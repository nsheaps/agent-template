#!/usr/bin/env bash
# claude-patch.sh — shared helpers for resolving + patching the claude
# binary. bin/claude is the ONLY caller that patches; bin/agent simply
# exec's `claude` (which PATH-resolves to bin/claude via direnv).
#
# Caller MUST set $REPO_DIR before invoking these helpers.
#
# Versioning + uniqueness model (Nate, Discord 2026-05-06 04:58Z):
# Each launch writes a UNIQUE patched binary at
#   $REPO_DIR/bin/patched/<version>/claude.<epoch>
# and atomically relinks $REPO_DIR/bin/claude-patched -> that file.
# Old patched outputs are left on disk (cheap, gitignored, easy to roll back).
# bin/claude only re-patches when the symlink is missing/broken or its
# target's version doesn't match the current claude version. Unique
# per-launch outputs eliminate the "Text file busy" failure mode that
# happened when the prior claude process still had the old patched
# binary mmap'd during a rapid restart.

# Echo the mise-pinned claude binary path. Returns 1 if mise can't resolve.
# Don't fall back to PATH — bin/<repo>/claude is on PATH and would be a loop.
claude_patch_resolve_bin() {
  if [[ -z "${REPO_DIR:-}" ]]; then
    echo "ERROR: claude_patch_resolve_bin requires REPO_DIR to be set" >&2
    return 1
  fi
  local bin
  bin="$(cd "$REPO_DIR" && mise which claude 2>/dev/null)" || return 1
  [[ -x "$bin" ]] || return 1
  printf '%s' "$bin"
}

# Extract the claude version from a mise-installed binary path.
# Mise layout: <mise-data>/installs/<plugin>/<version>/bin/claude
# Returns the version string (e.g. "2.1.128") or 1 on parse failure.
claude_patch_extract_version() {
  local bin="$1"
  local version
  version="$(basename "$(dirname "$(dirname "$bin")")")"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\. ]] || return 1
  printf '%s' "$version"
}

# Echo the per-version+per-launch patched-binary path. Requires REPO_DIR.
# Epoch is unique per launch so we never overwrite a binary in use (the
# "Text file busy" failure mode on rapid restarts).
claude_patch_path_for_version() {
  local version="$1"
  local epoch="$2"
  printf '%s' "$REPO_DIR/bin/patched/$version/claude.$epoch"
}

# Echo the stable symlink path that bin/claude exec's. Gitignored.
claude_patch_symlink_path() {
  printf '%s' "$REPO_DIR/bin/claude-patched"
}

# Extract the version from a patched-binary path. Layout is
# .../bin/patched/<version>/claude.<epoch>; the version is the parent
# directory's basename. Returns 1 if the path doesn't match the layout.
claude_patch_version_from_target() {
  local target="$1"
  local v
  v="$(basename "$(dirname "$target")")"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\. ]] || return 1
  printf '%s' "$v"
}

# Resolve the claude-patch-channels patcher binary. Echoes path or returns 1.
# Prefers $PATH (mise activated) but falls back to the mise shim directly,
# so this works in pre-direnv contexts too.
claude_patch_resolve_patcher() {
  local p
  p="$(command -v claude-patch-channels 2>/dev/null)" || true
  if [[ -z "$p" ]]; then
    local shim="$HOME/.local/share/mise/shims/claude-patch-channels"
    if [[ -x "$shim" ]]; then
      p="$shim"
    else
      return 1
    fi
  fi
  printf '%s' "$p"
}
