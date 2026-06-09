#!/usr/bin/env bash
# PreToolUse hook — blocks Write/Edit/MultiEdit to *.md files under
# $CLAUDE_CONFIG_DIR/projects/. Memory belongs OUTSIDE claude's internal
# project state dir (handler doesn't see/inspect files there).
#
# Wire from .claude/settings.json PreToolUse for Write|Edit|MultiEdit.

set -euo pipefail

# PreToolUse hook stdin: { tool_name, tool_input: { file_path, ... }, ... }
payload="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<<"$payload")"
file_path="$(jq -r '.tool_input.file_path // empty' <<<"$payload")"

case "$tool_name" in
  Write | Edit | MultiEdit) ;;
  *) exit 0 ;;
esac

[[ -z "$file_path" ]] && exit 0

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
projects_dir="$config_dir/projects"

# Block .md writes under the projects dir (deep match).
if [[ "$file_path" == "$projects_dir"/* && "$file_path" == *.md ]]; then
  cat >&2 <<EOF
Blocked: writing markdown under \$CLAUDE_CONFIG_DIR/projects/ is forbidden.
  Path:   $file_path
  Reason: memory/markdown lives in the AGENT REPO (so links are shareable),
          not under claude's internal project-state dir. Write to the repo's
          memory/ directory instead. See .claude/rules/memory-location.md.
EOF
  exit 2
fi

exit 0
