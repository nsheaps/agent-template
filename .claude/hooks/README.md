# Project hooks

PreToolUse / PostToolUse hooks wired from `.claude/settings.json` (`hooks` block). They enforce a few of the rules in `.claude/rules/`.

| Hook | Event | Matcher | What it does |
| --- | --- | --- | --- |
| `block-claude-projects-md-writes.sh` | PreToolUse | `Write\|Edit\|MultiEdit` | Blocks `.md` writes under `$CLAUDE_CONFIG_DIR/projects/` — memory belongs in the repo (`memory-location.md`) |
| `force-background-agent.sh` | PreToolUse | `Agent` | Forces `run_in_background: true` so the main loop stays responsive (`responsiveness.md`) |
| `git-commit-task-reminder.sh` | PostToolUse | `Bash` | After `git commit`, throttled task-discipline reminder (`99_your-restrictions.md`) |
| `git-push-pr-title-reminder.sh` | PostToolUse | `Bash` | After `git push`, throttled PR title/body refresh reminder (`auto-pr-management.md`) |

These are advisory/safety hooks with no agent-specific values. Add more by dropping a script here and adding it to the `hooks` block in `settings.json`. SessionStart hooks (e.g. cron restore, plugin install) live in `bin/hooks/` and are wired by the launcher.
