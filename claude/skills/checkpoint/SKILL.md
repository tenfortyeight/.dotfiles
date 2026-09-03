---
name: checkpoint
description: >
  Use when the user types /checkpoint, or proactively in long/complex sessions
  (past ~4 hours, ~15 commits, or when an output-token-limit risk is realistic)
  to dump current state to a markdown file so work can survive a session death
  and be resumed cleanly in a fresh session.
user-invocable: true
---

# /checkpoint — Save Session State for Resume

Long sessions occasionally die from output-token-limit errors mid-investigation, taking unrecoverable context with them. `/checkpoint` writes a self-contained handoff file so a fresh session can pick up exactly where this one stopped.

## When to run

- User types `/checkpoint` (manual).
- **Proactively suggest** running it when:
  - Session is past ~4 hours of active work, OR
  - More than ~15 commits have shipped on the current branch, OR
  - You're mid-investigation across many files and context is getting heavy, OR
  - The user is about to step away from a session that's mid-flight.

Suggest, don't auto-run — the user decides.

## What to write

Write to `.claude/checkpoints/YYYY-MM-DD-<short-topic>.md` (relative to the current working repo, not `~/.claude/`). If `.claude/checkpoints/` doesn't exist, create it. Use a short kebab-case topic (e.g. `forge-chat-migration`, `issue-58-quality-baseline`).

The file must be self-contained — readable by a fresh session with **zero** prior context.

```markdown
# Checkpoint: <topic>

Date: YYYY-MM-DD
Branch: <branch-name>
Repo: <repo-name>

## Goal
<1–3 sentences: what we set out to do, in plain language. Include the originating issue/PR if any.>

## Done
- <commit/change 1 — short description>
- <commit/change 2>
- ...

## In progress
- **What:** <the slice currently being worked>
- **Files touched:** <absolute or repo-relative paths>
- **Last hypothesis / mental model:** <one paragraph: what you believe is true about the problem right now>
- **Last action taken:** <last command run or last edit made>
- **Last result:** <output, error, or observation that ended the session>

## Next steps
1. <smallest next concrete action>
2. <next>
3. <next>

## Open questions for the user
- <question 1, if any>
- <question 2>

## Relevant context
- <links to issues, PRs, dashboards>
- <key file paths the next session must read first>
- <any non-obvious env state: AWS_PROFILE, kube context, feature flags>
```

Sections that don't apply can be omitted, but **In progress** and **Next steps** are mandatory — those are the resume seam.

## Rules

- **Do not** dump full file contents or large diffs into the checkpoint. Reference paths and let the next session read them. The checkpoint is a map, not an archive.
- **Do not** speculate beyond what's already known. If a hypothesis is unverified, mark it as such.
- **Do** include the exact next command(s) when known — saves the next session a discovery loop.
- **Do** record AWS profile / kube context if either matters for the next step.
- Verify the file was written, then tell the user the path and a one-line summary so they know where to point a fresh session.

## Resuming from a checkpoint

When the user starts a new session with "resume from `.claude/checkpoints/<file>`" (or similar):

1. Read the checkpoint file fully.
2. Read every file path it lists under **In progress** / **Relevant context**.
3. Verify any state claims (branch is correct, AWS_PROFILE matches, file paths still exist).
4. Confirm the goal with the user before continuing — point out anything in the checkpoint that looks stale.
5. Then start from the top of **Next steps**.

## What /checkpoint does NOT do

- Does not commit, push, or run tests.
- Does not modify code.
- Does not stop or rewind work — it's purely a snapshot.
