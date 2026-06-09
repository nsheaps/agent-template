# Marketplace & plugins

The agent's capabilities (skills, commands, hooks, subagents) come largely from **plugins** installed from a Claude Code plugin **marketplace**, plus the repo-local `.claude/skills|commands|agents`.

## How it's wired

- **Marketplace registration** and **enabled plugins** live in `.claude/settings.json` (repo-scope, committed) — this is canonical and survives restarts. Do not rely on user-scope (`$CLAUDE_CONFIG_DIR/settings*.json`); it gets wiped on restart.
- `.claude/plugins.settings.yaml` holds per-plugin configuration (e.g. `1pass`, `github-app` references; channel config).
- `bin/install-plugins` materializes the marketplace and enabled plugins into the plugin cache.

## Steps

1. Register the marketplace your org publishes from in `.claude/settings.json` (the marketplace source / known marketplaces).
2. Enable the plugins this agent needs under `enabledPlugins` — common ones: `1pass`, `github-app`, `mise`, `github`, `common-sense`, `agentic-behavior`, `scm-utils`, plus channel plugins (`discord`/`telegram`).
3. Provide each plugin's config in `.claude/plugins.settings.yaml`.
4. Run `bin/install-plugins` (the launcher also handles this on start).
5. Verify enabled plugins resolve and their skills appear.

## Rules

- NEVER use `claude plugin marketplace remove` to *update* a marketplace — it unconfigures every plugin from it. Use `claude plugin marketplace update` instead (`.claude/rules/plugin-safety.md`).
- Local repo skills take precedence over plugin skills (`.claude/rules/skill-resolution-order.md`); stabilized local skills should migrate upstream into a plugin.
- Put persistent config in **repo-scope**, not user-scope (`agent-utils:what-survives-agent-restart`).
