---
name: scope
description: >
  Use when the user types /scope, or proactively at the start of any
  multi-step task (3+ commits, multiple files, or a fuzzy ask) to lock
  in a numbered checklist of every in-scope deliverable — including
  implied items — and get user approval before any code changes.
user-invocable: true
---

# /scope — Lock In the Full Scope Before Coding

Multi-step plans drift when scope is implicit. `/scope` forces an explicit, numbered checklist *before* any code changes, gets the user to approve it, and uses it as the cutoff so the work doesn't end half-done.

## When to run

- User types `/scope`.
- **Proactively run** at the start of any task that:
  - Touches 3+ files, OR
  - Implies multiple commits, OR
  - Spans multiple repos / services, OR
  - Has fuzzy edges (e.g. "clean up X", "migrate Y", "fix the issues in Z").

Trivial tasks (one-line typo fix, single config tweak) skip this — use judgment.

## How to run

### 1. Enumerate everything

Read the user's ask and produce a numbered checklist that includes:

- **Stated items** — what the user explicitly mentioned.
- **Implied items** — what's necessary to actually finish the task (tests, docs, migrations, deploys, issue updates, follow-up cleanups, regression checks). Be explicit that these are *implied* so the user can confirm or trim.
- **Out of scope** — a short list of what you're *not* doing, to surface assumptions.

Format:

```
## Scope for: <one-line task summary>

### In scope
1. <stated item>
2. <stated item>
3. <implied: tests for X> ← inferred
4. <implied: update Grafana panel referencing renamed metric> ← inferred
5. ...

### Out of scope (please confirm)
- <thing I'm NOT doing>
- <thing I'm NOT doing>

### Open questions
- <anything I need clarified before starting>
```

### 2. Wait for approval

**Do not start coding.** Ask the user explicitly: "Approve this scope, or tell me what to add/remove/clarify?"

If the user adds/removes items, update the checklist and re-show. Only proceed once they've said yes (or equivalent).

### 3. Treat the list as the cutoff

Once approved:

- The checklist *is* the definition of done. Don't stop early ("9 of 12 commits, waiting for next prompt") — work through every item.
- If you discover a new item mid-flight that should be in scope, surface it to the user before silently adding it.
- If something turns out to be infeasible or unwise, surface it and ask for direction — don't drop it silently.

### 4. Track progress

Mirror the checklist into TaskCreate / TaskUpdate so progress is visible. Mark items completed as they finish, not in batches.

## Authoritative inventories, not estimates

When the scope involves "all the X that need Y" (cleanup, backfill, migration count):

- **Query the source of truth** — `gh issue list`, `git log`, a SQL count, `kubectl get`, `find`. Don't estimate from a sample.
- Include the exact count or the query you used in the checklist, so the user can sanity-check.

## What /scope does NOT do

- Does not modify code, files, or git state.
- Does not commit or deploy.
- Does not promise the work is small — its job is to make the work *visible*, even when it's larger than the user expected.

## Pairs naturally with

- `/go` (and `/go tdd`) — `/scope` defines what to ship; `/go` ships each slice via TDD; `/checkpoint` saves state if the session goes long.
