#!/usr/bin/env bash
# inject-channel-allowlist.sh — Inject ai-mktpl channel entries into GrowthBook cache
#
# Adds marketplace channel entries to cachedGrowthBookFeatures.tengu_harbor_ledger
# in ~/.claude.json. This allows --channels to work for plugins that aren't on
# Anthropic's official allowlist, bypassing the need for --dangerously-load-development-channels.
#
# The injection is idempotent — if an entry already exists, it is not duplicated.
# All existing ledger entries are preserved.
#
# Usage:
#   bin/helpers/inject-channel-allowlist.sh
#
# Called by bin/agent on every startup, after marketplace sync, before build_args.

set -euo pipefail

CLAUDE_JSON="${HOME}/.claude.json"

# Use project .claude/tmp/ instead of system /tmp — shared machine, multiple agents.
# This script lives at $REPO_DIR/bin/helpers/, so go up two levels.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INJECT_TMP_DIR="$REPO_DIR/.claude/tmp"
mkdir -p "$INJECT_TMP_DIR"

log() {
  echo "[inject-channel-allowlist] $1"
}

# Bail out gracefully if jq is missing
if ! command -v jq &>/dev/null; then
  log "WARNING: jq not found — skipping channel allowlist injection"
  exit 0
fi

# Bail out gracefully if the file doesn't exist
if [[ ! -f "$CLAUDE_JSON" ]]; then
  log "WARNING: $CLAUDE_JSON not found — skipping channel allowlist injection"
  exit 0
fi

# Entries to inject
# Each entry is a JSON object: {"marketplace":"...", "plugin":"..."}
ENTRIES_TO_INJECT=(
  '{"marketplace":"ai-mktpl","plugin":"discord"}'
  '{"marketplace":"ai-mktpl","plugin":"telegram"}'
)

CHANGED=false

for entry in "${ENTRIES_TO_INJECT[@]}"; do
  marketplace="$(echo "$entry" | jq -r '.marketplace')"
  plugin="$(echo "$entry" | jq -r '.plugin')"

  # Check if this exact entry already exists in the ledger
  existing="$(jq --argjson e "$entry" '
    .cachedGrowthBookFeatures.tengu_harbor_ledger //  [] |
    map(select(.marketplace == $e.marketplace and .plugin == $e.plugin)) |
    length
  ' "$CLAUDE_JSON" 2>/dev/null || echo "0")"

  if [[ "$existing" -gt "0" ]]; then
    log "Already present: marketplace=$marketplace plugin=$plugin — skipping"
    continue
  fi

  log "Injecting: marketplace=$marketplace plugin=$plugin"

  # Inject the entry by appending to the ledger array
  # If tengu_harbor_ledger is null/missing, initialise it to []
  tmp="$(mktemp "$INJECT_TMP_DIR/inject-channel-allowlist.XXXXXX")"
  if jq --argjson entry "$entry" '
    .cachedGrowthBookFeatures.tengu_harbor_ledger =
      ((.cachedGrowthBookFeatures.tengu_harbor_ledger // []) + [$entry])
  ' "$CLAUDE_JSON" > "$tmp"; then
    mv "$tmp" "$CLAUDE_JSON"
    CHANGED=true
  else
    rm -f "$tmp"
    log "ERROR: jq failed to update $CLAUDE_JSON for $marketplace/$plugin"
    exit 1
  fi
done

if [[ "$CHANGED" == "true" ]]; then
  log "Done — ledger updated."
else
  log "Done — no changes needed."
fi
