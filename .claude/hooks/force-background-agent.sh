#!/usr/bin/env bash
# PreToolUse hook — force every Agent() call to run in the background.
#
# Foreground subagent dispatches block the main session until timeout,
# making the main loop unresponsive to handler messages. Every Agent call
# must run in the background (see .claude/rules/responsiveness.md). This hook
# mutates the tool_input to set run_in_background=true regardless of caller
# intent.
#
# Behavior:
#   - run_in_background=true  → no-op (already correct).
#   - run_in_background unset → warn + force true.
#   - run_in_background=false → warn LOUDLY + force true.
#
# Wire from .claude/settings.json PreToolUse for matcher "Agent".

set -euo pipefail

payload="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<<"$payload")"

[[ "$tool_name" != "Agent" ]] && exit 0

# jq's `//` is a falsy-coalesce (false treated as missing), so use `has()`
# to distinguish "key missing" from "key present and false".
has_key="$(jq -r '.tool_input | has("run_in_background")' <<<"$payload")"

if [[ "$has_key" == "true" ]]; then
  run_in_bg="$(jq -r '.tool_input.run_in_background' <<<"$payload")"
else
  run_in_bg="unset"
fi

case "$run_in_bg" in
  true)
    # Already correct — pass through silently.
    exit 0
    ;;
  false)
    severity_note=$'🚨 LOUD WARNING — `run_in_background` was EXPLICITLY set to `false`. This is wrong: foreground subagent dispatches block the main session until timeout, freezing the main loop while you wait. Set it to `true` next time.'
    ;;
  unset)
    severity_note=$'⚠️ Warning — `run_in_background` was not set on this Agent() call. Always set it explicitly to `true` going forward.'
    ;;
  *)
    severity_note="⚠️ Warning — run_in_background had unexpected value: $run_in_bg. Forcing true."
    ;;
esac

updated_input="$(jq '.tool_input | .run_in_background = true' <<<"$payload")"

trailer='Your Agent() has been forced to the background. If this is an issue stop the task immediately.'

jq -n \
  --argjson updated "$updated_input" \
  --arg note "$severity_note" \
  --arg trailer "$trailer" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: $updated,
      additionalContext: ($note + "\n\n" + $trailer)
    }
  }'

exit 0
