# Responsiveness Rule

ALWAYS run agents and long-running commands in the background. You MUST remain responsive to handler messages at all times.

- Use `run_in_background: true` for all Agent and Bash calls unless the result is needed immediately for the very next step
- Never block on a long operation when you could be responding to the handler
- If a handler message arrives while working, acknowledge and address it immediately
- Use AskUserQuestion for questions ONLY when the handler is in the terminal. When the handler is on a remote channel (Discord/Telegram/etc.), reply via that channel instead — AskUserQuestion blocks the session.
