# Secrets & Shared Machine Rules

This machine may be shared between multiple agents (each with its own repo/project) and the handler. Treat `~/.claude/` as shared infrastructure, not this agent's personal space.

## If a secret leaks

If a secret value ever appears in the transcript, tell the handler immediately so the affected token(s) can be rotated. Conversation history is stored in plaintext — a leaked secret is leaked permanently. The avoidance patterns below exist to prevent leaks in the first place; never intentionally read secret-bearing files.

## Never Write Agent-Specific Config to User-Level Paths

- Do NOT write to `~/.claude/channels/`, `~/.claude/settings.local.json`, or any `~/.claude/` path for agent-specific configuration
- All agent-specific config belongs in the project directory (`.claude/` within the repo)
- User-level paths are shared between all agents on this machine

## Secret Handling

### Never expose secret values in conversation — ANY method

Secret-bearing env vars include: `*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`, `*_PEM`, `OP_SERVICE_ACCOUNT_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`, `GITHUB_APP_PRIVATE_KEY*`, `DISCORD_BOT_TOKEN`, etc.

- Do NOT use `op item get` piped through `jq` or any text processing
- Do NOT use `op read` to capture a value into a variable or file in conversation
- Do NOT use `env`, `printenv`, or `set` without filtering — they dump ALL env vars including secrets
- Do NOT use `echo $VAR`, `printf "$VAR"`, or any bash expansion that prints a secret value
- Do NOT pipe env var output to grep/awk/sed — the secret still appears in conversation
- Do NOT use `cat` on files that contain secrets (token files, PEM files, .env files with real values)
- Do NOT use `tr '\0' '\n' < /proc/<pid>/environ` or any other trick that dumps a process's full env — process env contains every secret the parent injected, including `OP_SERVICE_ACCOUNT_TOKEN`, `GH_TOKEN`, `*_PRIVATE_KEY`, etc. Even with a grep filter, multi-line values (PEM keys) and any non-prefixed secret env will slip through.
- Do NOT use `jq '.<filter>' settings.local.json` (or `.env // {}` or any open-ended filter) on a settings file that could contain root-level secrets. `settings.local.json` files ROUTINELY hold `OP_SERVICE_ACCOUNT_TOKEN`, `_ANTHROPIC_AUTH_TOKEN`, etc. AT THE ROOT, not nested under `.env`. A `// {}` fallback does not filter anything — it just provides a default if `.env` is missing, and jq prints whatever the path resolves to. **If the file has secret-like keys, jq will print them.**

### Safe ways to inspect settings/config files

When you need to read a settings file but suspect it might contain secrets:

```bash
# Safe: list ONLY the keys (names), no values
jq 'keys' settings.local.json
jq -r 'paths(scalars) | join(".")' settings.local.json   # all leaf paths

# Safe: read ONE specific key you've already vetted as non-secret
jq -r '.includeCoAuthoredBy' settings.local.json
jq -r '.permissions.defaultMode' settings.local.json

# Safe: check if a key exists without printing its value
jq -e 'has("OP_SERVICE_ACCOUNT_TOKEN")' settings.local.json

# UNSAFE — NEVER DO THIS:
cat settings.local.json                    # dumps everything
jq '.' settings.local.json                  # dumps everything
jq '.env // {}' settings.local.json         # if .env is missing, jq prints {} BUT if .env is missing because secrets are at root, you might switch to a filter that DOES match — never do that recursively
jq '.env // .' settings.local.json          # the `// .` fallback prints the WHOLE file if .env is missing
```

Before reading a settings/config file, ask: _can secrets live in this file?_ If yes, get keys first, then read individual keys you've confirmed are non-secret. NEVER print a value whose key matches `*_TOKEN|*_KEY|*_SECRET|*_PASSWORD|*_PEM|OP_*`.

- Conversation history is stored in plaintext — any secret that appears is leaked permanently

### Safe ways to inspect a process's env

When you need to know whether a specific env var is set in a running process, NEVER read `/proc/<pid>/environ` directly. Instead:

```bash
# Safe: check if a specific var is present (count only, no value)
grep -c '^GIT_AUTHOR_NAME=' /proc/<pid>/environ 2>/dev/null

# Safe: list KEYS only (split on null, drop the value via cut)
tr '\0' '\n' < /proc/<pid>/environ | cut -d= -f1 | sort

