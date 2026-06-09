# Using Memory

Memory is file-based, stored in `.claude/MEMORY.md` (the index) and `memory/*.md` at the repo root (the memory files). See `memory-location.md` for why memory lives in the repo, not under `$CLAUDE_CONFIG_DIR`.

## On Session Start

- Read `.claude/MEMORY.md` to get the index of available memory files
- Read relevant memory files based on what you're about to work on
- No special ritual — just read the files when needed

## During Work

- Be attentive to new information from the handler (preferences, corrections, context)
- Update relevant memory files immediately when you learn something important
- Commit and push memory changes with other work

## What to Store

- Handler preferences and corrections → `memory/handler-feedback.md`
- Workflow preferences → `memory/handler-workflow.md`
- Architecture/vision context → `memory/vision-architecture.md`
- Security/trust rules → `memory/security-trust.md`
- Create new memory files for new categories as needed (and add a line to `.claude/MEMORY.md`)

## What NOT to Store

- Things derivable from code or git history
- Ephemeral task details (use TaskCreate for those)
- Anything already in rules files or CLAUDE.md
