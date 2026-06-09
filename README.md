# agent-template

A template for standing up a new **agentic AI teammate** — a persistent Claude Code agent that runs in a tmux session, talks to a handler over a chat channel (Discord/Telegram), authenticates to GitHub as its own bot, and follows a checked-in set of rules, skills, and scheduled tasks.

This repo is **generic**. Every per-agent value is a `{{PLACEHOLDER}}`. You fill them in once, and you have a working agent.

## Quick start

1. Generate a repo from this template (or copy it) and clone it locally.
2. Read **[docs/setup/00-placeholders.md](docs/setup/00-placeholders.md)** — the full list of values to fill in.
3. Follow **[docs/setup/01-quickstart.md](docs/setup/01-quickstart.md)** end to end.
4. Launch with `bin/run-and-attach-agent`.

## What's in here

| Path | What it is |
| --- | --- |
| `agent.yaml` | The **sole** source of truth for the agent's name (everything derives from it) |
| `CLAUDE.md` | Entry point Claude reads first; points at the rules |
| `.claude/rules/` | Always-loaded behavioral constraints |
| `.claude/PERSONA.md`, `.claude/HANDLER.md` | Who the agent is and who it reports to |
| `.claude/contacts/` | Dossiers for the handler, peers, and people |
| `.claude/skills/`, `.claude/commands/`, `.claude/agents/` | Repo-local skills, commands, subagents |
| `.claude/hooks/`, `bin/hooks/` | PreToolUse/SessionStart hooks |
| `.claude/settings.json`, `.claude/plugins.settings.yaml` | Claude Code + plugin configuration |
| `.claude/scheduled-tasks.yaml` | Durable cron definitions restored on start |
| `bin/` | The launcher (`bin/run-and-attach-agent` is the entrypoint) |
| `memory/` | Durable, file-based memory (indexed by `.claude/MEMORY.md`) |
| `docs/setup/` | **Setup guides — start here** |
| `mise.toml`, `.envrc`, `rc.d/` | Tooling and shell environment |

## Setup guides

- [00 — Placeholders](docs/setup/00-placeholders.md)
- [01 — Quickstart](docs/setup/01-quickstart.md)
- [02 — 1Password (secrets)](docs/setup/02-1password.md)
- [03 — GitHub App (bot identity)](docs/setup/03-github-app.md)
- [04 — Chat channels (Discord / Telegram)](docs/setup/04-channels.md)
- [05 — Marketplace & plugins](docs/setup/05-marketplace-and-plugins.md)
- [07 — Architecture](docs/setup/07-architecture.md)
