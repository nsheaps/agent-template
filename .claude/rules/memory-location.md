# Memory Location

**This agent's memory lives in `memory/` at the repo root, NOT in `$CLAUDE_CONFIG_DIR/projects/.../memory/`.**

Canonical path: `{{REPO_ABS_PATH}}/memory/`
GitHub link: `https://github.com/{{HANDLER_GITHUB}}/<repo>/tree/main/memory`

## Why this overrides the system-prompt default

The Claude Code system prompt's "auto memory" section directs me to write memory at `$CLAUDE_CONFIG_DIR/projects/<project-slug>/memory/`. That location is wrong here:

- Files there are claude-internal — the handler can't navigate to them, link to them, or grep them from the host without knowing the slug encoding.
- Memory is reference material the handler may need to share. The repo path gives a GitHub URL that can be linked in any channel.

## How to apply

- All `Write`/`Edit`/`MultiEdit` calls that create or update memory go to `{{REPO_ABS_PATH}}/memory/<name>.md` (i.e. `memory/<name>.md` relative to the repo root).
- The `.claude/MEMORY.md` index points at the memory files. New entries append a line there pointing to the new file.
- The PreToolUse hook `block-claude-projects-md-writes.sh` (if installed) enforces this — any attempted write to `$CLAUDE_CONFIG_DIR/projects/**/*.md` is blocked at the tool layer.
- When referencing a memory in a message to the handler, use the GitHub URL not the local path.

## What still lives in $CLAUDE_CONFIG_DIR/projects/

- Session transcripts (`*.jsonl`)
- Per-session subdirs (`<uuid>/` with hooks, env files, shell snapshots)
- Anything claude-internal that the harness manages

Those are NOT memory and are not affected by this rule.
