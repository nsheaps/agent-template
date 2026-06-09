# Research Output Rules

## Sub-Agent Research MUST Go to docs/research/

ALL research output from sub-agents MUST be saved to `docs/research/`, never to `.claude/tmp/` or system `/tmp`.

This has been a recurring failure: sub-agents save research findings to `.claude/tmp/` which is treated as ephemeral and gets lost. Research findings are permanent artifacts.

## How to Prompt Sub-Agents for Research

When prompting a sub-agent to do research, ALWAYS specify the output path explicitly:

**GOOD:**

```
Research X and save your findings to docs/research/X-findings.md.
Include sources, key conclusions, and recommendations.
```

**BAD:**

```
Research X and save your findings somewhere.
```

or

```
Research X and save to .claude/tmp/X-research.md
```

The output path in the prompt MUST be `docs/research/<descriptive-name>.md`.

## After Research Completes

After any sub-agent completes research:

1. **Verify the file exists** at `docs/research/` — read it to confirm
2. **Commit the file** to git on main branch
3. **Push to origin** so it survives session restarts

Do NOT leave research files uncommitted. A research file that is not committed can be lost.

## Research Must Be on Main

Research files belong on `main`, not on feature branches. If you are on a feature branch:

1. Either commit research to main first (stash feature changes, checkout main, commit research, return to feature branch)
2. Or wait until the feature branch is merged, then ensure the research files are included

Research files committed only to a feature branch are at risk of being lost if the branch is deleted or rebased.

## File Naming Convention

```
docs/research/<topic-or-technology>.md          # general research
docs/research/<topic>-investigation.md          # debugging / root cause analysis
docs/research/<topic>-audit-YYYYMMDD.md         # dated audits
docs/research/self-improvement-report-YYYY-MM-DD.md  # self-improvement reports
```

Use descriptive names. Avoid generic names like `research.md` or `findings.md`.

## What Belongs Here vs Tmp

| Content                                       | Location         |
| --------------------------------------------- | ---------------- |
| Research findings, analysis, investigations   | `docs/research/` |
| Technology evaluations, tool comparisons      | `docs/research/` |
| Bug investigations and root cause analysis    | `docs/research/` |
| Self-improvement reports and session analysis | `docs/research/` |
| PR feedback summaries (significant ones)      | `docs/research/` |
| CI log output (single run debugging)          | `.claude/tmp/`   |
| API response JSON (used once, discarded)      | `.claude/tmp/`   |
| Session state files                           | `.claude/tmp/`   |
| PR-specific one-time fixes                    | `.claude/tmp/`   |

## Related Rules

- `file-placement.md` in common-sense plugin — overall file placement policy
- `communication.md` — temp files always use `.claude/tmp/`, never system `/tmp`
