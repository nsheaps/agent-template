#!/usr/bin/env bash
# op-inject.sh — read .claude/plugins.settings.yaml's `1pass.opExec.items[]`
# list and `eval`-inject each item's env vars into the current shell via
# op-exec.
#
# Caller MUST set REPO_DIR + LOG_FILE and define log() and warn() before
# sourcing. OP_SERVICE_ACCOUNT_TOKEN must already be in env (the launcher
# sources it from settings.local.json upstream of this).
#
# Skips entirely if op-exec / op / yq aren't available, or if op isn't
# authenticated. Per-item failures are logged but don't abort.

op_inject_env() {
  if ! command -v op-exec >/dev/null 2>&1 || ! command -v op >/dev/null 2>&1; then
    return 0
  fi
  if ! op whoami >/dev/null 2>&1; then
    warn "op not authenticated (no service account token?). Skipping 1Password injection."
    return 0
  fi

  local plugin_settings="$REPO_DIR/.claude/plugins.settings.yaml"
  if [[ ! -f "$plugin_settings" ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi

  local items
  items="$(yq -r '.["1pass"].opExec.items[]?' "$plugin_settings" 2>/dev/null || true)"
  if [[ -z "$items" ]]; then
    return 0
  fi

  local item_ref op_exec_stderr op_exec_stdout var_names
  while IFS= read -r item_ref; do
    [[ -z "$item_ref" ]] && continue
    log "Injecting env vars from $item_ref"
    op_exec_stderr="$(mktemp)"
    op_exec_stdout="$(mktemp)"
    if op-exec "$item_ref" >"$op_exec_stdout" 2>"$op_exec_stderr"; then
      # Diagnostic: list VAR names only (no values) from the export statements
      var_names="$(grep -oE '^[[:space:]]*export[[:space:]]+[A-Z_][A-Z0-9_]*=' "$op_exec_stdout" 2>/dev/null \
        | sed -E 's/^[[:space:]]*export[[:space:]]+//; s/=$//' | tr '\n' ' ')"
      log "[op-inject] $item_ref resolved $(echo "$var_names" | wc -w) vars: $var_names"
      # shellcheck disable=SC1090
      eval "$(<"$op_exec_stdout")"
      if [[ -s "$op_exec_stderr" ]]; then
        while IFS= read -r line; do
          warn "[stderr] $line"
        done < "$op_exec_stderr"
      fi
    else
      while IFS= read -r line; do
        warn "[stderr] $line"
      done < "$op_exec_stderr"
      warn "Failed to inject from $item_ref"
    fi
    rm -f "$op_exec_stderr" "$op_exec_stdout"
  done <<< "$items"
}
