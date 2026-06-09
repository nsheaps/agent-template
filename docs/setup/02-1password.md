# 1Password (secrets)

All of the agent's secrets live in 1Password and are injected into the session environment at startup by the `1pass` plugin. **No secret value is ever committed to this repo** — only `op://` references.

## What you need

- A 1Password vault for this agent: `{{OP_VAULT}}`.
- A 1Password **service account** with read access to that vault (its token is what the host uses to resolve `op://` references non-interactively).

## Steps

1. **Create the vault** `{{OP_VAULT}}` and add the agent's secrets as items, e.g.:
   - GitHub App credentials (see [03-github-app.md](03-github-app.md)) — stored as `{{GITHUB_APP_ITEM}}`.
   - Chat bot tokens (Discord/Telegram) — see [04-channels.md](04-channels.md).
   - Any model/provider API keys the agent needs.
2. **Provision the service-account token** on the host out-of-band (e.g. exported as `OP_SERVICE_ACCOUNT_TOKEN` by the launcher's environment, or via your secret manager). Never write it into the repo.
3. **Declare references** in `.claude/plugins.settings.yaml` under the `1pass` plugin config, using `op://{{OP_VAULT}}/<item>/<field>` references. The plugin resolves these at SessionStart and writes them to `CLAUDE_ENV_FILE` so every tool call sees them.
4. **Verify** with the `1pass:op` / `1pass:op-exec` skills, or `op whoami`. Confirm a secret's *effect* (e.g. `gh auth status` works), never its value.

## Rules

- Follow `.claude/rules/secrets-and-shared-machine.md` — it lists the safe vs. unsafe ways to inspect secrets and env. Read it before touching anything secret-bearing.
- Prefer runtime injection (`op run` / `op-exec` / plugin `op://` config) over writing secrets to files.
- If a secret ever lands in the transcript, tell the handler so it can be rotated.
