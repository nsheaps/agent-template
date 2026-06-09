---
name: skill-resolution-order
description: When multiple skills with the same purpose exist, prefer the one in this repo over plugin-provided skills
type: feedback
---

# Skill Resolution Order

When more than one skill could apply to a task, resolve in this order:

1. **`.claude/skills/` in this repo** — wins, always
2. **Plugin-provided skills** (e.g. `agentic-behavior:*`, `scm-utils:*`) — fallback

## Why

Skills checked into this repo are intentionally faster to iterate — no PR cycle against the plugin marketplace, no plugin version bumps, no review handoff. Once a local skill stabilizes and is clearly reusable across agents, migrate it to a plugin.

## How to apply

- Before invoking `Skill(<name>)`, check `.claude/skills/<name>/` in this repo. If present, use it.
- This OVERRIDES `using-skills-and-plugins.md` in common-sense for cases where a local skill exists with the same name/purpose as a plugin skill.
- Specific overrides (use local instead of plugin):
  - Debugging-the-agent skills: use `.claude/skills/debug-*` (local), NOT `agentic-behavior:correct-behavior` or `agentic-behavior:incident-tracker` for the _debugging_ portion. Those plugin skills are still authoritative for incident _reports_ and behavior corrections — just not the front-line debugging workflow.
- All local skills MUST be candidates to upstream into a plugin eventually. Mark each local SKILL.md with a `<!-- UPSTREAM: <target-plugin> -->` HTML comment near the top so we can sweep them later.
