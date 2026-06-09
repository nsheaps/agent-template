# Rules

Rules are **short declarative constraints** loaded on every API call. They define what to always/never do — not the step-by-step "how" (that belongs in skills). Keep them short; every token counts.

| Rule | Purpose |
| --- | --- |
| `00_who-you-are.md` | Wires in your persona, self-contact card, and handler |
| `10_your-org.md` | Org hierarchy and working norms |
| `99_your-restrictions.md` | Shared-machine policy + work-tracking discipline |
| `communication.md` | How to talk to the handler; saving info; temp files; git identity |
| `responsiveness.md` | Run long work in the background; stay responsive |
| `auto-pr-management.md` | Every branch gets a draft PR; keep it current |
| `task-planning.md` | Explore + plan before implementing; persist plans |
| `todo-management.md` | Keep Tasks current before every tool use |
| `code-quality.md` | Git workflow, testing, safe deletion, validation |
| `never-say-done-prematurely.md` | Validate end-to-end before claiming "done" |
| `verify-before-acting.md` | Verify root cause with evidence before acting |
| `intellectual-honesty-in-responses.md` | Demonstrate understanding; admit gaps |
| `how-to-politely-correct-someone.md` | The spinach rule — correct flaws directly |
| `research-first.md` | Check existing research/history before researching |
| `research-output.md` | Where research output must be saved |
| `using-memory.md` | File-based memory: index + `memory/*.md` |
| `memory-location.md` | Memory lives in the repo, not `$CLAUDE_CONFIG_DIR` |
| `skill-maintenance.md` | Keep local skills current |
| `skill-resolution-order.md` | Local repo skills win over plugin skills |
| `scheduled-tasks.md` | Durable crons; dedupe on restart vs. compaction |
| `secrets-and-shared-machine.md` | Never leak secrets; safe inspection patterns |
| `selective-responses.md` | Don't respond to messages not aimed at you |
| `tool-preferences.md` | Built-in tools over Bash; background execution |
| `bash-scripting.md` | No command chaining/piping in the Bash tool |
| `when-something-doesnt-work.md` | Stop, diagnose, fix the cause, then retry |
| `plugin-safety.md` | Never `marketplace remove` to update a marketplace |
| `glossary.md` | Canonical term definitions (e.g. capital-T Task) |

Plugins contribute additional rules at runtime. Local rules in this folder take precedence for this repo.
