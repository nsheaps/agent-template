#!/usr/bin/env bash
# PostToolUse hook: when Bash runs `git push ...`, surface a throttled
# PR-title/body review reminder. Throttle window: 300s (5 minutes).
#
# The auto-pr-management rule says to refresh the PR title/body after every
# push; this throttles that reminder to at most once per 5-minute window.

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
[[ "$CMD" =~ (^|[[:space:];&|])git[[:space:]]+push($|[[:space:]]) ]] || exit 0

THROTTLE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/tmp/.git-push-pr-title-reminder-last"
mkdir -p "$(dirname "$THROTTLE_FILE")"
NOW=$(date +%s)
LAST=0
[[ -f "$THROTTLE_FILE" ]] && LAST=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)

if (( NOW - LAST < 300 )); then
  exit 0
fi
echo "$NOW" > "$THROTTLE_FILE"

MSG="After this push, review the PR title and body to make sure they accurately reflect the full set of changes in the PR (not just the latest commit). The title and body should describe cumulative changes. Keep the title under 70 characters."

jq -nc --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'
