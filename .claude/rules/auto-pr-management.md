# Automatic PR Creation and Updates

## Rule: Every Branch Gets a PR

**All sessions MUST automatically create and maintain a pull request for their working branch.**

## Rule: Every PR Gets a Sub-Agent

**CRITICAL:** All PR work (creation, updates, feedback addressing, rebasing, conflict resolution) MUST be delegated to a sub-agent. Never do PR work directly in the main context.

**Why:** PR operations produce large diffs, API responses, and file changes that bloat the main context window. Sub-agents isolate this content and return only a summary. This keeps the main context responsive to handler messages.

**How:** When you need to create, update, or fix a PR:

1. Launch a sub-agent with `run_in_background: true`
2. Include all necessary context in the prompt (branch name, what to change, GH_TOKEN path, git identity)
3. The sub-agent handles: branching, commits, push, PR creation/update, review comment responses
4. Main agent receives a concise summary with PR URL and key artifacts

Source: Handler directive (2026-04-29): "from here on out every PR gets a sub-agent"

## When to Create a PR

Create a PR **after the first push** to a new branch. Do not wait for the user to ask.

## When to Update a PR

Update the PR description **after every push** to reflect the current state of changes. Keep the description accurate and up-to-date as work progresses.

## Keep Branch Up to Date Before Every Push

**CRITICAL:** Before every push, merge the latest `origin/main` into the branch. **Do NOT rebase** — prefer merge to preserve history.

1. `git fetch origin main`
2. Check if there are upstream commits: `git log --oneline HEAD..origin/main`
3. If there are ANY commits behind, merge: `git merge origin/main`
4. Resolve any conflicts, then push

**Why merge over rebase:** Rebasing rewrites history. Prefer merge to preserve the full commit history and avoid force pushes — only rebase if the handler explicitly asks for it.

## How to Authenticate

Use the `GH_TOKEN` environment variable with the `gh` CLI. Since the git remote in web sessions is a local proxy, use `gh api` with `--hostname github.com` for all GitHub API calls (not `gh pr create` which requires a GitHub remote).

The `gh` CLI should already be configured via the mise or GitHub claude-code plugin. If `gh` is not available, investigate the startup hooks for those plugins..

## Creating a PR

**Always create PRs as drafts.** After creation, add the `request-review` label to trigger an AI code review.

- Target the default branch (usually `main`) unless the task specifies otherwise
- Include a session link if available (format: `https://claude.ai/code/session_XXXXX`)

## Updating an Existing PR

After subsequent pushes, update the PR body to reflect all changes.

## Checking for an Existing PR

Before creating, check if a PR already exists for the current branch. If one exists, update it instead of creating a new one. Use server-side filtering (e.g. `?head=nsheaps:<branch-name>&state=open`) for efficiency.

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## PR Lifecycle

1. **Create as draft** — all new PRs start as drafts
2. **Add `request-review` label** — triggers AI code review automatically
3. **Monitor for review completion** — check `gh api repos/.../pulls/N/reviews` after CI finishes (see below)
4. **Address review feedback** — fix any issues found by the AI review
5. **Mark ready** when work is complete and CI passes

## Monitor for Reviews After Pushing

**CRITICAL:** After pushing a PR, do NOT just check CI status and declare "waiting for review." The CI review workflow produces a review that you must act on.

After pushing to a PR with `request-review` label:

1. Check CI status (statusCheckRollup) — wait for completion
2. **Immediately check for reviews**: `gh api repos/{owner}/{repo}/pulls/{N}/reviews`
3. **Also check for inline comments**: `gh api repos/{owner}/{repo}/pulls/{N}/comments`
4. If reviews exist, read and address them — do not wait to be told

The review workflow typically completes within 2-3 minutes of a push. If you report "waiting for review" when a review has already been posted, that is a failure — it wastes the handler's time and shows you didn't actually check.

**Anti-pattern:** Checking `statusCheckRollup`, seeing "claude-review: SKIPPED/SUCCESS", and assuming no review exists. The review is posted as a PR review comment, not through the check status API.

Why this matters: reporting a PR as "waiting for review" when a review has already been posted wastes the handler's time and signals you did not actually check. The review is posted as a PR review (and/or inline comments), not as a check-status entry.
