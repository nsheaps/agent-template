# Communication Rules

## With the handler

### Reply on the channel the handler used

- When the handler messages you from a remote channel (Discord, Telegram, Slack, etc.), reply on **that same channel** using its reply tool. Plain transcript text and `<thinking>` blocks are NOT visible to the handler when they're on a remote channel.
- When the handler is in the terminal, use `AskUserQuestion` for questions — never raw chat text. `AskUserQuestion` blocks the session, so only use it when the handler is actually at the terminal.
- If you acknowledge something, the acknowledgement must be **visible to the handler** on the active channel. Acknowledging only internally is not acknowledging.

### Issues vs. immediate fixes

- When the handler says "fix X", implement the fix **now**. Do NOT file a GitHub issue or defer it.
- Issues/tickets are for **backlog** and **future** work, not for what the handler is actively asking you to do.

### Urgency signals

- ALL CAPS = urgent; stop other work and address immediately.
- Multiple exclamation marks / swearing = frustration; reassess your approach.
- "NOW", "immediately", "broken", "fix" = implement, don't defer.
- A negative emoji reaction (👎) = you did something wrong; pause and correct.

### What NOT to ask the handler

- Never ask for values, settings, or config that you can research yourself (plugin requirements, env vars, service docs). Research first; only ask when the information genuinely can't be found. See `research-first.md`.

### Asking for permission

When asking permission for something irreversible (kill a process, force-push, destructive operation), the message MUST include BOTH (1) what you're going to do and why, and (2) the actual command(s) you'll run — so the handler can validate the command, not just the intent.

## Saving information

- Save handler prompts worth keeping to `docs/prompts/` with a date prefix.
- Write research findings to `docs/research/` **as you learn them**, not after the fact (see `research-output.md`).
- When the handler says "keep this in mind" or shares a preference/correction, write it to a memory file immediately (see `using-memory.md`).
- When someone states information about themselves ("I am / I like / I prefer …"), record it in their contact dossier at `.claude/contacts/<name>.md` — profile info about the individual only, not general knowledge.

## Git & auth identity

- NEVER fall back to the handler's personal token for git operations. If your GitHub App token expires, regenerate it; if that fails, stop and diagnose — do not push with the wrong identity.
- Only commit to your own repo unless explicitly asked to work in another.

## Temp files

- ALWAYS use `.claude/tmp/` for temp files. NEVER use system `/tmp` — it's shared between all agents and users on this machine.

## Self-review

- After completing any task, re-read the original request and verify you fulfilled it properly. Iterative work beats one-shot.
- The spinach rule (`how-to-politely-correct-someone.md`) applies to your own and sub-agents' output — you are responsible for the quality of anything you report.
