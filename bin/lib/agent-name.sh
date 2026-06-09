#!/usr/bin/env bash
# agent-name.sh — resolve AGENT_NAME from agent.yaml. Source of truth is
# agent.yaml; inherited env is ignored entirely.
#
# Caller MUST set $REPO_DIR before sourcing. agent_name_resolve sets
# AGENT_NAME (without exporting — leave that to agent_env_export).
#
# Why no env fallback (Nate Discord 2026-05-17 10:23Z, msg 1505516188984148221):
# A tmux server started by one agent persists its env (including AGENT_NAME)
# to every subsequent `tmux new-session` in that server. Letting env win
# meant `tmux new-session -d -s henry … bash bin/agent` in henry's repo ran
# as jack identity because the tmux server's env carried `AGENT_NAME=jack`.
# Findings: docs/research/bin-agent-ordering-bug-2026-05-17.md §"Fix 1".

agent_name_read_yaml() {
  local f="$REPO_DIR/agent.yaml"
  [[ -f "$f" ]] || return 1
  # Minimal parser — grabs `name: <value>` from the top of the file. Avoids a
  # yq dependency at this point in launcher startup (yq is installed via mise,
  # which hasn't been activated yet on the very first run after a fresh clone).
  local v
  v="$(grep -E '^[[:space:]]*name:[[:space:]]*' "$f" | head -1 | sed -E 's/^[[:space:]]*name:[[:space:]]*//; s/[[:space:]]*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  [[ -n "$v" ]] && printf '%s' "$v"
}

agent_name_resolve() {
  if [[ -z "${REPO_DIR:-}" ]]; then
    echo "ERROR: agent_name_resolve requires REPO_DIR to be set" >&2
    return 1
  fi
  AGENT_NAME="$(agent_name_read_yaml)"
  if [[ -z "$AGENT_NAME" ]]; then
    echo "ERROR: AGENT_NAME could not be determined (no name: in $REPO_DIR/agent.yaml)" >&2
    return 1
  fi
}
