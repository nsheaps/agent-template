#!/usr/bin/env bash
# PostToolUse hook: when Bash runs `git commit ...`, surface a throttled
# task-discipline reminder. Throttle window: 60s.
#
# Surfaces the task-discipline reminder from .claude/rules/99_your-restrictions.md
# after each commit, throttled to once per 60s.

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
[[ "$CMD" =~ (^|[[:space:];&|])git[[:space:]]+commit($|[[:space:]]) ]] || exit 0

THROTTLE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/tmp/.git-commit-reminder-last"
mkdir -p "$(dirname "$THROTTLE_FILE")"
NOW=$(date +%s)
LAST=0
[[ -f "$THROTTLE_FILE" ]] && LAST=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)

if (( NOW - LAST < 60 )); then
  exit 0
fi
echo "$NOW" > "$THROTTLE_FILE"

MSG="Don't forget to keep your tasks up to date. Tasks need links to PRs and commits in descriptions, and if you're commiting to a PR you better have a task tracking it with proper validation steps before starting it and results before completing it!"

jq -nc --arg msg "$MSG" '{
  systemMessage: $msg,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'
