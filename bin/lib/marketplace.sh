#!/usr/bin/env bash
# marketplace.sh — claude plugin marketplace bootstrap + orphan prune.
#
# Both functions are non-fatal: a marketplace that's unreachable on this
# restart, an `add`/`install` that errors, or an old claude that lacks
# `prune` — none of those should keep the agent from coming up.
#
# Caller MUST set REPO_DIR + LOG_FILE and define log() and warn() before
# sourcing.

# Bootstrap marketplaces declared in .claude/settings.json:
# 1. `marketplace add` for each entry under `extraKnownMarketplaces` (idempotent).
# 2. `marketplace update` to refresh metadata.
# 3. `plugin install` for any `enabledPlugins:true` entry that isn't installed.
#
# Plugins stay at their currently-installed version until manually updated —
# accepted side effect of dropping the per-plugin update loop (Nate, Discord
# 2026-05-05 18:34Z).
#
# Cross-agent consistency: L14.
marketplace_bootstrap() {
  local settings="$REPO_DIR/.claude/settings.json"
  if [[ ! -f "$settings" ]]; then
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    log "[marketplace] skipped: claude not on PATH"; return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log "[marketplace] skipped: jq not on PATH"; return 0
  fi

  # 1) marketplace add for each entry under extraKnownMarketplaces.
  #    `marketplace add` is idempotent — it logs that the marketplace is
  #    already known and exits 0.
  local mkts mkt source_obj source_str
  mkts="$(jq -r '.extraKnownMarketplaces // {} | keys[]?' "$settings" 2>/dev/null)"
  while IFS= read -r mkt; do
    [[ -z "$mkt" ]] && continue
    source_obj="$(jq -c --arg name "$mkt" '.extraKnownMarketplaces[$name].source' "$settings" 2>/dev/null)"
    if [[ "$source_obj" == "null" || -z "$source_obj" ]]; then
      continue
    fi
    # Convert the source object to the string form `marketplace add` accepts.
    # Currently we only know about `source: "github"` with a `repo` field.
    # Other kinds: log and skip (non-fatal).
    local kind repo
    kind="$(echo "$source_obj" | jq -r '.source // empty')"
    repo="$(echo "$source_obj" | jq -r '.repo // empty')"
    if [[ "$kind" == "github" && -n "$repo" ]]; then
      source_str="$repo"
    else
      log "[marketplace] skipping $mkt — unsupported source kind '$kind'"
      continue
    fi
    log "[marketplace] add $mkt ($source_str)"
    # `claude plugin marketplace add [options] <source>` takes a single positional —
    # the source URL/repo/path. The marketplace name comes from the .claude-plugin/
    # marketplace.json on the source side, NOT from the caller. Passing $mkt as a
    # second positional made claude treat it as a second source, which fails with
    # "Invalid marketplace source format".
    #
    # Capture output to a temp file so we can both archive it in $LOG_FILE AND
    # surface it to the pane on failure. Silent failures here hid auth/clone
    # errors behind a generic "likely already present" log line for weeks.
    local mkt_out mkt_rc
    mkt_out="$(mktemp -t marketplace-add.XXXXXX)"
    command claude plugin marketplace add "$source_str" >"$mkt_out" 2>&1
    mkt_rc=$?
    cat "$mkt_out" >> "$LOG_FILE"
    if (( mkt_rc != 0 )); then
      warn "[marketplace] add for $mkt FAILED (rc=$mkt_rc):"
      sed 's|^|[marketplace:'"$mkt"'] |' "$mkt_out" >&2
    fi
    rm -f "$mkt_out"
  done <<< "$mkts"

  # 2) Refresh marketplaces.
  log "[marketplace] update (refresh metadata)"
  command claude plugin marketplace update >>"$LOG_FILE" 2>&1 \
    || warn "[marketplace] update non-zero (non-fatal)"

  # Resolve the scope claude has on record for a given plugin id. Prefers a
  # record matching the current project dir; falls back to the first record's
  # scope (covers user-scope global installs); defaults to "project" when no
  # record exists yet (new install). Without this, `plugin install`/`update`
  # default to user scope even when settings.json enables the plugin at
  # project scope, leaving the plugin installed but not visible to the agent.
  # Refs: #596.
  resolve_scope() {
    local pid="$1"
    local installed_json="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
    [ -f "$installed_json" ] || { echo "project"; return; }
    local scope
    scope=$(jq -r --arg pid "$pid" --arg cwd "${PROJECT_DIR:-$PWD}" \
      '.plugins[$pid][]? | select(.projectPath==$cwd) | .scope' "$installed_json" 2>/dev/null | head -n1)
    if [ -z "$scope" ]; then
      scope=$(jq -r --arg pid "$pid" '.plugins[$pid][]?.scope' "$installed_json" 2>/dev/null | head -n1)
    fi
    echo "${scope:-project}"
  }

  # 3) Ensure every enabledPlugins:true entry is installed AND bound to the
  #    latest cached version.
  #
  #    `marketplace update` only refreshes the marketplace cache — it does NOT
  #    rebind the active plugin version for already-enabled plugins. Claude
  #    Code keeps using the version that was bound at first-enable, so a v1.0.2
  #    bump sits in the cache while Setup{init}/SessionStart hooks fire from
  #    v1.0.1's hooks.json. Empirically verified on Alex 2026-05-16: shared-lib
  #    v1.0.2 in cache, v1.0.1 still bound, lib/ data dir never picked up new
  #    files. Per claude-code-guide.
  #
  #    Fix: run `plugin update <pid>` for every enabled plugin AFTER marketplace
  #    update. This rebinds to the latest cached version so the NEXT session's
  #    hooks fire from the new hooks.json. Non-fatal: if update fails for one
  #    plugin, we keep going and the launcher pre-pass / interactive session
  #    will still work from the previously-bound version.
  local enabled installed pid
  enabled="$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings" 2>/dev/null)"
  installed="$(command claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"

  # Track outcomes per plugin so we can emit a single human-readable summary
  # line at the end of the loop. The summary is logged via log() so it lands
  # in $LOG_FILE — bin/agent's build_prompt() then appends the full LOG_FILE
  # to the agent's first-turn prompt as "## Launcher Logs (since last start)".
  # That's how the agent sees "none updated / updated a b c / installed x y z"
  # at session start without us needing a separate sidecar file or hook.
  # Refs: Nate, Discord 2026-05-16.
  local -a installed_pids=() updated_pids=() uptodate_pids=() failed_pids=()

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    local scope
    scope="$(resolve_scope "$pid")"
    if ! grep -Fxq "$pid" <<< "$installed"; then
      log "[marketplace] installing missing plugin $pid (scope=$scope)"
      local install_out install_rc
      install_out="$(command claude plugin install --scope "$scope" "$pid" 2>&1)"
      install_rc=$?
      printf '%s\n' "$install_out" >>"$LOG_FILE"
      if (( install_rc != 0 )); then
        # Surface the actual error + a fix suggestion in the launcher pane.
        # Without this, the operator only sees "install of X failed" with no
        # explanation and has to dig through the log file.
        warn "[marketplace] install of $pid failed (rc=$install_rc, non-fatal):"
        printf '%s\n' "$install_out" | tail -n 5 | while IFS= read -r line; do
          printf '[marketplace:%s] %s\n' "$pid" "$line"
        done
        warn "[marketplace] fix: run 'claude plugin install $pid' manually, or grep $LOG_FILE for the full output."
        failed_pids+=("$pid")
      else
        installed_pids+=("$pid")
      fi
    else
      # Rebind to the latest cached version. No-op if already on latest.
      #
      # Print BEFORE invoking so the pane shows progress per-plugin instead of
      # going silent during the loop. The Claude CLI's own "Checking for
      # updates…" / "✔ already at the latest version" lines get captured into
      # $update_out and only flushed to $LOG_FILE — they never reach the pane.
      # Without an explicit log() line per iteration the loop looked hung.
      log "[marketplace] checking $pid (scope=$scope)…"
      local update_out update_rc summary
      update_out="$(command claude plugin update --scope "$scope" "$pid" 2>&1)"
      update_rc=$?
      printf '%s\n' "$update_out" >>"$LOG_FILE"
      if (( update_rc != 0 )); then
        warn "[marketplace] update of $pid non-zero (rc=$update_rc, non-fatal)"
        failed_pids+=("$pid")
      else
        # Classify the CLI's own outcome. Common cases:
        #   "✔ already at the latest version (X)" → up to date (no version change)
        #   "Updated <pid> from X to Y"           → updated (version change)
        if grep -q 'already at the latest version' <<< "$update_out"; then
          summary="up to date"
          uptodate_pids+=("$pid")
        elif grep -qiE 'updated|installed' <<< "$update_out"; then
          summary="$(grep -iE 'updated|installed' <<< "$update_out" | head -n1 | sed 's/^[[:space:]]*//')"
          updated_pids+=("$pid")
        else
          summary="$(grep -v '^[[:space:]]*$' <<< "$update_out" | tail -n1 | sed 's/^[[:space:]]*//')"
          [[ -z "$summary" ]] && summary="done"
          # Unknown outcome — bucket as up-to-date for the summary line (no
          # version change detected) but keep the raw line in the per-plugin
          # log above so it's not lost.
          uptodate_pids+=("$pid")
        fi
        log "[marketplace]   → $pid: $summary"
      fi
    fi
  done <<< "$enabled"

  # Emit the summary line. Designed to be readable in the agent's first-turn
  # context: a single log line whose shape tells the agent at a glance what
  # changed since the last launch. Examples:
  #   [marketplace] summary: none updated
  #   [marketplace] summary: updated: 1pass, shared-lib
  #   [marketplace] summary: installed: github-app; updated: 1pass
  #   [marketplace] summary: installed: x; updated: a, b; failed: c
  # Manual ", " join — ${arr[*]} with IFS only uses the FIRST char of IFS,
  # so we'd lose the space if we used the natural form. A function makes the
  # three call sites below readable.
  _join_csv() {
    local sep=", " first="$1"; shift
    local out="$first" item
    for item in "$@"; do out="$out$sep$item"; done
    printf '%s' "$out"
  }
  local -a summary_parts=()
  if (( ${#installed_pids[@]} > 0 )); then
    summary_parts+=("installed: $(_join_csv "${installed_pids[@]}")")
  fi
  if (( ${#updated_pids[@]} > 0 )); then
    summary_parts+=("updated: $(_join_csv "${updated_pids[@]}")")
  fi
  if (( ${#failed_pids[@]} > 0 )); then
    summary_parts+=("failed: $(_join_csv "${failed_pids[@]}")")
  fi
  if (( ${#summary_parts[@]} == 0 )); then
    log "[marketplace] summary: none updated"
  else
    # ${arr[*]} only uses the FIRST char of IFS as separator, so we need
    # a manual join to get "; " (semicolon + space) between parts.
    local summary_line="${summary_parts[0]}"
    local i
    for (( i=1; i < ${#summary_parts[@]}; i++ )); do
      summary_line="$summary_line; ${summary_parts[$i]}"
    done
    log "[marketplace] summary: $summary_line"
  fi
}

# Prune auto-installed plugin dependencies that no longer have any plugin
# requiring them. Gated on the subcommand existing — older Claude versions
# just silently skip. -y skips the confirmation prompt; failure is non-fatal.
# Available in claude-code v2.1.121+ (nsheaps/ai-mktpl#478).
#
# Prunes at BOTH user and project scope. `claude plugin prune` defaults to
# user only — without an explicit project pass, plugins enabled at project
# scope leave orphan deps lying around forever. Refs: #550.
marketplace_prune_orphans() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "Skipping plugin prune: claude not on PATH"
    return 0
  fi
  if ! claude plugin --help 2>&1 | grep -q '^[[:space:]]*prune'; then
    warn "Skipping plugin prune: subcommand unavailable (claude < v2.1.121, see nsheaps/ai-mktpl#478)"
    return 0
  fi
  local scope prune_out
  for scope in user project; do
    log "Pruning orphan auto-installed plugin dependencies ($scope scope)..."
    # Capture prune's output into a variable instead of redirecting >>$LOG_FILE
    # directly. Without this, prune's "Nothing to prune…" / "Removed N plugin(s)"
    # output skips the tmux pane entirely (only the file gets it). Passing the
    # capture through log() preserves both: timestamped pane line + file entry.
    # Refs: #552.
    if ! prune_out="$(claude plugin prune -y -s "$scope" 2>&1)"; then
      warn "claude plugin prune -s $scope exited non-zero (non-fatal)"
    fi
    [[ -n "$prune_out" ]] && log "$prune_out"
  done
}
