#!/usr/bin/env bash
# seed-claude-json.sh — copy-or-merge the checked-in seed .claude.json
# into the per-agent CLAUDE_CONFIG_DIR.
#
# Why: a fresh CLAUDE_CONFIG_DIR (after a clone, a wipe, or a brand-new
# agent) doesn't have hasCompletedOnboarding=true or the per-project
# trust flags claude expects on first launch. Without them, claude
# strands on the theme picker / trust dialog / login picker. Seeding the
# right flags upfront skips all three.
#
# Merge semantics: jq -s '.[0] * .[1]' (seed * target) — TARGET WINS on
# overlapping keys so seed updates are additive and never destroy
# runtime state (firstStartTime, userID, migration flags, cached
# growthbook features, etc.).
#
# Caller MUST set REPO_DIR + CLAUDE_CONFIG_DIR + LOG_FILE and define
# log() and warn() before sourcing.
#
# Reference: docs/research/claude-code-oauth-token-bootstrap-investigation.md
# in the ai-agent-jack repo.

seed_claude_json() {
  local seed="$REPO_DIR/.claude/.claude.json"
  local target="$CLAUDE_CONFIG_DIR/.claude.json"
  if [[ ! -f "$seed" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  if [[ ! -f "$target" ]]; then
    cp "$seed" "$target"
    log "[seed] copied $seed to $target (target was missing)"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  if jq -s '.[0] * .[1]' "$seed" "$target" > "$tmp" 2>/dev/null; then
    # Only log + replace if the merge actually changed the target SEMANTICALLY.
    # cmp -s would compare bytes, which fails when claude has rewritten the
    # target with different key ordering/whitespace than jq produces. Use jq
    # itself for the equality check so canonical form differences don't
    # trigger spurious "merged" logs every boot. Refs: #551.
    if jq -ne --slurpfile a "$tmp" --slurpfile b "$target" '$a == $b' >/dev/null 2>&1; then
      rm -f "$tmp"
    else
      mv "$tmp" "$target"
      log "[seed] merged $seed into $target (target wins on conflict)"
    fi
  else
    rm -f "$tmp"
    warn "[seed] jq merge failed; leaving $target alone"
  fi
}
