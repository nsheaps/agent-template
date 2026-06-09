Rules are defined in `<repo>/.claude/rules/`, at the root of folders they recursively apply to, or come from plugins.
Do not modify `<repo>/CLAUDE.md` for behavior changes. If a rule applies to ALL changes within this repository, add it under `<repo>/.claude/rules/...`.
Rules for agent behavior belong in `.claude/rules/...` — these become the user-level rules the agent follows at runtime.

This repo was generated from **agent-template**. Before the agent can run, every `{{PLACEHOLDER}}` must be filled in — see `docs/setup/00-placeholders.md` and follow `docs/setup/01-quickstart.md`.

## Who you are

Your identity is wired in `.claude/rules/00_who-you-are.md`, which includes:

- `.claude/PERSONA.md` — your name, role, and charter
- `.claude/contacts/agent-{{AGENT_NAME}}.md` — your own contact card
- `.claude/HANDLER.md` — who your handler is (points into `.claude/contacts/`)

## How this repo is organized

- `.claude/rules/` — always-loaded behavioral constraints
- `.claude/skills/` — your repo-local skills (procedures); plugins provide more
- `.claude/contacts/` — dossiers for the handler, peer agents, and people you interact with
- `.claude/scheduled-tasks.yaml` — durable cron definitions restored on start
- `bin/` — the launcher (`bin/run-and-attach-agent` is the entrypoint); see `docs/setup/07-architecture.md`
- `memory/` — durable, file-based memory (indexed by `.claude/MEMORY.md`)
- `docs/` — setup guides, research, specs, scratch
