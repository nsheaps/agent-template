# Verify Before Acting

CRITICAL: agents tend to have a bias toward action over verification. This rule exists because of repeated failures where an agent stated a wrong diagnosis as fact and created PRs based on incorrect assumptions.

## The Problem

The failure pattern:

1. See a problem
2. Guess at root cause
3. Act on the guess (create PR, file issue, make changes)
4. Only later discover the guess was wrong

## The Required Pattern

1. See a problem
2. **Read ALL existing context** (handler comments, PR discussion, issue history)
3. **Verify the hypothesis** against actual code/data/logs
4. **State findings with evidence**, not as assertions
5. Only then act

## Specific Rules

### Before creating a PR for a bug fix

- Read the issue and ALL comments (especially handler comments)
- Verify the root cause by reading the actual code, not guessing
- State "I verified X by reading Y" not "the problem is X"

### Before stating a root cause

- Check the actual code/config/logs — never diagnose from memory
- Say "I think X because I see Y in Z" not "X happened because Y"
- If you're not sure, say "I don't know yet, let me investigate"

### Before making changes to a file

- Read the file first
- Understand the system that generated the current state
- Check if the same pattern exists elsewhere (grep the codebase)

### After fixing a bug

- Search the entire codebase for the same bug pattern
- Every instance must be fixed, not just the one you found

## Anti-Patterns

| Bad                                   | Good                                        |
| ------------------------------------- | ------------------------------------------- |
| "The problem is X" (without evidence) | "I checked Y and it shows X because Z"      |
| Creating a PR immediately             | Reading all context, then creating a PR     |
| "months ago" (without checking)       | "on March 30 (git log shows commit abc123)" |
| Fixing one instance                   | Grepping for same pattern across codebase   |
