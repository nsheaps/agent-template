#!/usr/bin/env bash
# test-env.sh — single source of truth for the env-strip list used by
# bin/test-agent when launching bin/agent in clean-env mode.
#
# Keep this in sync with the agent-management skill's tmux launch recipe
# and the per-PR test sub-agent prompts. Adding a new agent secret? Add
# its env var name here.

# Space-separated list of env vars to unset before invoking bin/agent
# under test. AGENT_NAME is included so the launcher reads the per-repo
# agent.yaml (any inherited AGENT_NAME from the parent shell is wrong
# in cross-agent contexts).
TEST_ENV_STRIP_VARS=(
  AGENT_LAUNCHER_PID
  DISCORD_BOT_TOKEN
  TELEGRAM_BOT_TOKEN
  DISCORD_ALLOW_BOTS
  GH_TOKEN
  GITHUB_TOKEN
  BRAINTRUST_API_KEY
  GITHUB_APP_ID
  GITHUB_APP_PRIVATE_KEY
  GITHUB_APP_PRIVATE_KEY_PATH
  GITHUB_INSTALLATION_ID
  GITHUB_APP_CLIENT_ID
  GITHUB_APP_CLIENT_SECRET
  OP_SERVICE_ACCOUNT_TOKEN
  AGENT_NAME
)

# Echo the `env -u VAR1 -u VAR2 …` prefix that `tmux new-session -d -c …`
# can use as the leading part of its command string. No trailing space —
# caller is expected to append the actual command.
test_env_strip_cmd() {
  local prefix="env"
  local v
  for v in "${TEST_ENV_STRIP_VARS[@]}"; do
    prefix+=" -u $v"
  done
  printf '%s' "$prefix"
}
