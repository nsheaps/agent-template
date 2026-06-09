# Memory Index

This is the index of {{AGENT_FIRST_NAME}}'s durable, file-based memory. Memory files live in `memory/` at the repo root (NOT under `$CLAUDE_CONFIG_DIR` — see `.claude/rules/memory-location.md`).

On session start, read this index, then read the memory files relevant to what you're about to work on.

| File | Contents |
| --- | --- |
| _(none yet)_ | Add a row here whenever you create a `memory/<name>.md` file. |

Suggested starting files (create when you have content):

- `memory/handler-feedback.md` — corrections and preferences from the handler
- `memory/handler-workflow.md` — how the handler likes work done
- `memory/vision-architecture.md` — architecture/vision context
