# Scheduled Tasks — Persistence Rules

Crons created with CronCreate are session-only and die on TRUE SESSION RESTART (process exit). To survive restarts, scheduled tasks are persisted to `.claude/scheduled-tasks.yaml`.

**Important distinction (added 2026-05-17 after a duplicate-cron incident):** COMPACTION CONTINUATION (when the conversation memory rolls forward mid-session but the process stays alive) preserves in-memory crons. The session-start banner says "This session is being continued from a previous conversation that ran out of context" — that's compaction, NOT a restart, and existing crons are still firing. Re-creating them blindly produces duplicates that fire 2× per tick (thundering herd at the API level + wasted work).

## On Session Start

ALWAYS dedupe via CronList BEFORE recreating from `.claude/scheduled-tasks.yaml`.

Steps:

1. Call `CronList` and capture the set of currently-active `(cron, prompt)` pairs (match on cron expression + a substring of the prompt — the full prompt may be truncated in the listing).
2. Read `.claude/scheduled-tasks.yaml`.
3. For each task where `enabled: true`:
   - If a matching active cron already exists in the CronList result → SKIP (do not CronCreate; the existing cron is still good).
   - Otherwise → call CronCreate with the task's `cron` and `prompt`, set `recurring` per the task's `recurring` field.
4. **Catch-up check** (only for crons you actually CronCreate'd just now — not for ones that were already active): if the task should have fired while the session was down, fire it immediately.
5. Do this silently as part of session initialization — no need to announce it to the handler.

If the file does not exist or is empty, skip without error. If CronList returns crons that are NOT in the yaml (handler removed them between sessions, or stale from a prior session), leave them alone unless they clearly conflict with what the yaml declares — destructive cleanup belongs to a separate housekeeping task with handler ack.

## When Creating a New Cron

After calling CronCreate to schedule a new recurring task:

1. Add the task to `.claude/scheduled-tasks.yaml` with appropriate fields
2. Set `recurring: true` if it should persist across restarts, `false` if one-shot
3. Commit the updated file (it is checked into the repo)

## When Deleting a Cron

After calling CronDelete (or when a one-shot task fires and completes):

1. Remove the task entry from `.claude/scheduled-tasks.yaml`, OR set `enabled: false`
2. Commit the updated file

## When Modifying a Cron

If a cron's schedule or prompt needs to change:

1. Delete the old cron via CronDelete
2. Create the new cron via CronCreate
3. Update the entry in `.claude/scheduled-tasks.yaml`
4. Commit

## File Location

`.claude/scheduled-tasks.yaml` — checked into the repo, human-editable.
The handler can edit this file directly between sessions to add/remove/modify tasks.
The agent must honor changes made by the handler without requiring a session to be active.

## Deduplication on Restore

CronCreate does not deduplicate — calling it twice produces TWO independent crons firing on the same schedule. On session start, the "On Session Start" steps above already enforce CronList-first dedup; the previous wording ("safe to assume no crons are active") was wrong for compaction continuation and is removed.
