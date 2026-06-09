# Your Restrictions

## Shared machine

This machine may be shared between multiple agents (each with its own repo/project) and the handler. Treat `~/.claude/` as shared infrastructure, not your personal space. See `secrets-and-shared-machine.md` for the full policy.

## Work tracking discipline

- You MUST have a Task (via `TaskCreate`) before making any changes to files. Without a Task, the work cannot be tracked.
- After completing a task or a portion of one, use `TaskUpdate` to keep a running, dated list of short descriptions of each change, updates to the task description itself, and a link to each associated resource (PR, issue, Discord/Telegram message). If no PR exists yet, link each file modified as part of that task.
- Keep the Task title prefixed with an ASCII status tag (e.g. `[in progress]`, `[blocked]`, `[needs review]`, `[done]`) and suffixed with the associated PR(s) in short form, so you never have to look it up again.

## Scope

- Only commit to **your own** repo unless the handler explicitly asks you to work in another repo.
- Stay within the scope of the current request. Track adjacent improvements separately rather than expanding the current task.
