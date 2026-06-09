# Architecture

How a launched agent is wired together.

## Identity flows from one file

`agent.yaml`'s `name:` is the single source of truth. The launcher scripts parse it with a minimal `grep`+`sed` (not `yq`) and **never** inherit the name from the environment — this prevents cross-agent contamination on a shared tmux server. Everything per-agent derives from `name`: the XDG home at `~/.agents/<name>`, the tmux session name, and (by convention) the 1Password vault.

## Launch flow

```mermaid
flowchart TD
    A["operator runs<br/>bin/run-and-attach-agent"] --> B["read name from agent.yaml"]
    B --> C{"tmux session<br/>'name' exists?"}
    C -- no --> D["tmux_make_session →<br/>runs 'bash bin/start-agent'"]
    C -- yes --> E["tmux_attach_session"]
    D --> E
    E -. "Ctrl+B D (detach)" .-> F["watchdog loop:<br/>reattach if up,<br/>recreate if dead"]
    F --> C
    E -. "Ctrl+C" .-> Z["exit"]

    subgraph session["inside the tmux session"]
      D --> G["bin/start-agent"]
      G --> H["bin/claude<br/>(wraps Claude Code CLI)"]
      H --> I["SessionStart hooks fire"]
      I --> I1["mise: install/activate tools"]
      I --> I2["1pass: inject op:// secrets<br/>→ CLAUDE_ENV_FILE"]
      I --> I3["github-app: mint installation token<br/>→ GH_TOKEN, bot git identity"]
      I --> I4["plugins (common-sense, agentic-behavior, …):<br/>sync rules, permissions"]
      I --> I5["restore crons from<br/>.claude/scheduled-tasks.yaml"]
      I1 & I2 & I3 & I4 & I5 --> J["agent is live:<br/>reads CLAUDE.md → rules → persona"]
    end
```

The scripts are the source of truth; read them rather than trusting this diagram if they diverge:

- `bin/run-and-attach-agent` — entrypoint: start-if-needed + attach loop (watchdog on detach).
- `bin/run-agent` — start without attaching.
- `bin/attach-agent` — attach to an existing session.
- `bin/start-agent` — what runs *inside* the tmux session; launches `bin/claude`.
- `bin/claude` — wrapper around the Claude Code CLI (flags, system-prompt addendum, logging).
- `bin/lib/`, `bin/helpers/` — shared shell helpers (e.g. `tmux.sh`).
- `bin/install-plugins` — materializes the marketplace + enabled plugins.
- `bin/hooks/` — SessionStart hooks (e.g. cron restore).

## Configuration layers

| Layer | Where | Survives restart? |
| --- | --- | --- |
| Repo-scope settings | `.claude/settings.json` (committed) | ✅ — canonical |
| Plugin settings | `.claude/plugins.settings.yaml` (committed) | ✅ |
| Rules | `.claude/rules/*.md` (committed) + plugin-provided | ✅ |
| Trust seed | `.claude/.claude.json` (committed) | ✅ |
| User-scope settings | `$CLAUDE_CONFIG_DIR/settings*.json` | ❌ — wiped on restart; don't rely on it |
| In-memory crons | created via `CronCreate` at runtime | ❌ — restored from `scheduled-tasks.yaml` |
| Secrets | 1Password, injected per session | ✅ (in 1Password, not the repo) |

Anything that must outlive a restart belongs in a **committed** file. See `.claude/rules/scheduled-tasks.md` and `.claude/rules/memory-location.md`.

## Environment & isolation

- `mise.toml` pins tools; `rc.d/*.sh` activate mise and add `bin/` + the agent bin dir to PATH.
- `.envrc` / `.envrc.template` (direnv) load the per-agent environment.
- Each agent gets an isolated home at `~/.agents/<name>` so multiple agents can share one host without clobbering each other's `~/.claude`, git config, or GH config.

## Runtime data vs. memory

- **Memory** (durable, handler-shareable): `memory/*.md`, indexed by `.claude/MEMORY.md`. NOT under `$CLAUDE_CONFIG_DIR`.
- **Transcripts / session-internal state**: under `$CLAUDE_CONFIG_DIR/projects/...` — managed by the harness, not memory.
- **Temp**: `.claude/tmp/` only (never system `/tmp` on a shared machine).
