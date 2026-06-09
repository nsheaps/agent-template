# GitHub App (bot identity)

The agent acts on GitHub as **its own bot** (`{{BOT_LOGIN}}`), never as the handler. This keeps attribution clean and scopes permissions to exactly what the agent needs. The `github-app` plugin mints a short-lived **installation token** at SessionStart and configures the bot git identity.

## What you need

- A **GitHub App** owned by your org with the permissions the agent needs (typically: Contents RW, Pull requests RW, Issues RW, and read access for browsing).
- The App **installed** on the target repos/org — note the **installation id** (`{{GITHUB_INSTALLATION_ID}}`).
- The App's **id** and **private key (PEM)**.

## Steps

1. **Create the App** (org settings → Developer settings → GitHub Apps). Generate a private key (PEM).
2. **Install it** on the org/repos this agent works in; record the installation id → `{{GITHUB_INSTALLATION_ID}}`.
3. **Store credentials in 1Password** as `{{GITHUB_APP_ITEM}}` in vault `{{OP_VAULT}}`: the App id, installation id, and the PEM. (See [02-1password.md](02-1password.md).)
4. **Wire the `github-app` plugin** via `.claude/plugins.settings.yaml` so its SessionStart hook reads those values and:
   - mints an installation token → `GH_TOKEN` / `GITHUB_TOKEN` (written to `CLAUDE_ENV_FILE`),
   - isolates `GH_CONFIG_DIR` so it doesn't clobber other agents,
   - sets the bot git identity (`{{BOT_LOGIN}}` + its noreply email) and the `gh` credential helper.
5. **Verify**: in a session, `gh auth status` resolves to the bot; a test commit is attributed to `{{BOT_LOGIN}}`.

## Rules

- NEVER fall back to the handler's personal token for git (`.claude/rules/communication.md`). If the token expires mid-session, regenerate it via the `github-app` plugin's skills; if that fails, stop and diagnose.
- Installation tokens are short-lived — the plugin refreshes them; the `github-app:github-app-token` skill covers manual refresh.
