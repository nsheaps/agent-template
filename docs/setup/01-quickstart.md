# Quickstart

Bring a new agent from a fresh clone of this template to a running session.

> Replace every `{{PLACEHOLDER}}` as you go — see [00-placeholders.md](00-placeholders.md).
> Find any you missed: `grep -rn '{{' . --include='*.md' --include='*.json' --include='*.yaml' | grep -v docs/setup/00-placeholders.md`

## 0. Prerequisites

- A Unix-like host you control (the agent runs in **tmux**; sessions are long-lived).
- [`mise`](https://mise.jdx.dev/) for tool management (the SessionStart hooks will install it if missing).
- The Claude Code CLI available on PATH (the launcher wraps it via `bin/claude`).
- Accounts/access for: 1Password, a GitHub org + GitHub App, and at least one chat channel (Discord or Telegram).

## 1. Pick the name

Edit **`agent.yaml`** and set `name:` to your agent's short lowercase slug (e.g. `jordan`). This is the **only** place the name is defined — `~/.agents/<name>`, the tmux session, and the 1Password vault all derive from it.

## 2. Fill in identity

- `.claude/PERSONA.md` — name, role, charter, voice (`{{AGENT_DISPLAY_NAME}}`, `{{AGENT_FIRST_NAME}}`, `{{AGENT_ROLE}}`, `{{ORG_NAME}}`).
- `.claude/HANDLER.md` + `.claude/contacts/{{HANDLER_SLUG}}.md` — your handler.
- `.claude/contacts/agent-{{AGENT_NAME}}.md` — your own card; rename the file to `agent-<name>.md`.
- `.claude/rules/10_your-org.md` — the org tree and peers.

## 3. Secrets — 1Password

Follow [02-1password.md](02-1password.md): create the agent's vault `{{OP_VAULT}}`, store its secrets, and wire the `1pass` plugin so they're injected at session start. **Secrets are never written to the repo** — only `op://` references.

## 4. Bot identity — GitHub App

Follow [03-github-app.md](03-github-app.md): the agent commits and pushes as its own bot (`{{BOT_LOGIN}}`), never as the handler. You'll set `{{GITHUB_APP_ITEM}}` and `{{GITHUB_INSTALLATION_ID}}`.

## 5. Talk to it — a channel

Follow [04-channels.md](04-channels.md) to wire Discord and/or Telegram so the handler can message the agent and get replies on the same channel.

## 6. Plugins

Follow [05-marketplace-and-plugins.md](05-marketplace-and-plugins.md): the marketplace is registered and plugins enabled in `.claude/settings.json`; `bin/install-plugins` materializes them.

## 7. Trust the repo path

`.claude/.claude.json` seeds Claude Code's trust for `{{REPO_ABS_PATH}}` so the first launch isn't blocked by a trust prompt. Make sure that path matches where you cloned.

## 8. Launch

```bash
bin/run-and-attach-agent
```

This starts a tmux session named after `agent.yaml`'s `name:` (via `bin/start-agent`) and attaches. Detach with `Ctrl+B D` (the watchdog reattaches/recreates); `Ctrl+C` exits the loop. See [07-architecture.md](07-architecture.md) for what happens under the hood.

## 9. Verify

- The agent greets/responds on the configured channel.
- `gh auth status` inside the session resolves to the bot, not the handler.
- A trivial commit is attributed to `{{BOT_LOGIN}}`.
- Scheduled tasks in `.claude/scheduled-tasks.yaml` are restored (check with the agent).