# Safe: check the LENGTH of a single non-secret value (paths, names)
awk -v RS='\0' '/^GIT_CONFIG_GLOBAL=/{sub(/^[^=]+=/,""); print length}' /proc/<pid>/environ
```

NEVER print the actual value. NEVER grep for `^OP_|^GH_TOKEN|^GITHUB_TOKEN|^*_PRIVATE_KEY|^*_SECRET|^*_PASSWORD` or any pattern that would print a secret-bearing line.

### Safe ways to inspect a process tree

NEVER use any command that prints a process's full command line (`ps -ef`, `ps aux`, `pgrep -af`, `pgrep -al`, `pstree -a`, `/proc/<pid>/cmdline`). On this machine, agent launchers are commonly invoked via `bash -c "export TOKEN=value && exec ..."` — every secret the parent injected is in the process's argv permanently. A pattern filter does NOT help: `pgrep -af 'name'` matches the regex against the FULL command line, so even when you target an unrelated process the matcher can land on the credential-laden one (and `-a` then prints all of it).

Safe patterns (PIDs and short comm names only — never argv):

```bash
# Safe: list PIDs matching a name; no command line output
pgrep <name>                     # PIDs only
pgrep -l <name>                  # PID + 15-char comm (NOT full argv)

# Safe: format-controlled ps with no cmd field
ps -o pid,etime,comm <pid>       # comm = exec name only (15 chars)
ps -o pid,etime,stat,comm        # all PIDs, no argv

# Safe: tmux session check (no process introspection)
tmux has-session -t <name> 2>/dev/null

# UNSAFE — NEVER:
ps -ef                           # cmdline column dumps argv (includes export TOKEN=…)
ps aux                           # same
pgrep -af <pat>                  # -a prints argv; -f matches against argv
pgrep -al <pat>                  # same
cat /proc/<pid>/cmdline          # raw argv with NUL separators
pstree -a                        # -a shows argv
```

Documented leak failure modes (learned from real incidents — keep these):

- Dumping a process environment via `tr '\0' '\n' < /proc/<pid>/environ | grep ^OP_` leaked an `OP_SERVICE_ACCOUNT_TOKEN`: the grep matched the prefix and printed the full multi-line value.
- `jq '.env // {}' settings.local.json` leaked tokens because the secrets were at the JSON root, not under `.env` — the `// {}` fallback does not filter anything else out.
- `ps -ef | grep …` leaked `DISCORD_BOT_TOKEN`, `OP_SERVICE_ACCOUNT_TOKEN`, `TELEGRAM_BOT_TOKEN`, and a partial `GITHUB_APP_PRIVATE_KEY`: agents are commonly launched by an outer `sh -c "export TOKEN=val … && exec …"`, so every secret is in the process argv and `ps -ef` dumps argv unconditionally.
- `pgrep -af <pat>` / `pgrep -laf <pat>` re-leaked the same secrets: the matcher latched onto the launcher shell whose argv contained `export TOKEN=...`. Lesson: there is **no safe argv-printing pattern**. To find a process by name use `pgrep <name>` (PIDs only) or `pgrep -l <name>` (PID + 15-char comm). To inspect a PID's parent chain use `ps -o pid,ppid,etime,comm -p <pid>`. NEVER use `-af`, `-laf`, `ps aux`, or any flag that includes the cmdline column.
- `head`/`tail`/`cat`/Read on files under `~/.claude/session-env/<uuid>/` dumped every injected secret: those files are written by the 1Password plugin's secret aggregator and contain all secrets as `export VAR=value` lines. NEVER read them with cat/head/tail/Read; use `grep -l <pattern>` (filenames only) or `grep -c <pattern>` (counts only) and `rm`/`find -delete` to clean up.

### Use runtime injection instead

- Use `op run` or `op-exec` to inject secrets into process environments at startup
- Use plugin config mechanisms (plugins.settings.yaml) to declare `op://` references
- Let plugins handle their own secret resolution internally
- Configure MCP servers to receive secrets via environment injection, not file writes

### When a plugin needs a secret

1. First: check if the plugin supports `op://` references in its config
2. Second: check if op-exec can wrap the server startup command
3. Third: use `op run --env-file` with a template `.env` containing `op://` references
4. Last resort: ask the handler for guidance — do not improvise

## Verifying Auth Status

- Use tool-specific status commands: `op whoami`, `gh auth status`
- For env vars, use ONLY these safe patterns:

  ```bash
  # Safe: check if set + length
  [[ -n "${GH_TOKEN:-}" ]] && echo "GH_TOKEN is set (${#GH_TOKEN} chars)" || echo "GH_TOKEN is not set"

  # Safe: check env var existence without value
  env | grep -c '^GH_TOKEN=' # prints count (0 or 1), not value

  # UNSAFE — NEVER DO THIS:
  echo "$GH_TOKEN"          # prints the secret
  env | grep GH_TOKEN       # prints NAME=VALUE including the secret
  printenv GH_TOKEN          # prints the secret
  env                        # dumps ALL vars including secrets
  ```

- Never print the actual value, even partially beyond first few chars
- To verify a secret works, test its **effect** (does `gh auth status` succeed?) not its value
