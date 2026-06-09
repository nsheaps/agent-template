#!/usr/bin/env bash
# agent-env.sh — single source of truth for the per-agent env exports
# shared by bin/agent and bin/claude.
#
# Caller MUST set AGENT_NAME before invoking agent_env_export. The
# function derives every per-agent path from AGENT_NAME (so the same
# env layout shows up regardless of who invoked us).
#
# Why this is a function, not top-level exports: bin/agent recomputes
# AGENT_HOME_DIR after `op run` injects the parent ENVIRONMENT (which
# may carry a stale AGENT_HOME_DIR from a different agent — see the
# comment at the call site in bin/agent). Wrapping in a function lets
# the caller call it at the exact recompute point.

agent_env_export() {
  if [[ -z "${AGENT_NAME:-}" ]]; then
    echo "ERROR: agent_env_export requires AGENT_NAME to be set" >&2
    return 1
  fi

  AGENT_HOME_DIR="$HOME/.agents/$AGENT_NAME"

  # XDG Base Directory spec (https://wiki.archlinux.org/title/XDG_Base_Directory)
  # — every per-agent directory is anchored under AGENT_HOME_DIR so apps that
  # honor XDG (gh, git, jq, mise, op, …) write into the agent's namespace
  # automatically, no per-app env var needed. We override the four primary
  # variables AND prepend the agent dirs to the system search lists.
  export XDG_CONFIG_HOME="$AGENT_HOME_DIR/.config"
  export XDG_DATA_HOME="$AGENT_HOME_DIR/.local/share"
  export XDG_STATE_HOME="$AGENT_HOME_DIR/.local/state"
  export XDG_CACHE_HOME="$AGENT_HOME_DIR/.cache"
  # Prepend agent paths to the system search lists so reads find agent files
  # first while still falling back to system defaults for anything not
  # per-agent (per spec: colon-separated, leftmost has highest precedence).
  export XDG_CONFIG_DIRS="$XDG_CONFIG_HOME:${XDG_CONFIG_DIRS:-/etc/xdg}"
  export XDG_DATA_DIRS="$XDG_DATA_HOME:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

  GH_CONFIG_DIR="$XDG_CONFIG_HOME/gh"
  mkdir -p "$GH_CONFIG_DIR" "$AGENT_HOME_DIR/.claude" \
    "$XDG_CONFIG_HOME/git" \
    "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

  export AGENT_NAME
  export AGENT_HOME_DIR
  export GH_CONFIG_DIR
  export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"
  # CLAUDE_CONFIG_DIR relocates the per-agent claude home (settings, config,
  # projects/) under $AGENT_HOME_DIR/.claude.
  export CLAUDE_CONFIG_DIR="$AGENT_HOME_DIR/.claude"
  export DISABLE_AUTOUPDATER=1
  export FORCE_AUTOUPDATE_PLUGINS=1
  # L28: opt out of the per-message Anthropic attribution header.
  # Ref: https://code.claude.com/docs/en/env-vars
  export CLAUDE_CODE_ATTRIBUTION_HEADER=0
  # force 2+ min agents to be forced to background
  export CLAUDE_AUTO_BACKGROUND_TASKS=1
  export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
  export CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING=1
  # todo: turn on when we replace pr and commit workflows with ones from scm-utils
  # export CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1
  export CLAUDE_CODE_ENABLE_AWAY_SUMMARY=1
  export CLAUDE_CODE_ENABLE_BACKGROUND_PLUGIN_REFRESH=1
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
}
