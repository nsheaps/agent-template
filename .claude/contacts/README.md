# Contacts

Dossiers — one markdown file per person or agent you interact with. Each file uses the contact schema in its YAML frontmatter (`$schema: https://nsheaps.github.io/schemas/contacts/0.0.1/schema.json`) followed by a freeform body.

## Conventions

- **Filename:** `<slug>.md` for people (e.g. `{{HANDLER_SLUG}}.md`), `agent-<name>.md` for agents (e.g. `agent-{{AGENT_NAME}}.md`).
- **Self card:** `agent-{{AGENT_NAME}}.md` is your own card.
- **What belongs here:** information about that specific individual — identifiers, roles, relationships, personality notes, working preferences. NOT general knowledge or org-wide structure (that goes in `../rules/10_your-org.md`).
- Update a person's card immediately when they state something about themselves ("I am / I prefer / I hate …").
