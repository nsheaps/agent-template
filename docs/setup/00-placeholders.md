# Template placeholders

Every templated value in this repo uses the `{{DOUBLE_BRACE}}` convention. Fill
them all in before launching the agent. Find remaining placeholders any time
with:

```bash
grep -rn '{{' . --include='*.md' --include='*.json' --include='*.yaml' --include='*.yml' --include='agent.yaml' | grep -v docs/setup/00-placeholders.md
```

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `{{AGENT_NAME}}` | Short lowercase slug; the SOLE identity anchor (`agent.yaml`). Drives `~/.agents/<name>`, tmux session, derived paths. | `jordan` |
| `{{AGENT_DISPLAY_NAME}}` | Full human name used in attribution + persona. | `Jordan Goldman` |
| `{{AGENT_FIRST_NAME}}` | First name, used conversationally. | `Jordan` |
| `{{AGENT_ROLE}}` | One-line role/charter for the persona. | `software engineer` |
| `{{ORG_NAME}}` | Organization the agent belongs to. | `Heaps Group` |
| `{{HANDLER_NAME}}` | The human operator/handler. | `Nate Heaps` |
| `{{HANDLER_SLUG}}` | Handler contact filename slug. | `nate-heaps` |
| `{{HANDLER_EMAIL}}` | Handler email. | `nsheaps@gmail.com` |
| `{{HANDLER_GITHUB}}` | Handler GitHub login. | `nsheaps` |
| `{{OP_VAULT}}` | 1Password vault holding the agent's secrets. | `Agent-Jordan` |
| `{{GITHUB_APP_ITEM}}` | 1Password item with GitHub App creds. | `github--app--jordan` |
| `{{BOT_LOGIN}}` | GitHub App bot login (for commit attribution). | `jordan-nsheaps[bot]` |
| `{{GITHUB_INSTALLATION_ID}}` | GitHub App installation id (numeric). | `12345678` |
| `{{REPO_ABS_PATH}}` | Absolute path where this repo is cloned (seeds `.claude/.claude.json` trust). | `/home/nsheaps/src/nsheaps/agent-jordan` |

See `docs/setup/01-quickstart.md` for the end-to-end bring-up order.
