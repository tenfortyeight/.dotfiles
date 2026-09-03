---
name: go
description: >
  Use when the user types /go (outer pre-PR chain: verify → simplify → review →
  adversarial verify → commit → optional PR → optional notify) or /go tdd (inner
  red-green-refactor-commit cycle for one slice of bug/behavior work). Never
  deploys, merges, or force-pushes.
user-invocable: true
---

# /go — TDD Inner Loop + Pre-PR Outer Chain

`/go` has two modes. Pick the one that matches where the user is in the work:

- **Inner loop** (`/go tdd` or starting bug/behavior work) — drives one red→green→refactor→commit cycle.
- **Outer chain** (`/go`, default) — finishing chain that runs verify → simplify → review → commit → optional PR → DM.

**Never deploys. Never merges PRs. Never force-pushes.** Those require explicit user permission per the deploy-permission memory.

---

## Mode 1 — Inner TDD loop (`/go tdd`)

Use this when starting or in the middle of bug/behavior work. Drives **one** cycle. Ask the user to invoke again for the next slice.

Rationale: tight cycles keep each commit reviewable and give design feedback early.

### Cycle steps

1. **Red.** Identify the smallest next slice of behavior (or bug to reproduce). Write **one** failing test for it. Run it. Confirm it fails *for the right reason* — not from a syntax error or wrong import. If the failure mode is wrong, fix the test before continuing.

2. **Green.** Write the **minimum** code to make the test pass. Ugly is allowed. Don't generalize. Don't add features the test doesn't demand. Run the test; confirm it passes. Run the rest of the test suite; confirm nothing else regressed.

3. **Refactor.** Tests stay green throughout. Invoke `/simplify` on the touched files. Look for: duplication, unclear names, leaky boundaries, dead code, accidental complexity. Re-run tests after each refactor step. If refactoring reveals a design problem ("this is hard to test"), surface it to the user before pushing through.

4. **Commit.** Small, focused, oneliner message. Typically two commits per cycle (test, then implementation), or one commit if they're tightly coupled. Use `git commit -m "..."` — no heredocs (the hook blocks them).

### Gates

- If step 1's test passes immediately → wrong test. Stop and ask the user what behavior should be pinned.
- If step 2 needs more than ~20 lines or branches into multiple concerns → slice was too big. Stop, revert, and ask the user to slice smaller.
- If step 3 reveals a structural problem → stop and report; don't refactor your way into a redesign without user input.

### When done with all slices

Tell the user: "TDD slices done — run `/go` for the outer chain when ready." Do not auto-run the outer chain.

---

## Mode 2 — Outer pre-PR chain (`/go`)

Run the steps in order. Each step gates the next — if a step surfaces blockers, stop, report, and wait for the user. Do not paper over issues silently.

### 0. TDD sanity check (heuristic, fast)
Before running the chain, glance at the unpushed commits on the current ref (`git log @{u}..HEAD` if upstream is set, else `git log -n 20`). If the diff touches behavior (non-trivial source files) but **no test files were added or modified across any of those commits**, warn the user:
> "⚠ No test changes detected in unpushed commits. Was this work TDD'd? If this is a bug fix, the failing-test commit should exist. Continue anyway?"
Do not block — just surface. The user might have a legit reason (docs, config, infra-only). Works for both trunk-based work on `main` and feature branches.

### 1. Verify (`/verify`)
Invoke the `verify` skill. This runs file-type validators and environment/profile checks.

**Gate:** If `/verify` reports any `✗ blocker`, stop. Report findings plainly. Do not continue until the user resolves or explicitly says "proceed anyway". Warnings are surfaced but do not block.

### 2. Simplify (`/simplify`)
Invoke the built-in `simplify` skill to review the changed code for reuse opportunities, quality issues, and inefficiencies, and to fix anything it finds.

**Gate:** Let `simplify` apply its changes. After it finishes, re-run `/verify` quickly on the modified files to make sure nothing it changed introduced a validator failure. If it did, stop and report.

