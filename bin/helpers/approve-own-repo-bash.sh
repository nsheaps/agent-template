#!/usr/bin/env bash
# approve-own-repo-bash.sh — Auto-approve Bash commands that write to own project repo
#
# PermissionRequest hook for Bash tool.
# Reads hook input JSON from stdin, extracts tool_input.command,
# checks if the command contains output redirects (> or >>) pointing to
# paths within CLAUDE_PROJECT_DIR (the Henry repo).
#
# If yes: outputs approve decision JSON.
# If no:  exits 0 silently (falls through to normal permission behavior).
#
# Usage in settings.json hooks:
#   "command": "bash bin/helpers/approve-own-repo-bash.sh"

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/home/nsheaps/src/nsheaps/.ai-agent-henry}"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
  exit 0  # No command in input, fall through
fi

# Check if the command contains a redirect (> or >>) to a path that starts
# with the project directory or the .claude/ subdirectory.
# We look for patterns like:
#   > /path/to/project/...
#   >> /path/to/project/...
#   >/path/to/project/...
#   >>/path/to/project/...
# using grep with extended regex.

if echo "$COMMAND" | grep -qE ">+\s*${PROJECT_DIR}"; then
  jq -n --arg reason "Bash writing to own project repo (${PROJECT_DIR})" \
    '{"decision":"approve","reason":$reason}'
  exit 0
fi

# Also match relative paths starting with .claude/ when run from project root
if echo "$COMMAND" | grep -qE ">+\s*\.claude/"; then
  jq -n --arg reason "Bash writing to .claude/ within own project repo" \
    '{"decision":"approve","reason":$reason}'
  exit 0
fi

# Not a write to own repo — fall through to normal permission behavior
exit 0
