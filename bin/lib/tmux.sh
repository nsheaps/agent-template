#!/usr/bin/env bash
# tmux.sh — shared tmux session helpers for the agent launcher scripts.
#
# Sourced by:
#   - bin/run-agent              (creates session if missing, exits)
#   - bin/run-and-attach-agent   (creates + attaches in a loop)
#   - bin/attach-agent           (attaches to existing session, never creates)
#
# Convention: the session name equals AGENT_NAME (one tmux session per agent).
#
# Spec: docs/specs/start-agent.md
# TODO (system-service migration): when the agent runner moves to a systemd
# unit, this file goes away. tmux is replaced by journald; "session up?"
# becomes "is the unit active?".

# Three helpers with deliberately small surface area. Each takes the session
# name as $1 (defaulting to AGENT_NAME) and shells out to tmux. No error
# handling beyond tmux's own — callers decide what to do with non-zero exit.

# tmux_session_exists [session-name]
# Exit 0 if the session is up, non-zero otherwise. Silent.
tmux_session_exists() {
  local name="${1:-${AGENT_NAME:?AGENT_NAME or arg required}}"
  tmux has-session -t "$name" 2>/dev/null
}

# tmux_make_session <session-name> <cwd> <command>
# Create a detached tmux session named <session-name>, started in <cwd>,
# running <command>. Exits with tmux's exit code.
#
# Passes AGENT_NAME=<name> via -e so the new session does NOT inherit a
# stale AGENT_NAME from the tmux server's environment (which can happen
# when one agent's shell created the tmux server and a different agent
# is now starting a session — e.g. Jack launching Henry).
tmux_make_session() {
  local name="${1:?session name required}"
  local cwd="${2:?cwd required}"
  local cmd="${3:?command required}"
  tmux new-session -d -s "$name" -e "AGENT_NAME=$name" -c "$cwd" "$cmd"
}

# tmux_attach_session [session-name]
# Attach to an existing session. Will fail if the session doesn't exist.
tmux_attach_session() {
  local name="${1:-${AGENT_NAME:?AGENT_NAME or arg required}}"
  tmux attach -t "$name"
}