### 3. Review (`/review-squad`)
Spawn the review-squad agents (architecture, security, QA, devil's-advocate) **in parallel** via the Agent tool with `subagent_type: general-purpose` — Plan agents go idle without responding to messages, see user preferences.

- Architecture → does this fit the platform design? Patterns consistent across repos?
- Security → secrets exposure, input validation, auth boundaries, OWASP concerns
- QA → testability, missing coverage, boundary conditions
- Devil's advocate → "what breaks?" — race conditions, partial failures, rollback scenarios

**Gate:** Consolidate findings by severity:
- **Blockers** (critical bugs, security issues, architectural violations) → stop, report, wait.
- **Warnings** → surface to user and let them decide.
- **Suggestions** → include in the report, don't block.

Once blockers are resolved, record the receipt so `review-gate.sh` does not re-ask:
`mkdir -p "$(git rev-parse --git-dir)/claude-gates" && echo "<blockers resolved>" > "$(git rev-parse --git-dir)/claude-gates/review-$(git rev-parse HEAD)"`

### 3.5 Adversarial verify (do NOT skip)

Review asks "is this good code?". This asks "is this claim actually true?" — the failure mode that has cost the most rework.

Spawn **one fresh general-purpose agent** and give it ONLY the user's original requirement and the raw diff. **Never** pass it your summary, your reasoning, or your conclusion — a verifier that reads your reasoning re-derives your mistakes. Instruct it to:

- Assume the implementation is subtly wrong and prove correctness **empirically**, not by reading code.
- Query live systems. Confirm every metric, field, endpoint, model and price it touches actually exists by hitting the real API — never a cached table.
- Confirm datasource/query-language compatibility (a Prometheus query against a Loki datasource has shipped before).
- Grep for leftover legacy paths, dead flags, superseded implementations, orphaned tests.
- Confirm **every** acceptance criterion is met, not most of them.

**Gate:** It returns PASS/FAIL with pasted evidence. On FAIL, fix and re-verify — do not argue with it from memory. Do not tell the user the work is done until it returns PASS. Then record:
`echo "<one-line evidence>" > "$(git rev-parse --git-dir)/claude-gates/verify-$(git rev-parse HEAD)"`

This step also runs automatically: `verifier-gate.sh` (a Stop hook) blocks the end of any turn with substantive unverified source changes, so it happens whether or not `/go` was typed.

### 4. Commit in chunks
If nothing is blocking:
- Stage and commit in **small, focused chunks** — do not batch. The user's workflow preference is reviewable history.
- Use simple oneliner commit messages: `git commit -m "message"`. No heredocs, no `$(cat ...)` — the hooks will block these anyway.
- One logical change per commit. Refactors separate from behavior changes separate from test additions.

### 5. Optional PR
Only if the user explicitly asked for a PR (via `/go pr`, `/go --pr`, or similar). On trunk-based workflows (working directly on unprotected `main`) the chain typically ends after step 4 with the commits pushed — no PR needed. Tell the user the work is ready / pushed.

When creating a PR: short title (≤70 chars), body with Summary + Test plan. Use `gh pr create`.

**Never** `gh pr merge`. That's a deploy-shaped action.

### 6. Notify (optional, workspace-specific)

Skip this step unless the current repo declares a notification target — this skill stays
workspace-neutral so it ports between machines and employers unchanged.

If `.claude/notify` exists in the repo root, read it and follow it. Expected shape:
a channel (e.g. `slack`) and a target id, one per line. Send a 3–5 line summary:
- What was changed (one line)
- Verify / review / verifier outcomes
- Commits made, PR link if created
- Anything that needs their attention

No preamble. If the file is absent, say nothing and end the chain at step 5.

## Arguments

- `/go tdd` — run one inner red→green→refactor→commit cycle.
- `/go` — full outer chain, stop before PR creation.
- `/go pr` — full outer chain + create PR.
- `/go --skip-review` — emergency use only, skip step 3. Ask for user confirmation first.
- `/go --dry-run` — walk through what /go would do without modifying anything.

## What /go does NOT do

- No deploys (`kubectl apply`, `terraform apply`, `helm`, project-specific deploy CLIs, etc.).
- No `gh pr merge`, `git push --force`, or tag pushes.
- No silent fixes — every non-trivial change must show up in the report.
- No skipping the TDD cycle. Tests, code, and refactors are not batched at the end.
