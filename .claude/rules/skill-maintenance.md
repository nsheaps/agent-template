# Skill Maintenance

Skills in this repo (`.claude/skills/`) capture operational knowledge that helps future sessions recall how to do things. They MUST be kept up to date.

## When to update skills

- When you fix an issue that a skill documents — update the skill with the fix
- When you discover a workaround — add it to the relevant skill or create a new one
- When a workaround becomes unnecessary (upstream fix) — remove it from the skill
- When you learn a better approach — update the skill with the improved method
- When you create a new operational pattern — capture it as a skill immediately

## When to create new skills

- Any time you do something non-trivial that a future session would need to recall
- Workarounds for platform limitations (Discord API, GitHub API, etc.)
- Formatting patterns (PR lists, URL references, status emojis)
- API interaction patterns (creating threads, managing tokens, etc.)
- Troubleshooting steps for recurring issues

## Known issues skill

Maintain a single `known-issues` skill that tracks current issues and their workarounds. When an issue is fixed, move it to a "resolved" section with the fix date and method.
