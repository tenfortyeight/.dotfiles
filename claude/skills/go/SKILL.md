---
name: go
description: >
  Use when the user types /go (outer pre-PR chain: verify → simplify →
  independent check → commit → optional PR → optional notify) or /go tdd (inner
  red-green-refactor-commit cycles for bug/behavior work, then the outer chain). Never
  deploys, merges, or force-pushes.
user-invocable: true
---

# /go — TDD Inner Loop + Pre-PR Outer Chain

`/go` has two modes. Pick the one that matches where the user is in the work:

- **Inner loop** (`/go tdd` or starting bug/behavior work) — drives one red→green→refactor→commit cycle.
- **Outer chain** (`/go`, default) — finishing chain that runs verify → simplify → independent check → commit → optional PR → optional notify.

**Never deploys. Never merges PRs. Never force-pushes.** Those need the user's explicit go-ahead (CLAUDE.md, Environment safety).

Everywhere else, a gate means *fix it and re-run the step*, not *stop and wait*. Stop for the user only when the fix needs their decision — scope, business logic, or blast radius (CLAUDE.md, Working hands-off).

---

## Mode 1 — Inner TDD loop (`/go tdd`)

Use this when starting or in the middle of bug/behavior work. Drives one cycle per slice, then moves on to the next slice.

Rationale: tight cycles keep each commit reviewable and give design feedback early.

### Cycle steps

1. **Red.** Identify the smallest next slice of behavior (or bug to reproduce). Write **one** failing test for it. Run it. Confirm it fails *for the right reason* — not from a syntax error or wrong import. If the failure mode is wrong, fix the test before continuing.

2. **Green.** Write the **minimum** code to make the test pass. Ugly is allowed. Don't generalize. Don't add features the test doesn't demand. Run the test; confirm it passes. Run the rest of the test suite; confirm nothing else regressed.

3. **Refactor.** Tests stay green throughout. Invoke `/simplify` on the touched files. Look for: duplication, unclear names, leaky boundaries, dead code, accidental complexity. Re-run tests after each refactor step. If refactoring reveals a design problem ("this is hard to test"), fix the design — that is the feedback the test is giving.

4. **Commit.** Small, focused, oneliner message. Typically two commits per cycle (test, then implementation), or one commit if they're tightly coupled. Use `git commit -m "..."` — no heredocs (the hook blocks them).

### Gates

- If step 1's test passes immediately → wrong test. Rewrite it; ask the user only if the intended behaviour itself is unclear.
- If step 2 needs more than ~20 lines or branches into multiple concerns → slice was too big. Revert and slice smaller.
- If step 3's fix would change a public contract, a schema, or the scope of the task → stop and report; that is a decision for the user.

### When done with all slices

Run the outer chain.

---

## Mode 2 — Outer pre-PR chain (`/go`)

Run the steps in order. Each step gates the next: if a step surfaces a blocker, fix it and re-run that step. Do not paper over issues silently — every fix shows up in the report.

### 0. TDD sanity check (heuristic, fast)
Before running the chain, glance at the unpushed commits on the current ref (`git log @{u}..HEAD` if upstream is set, else `git log -n 20`). If the diff fixes a bug or changes behavior but **no test files were added or modified across any of those commits**, write the missing test now. Docs, config and infra-only changes legitimately have none — note that in the report and move on.

### 1. Verify (`/verify`)
Invoke the `verify` skill. This runs file-type validators and environment/profile checks.

**Gate:** Fix any `✗ blocker` and re-run. Stop only if the fix needs the user (wrong environment or profile, missing access). Warnings go in the report.

### 2. Simplify (`/simplify`)
Invoke the built-in `simplify` skill to review the changed code for reuse opportunities, quality issues, and inefficiencies, and to fix anything it finds.

Then ask the scout's-honour question explicitly, because adding is easier to notice than removing: **what did this change make dead, and what can now be removed?** — superseded functions, flags no longer read, imports left orphaned, tests that pin behaviour that no longer exists. Remove it in this chain, not a later cleanup. If the diff is almost all additions, that is the prompt to look, not a verdict — greenfield legitimately adds. If the cleanup is genuinely bigger than this change, say so rather than leaving two truths behind.

**Gate:** Let `simplify` apply its changes. After it finishes, re-run `/verify` quickly on the modified files to make sure nothing it changed introduced a validator failure. If it did, stop and report.

### 3. Independent check

This is the rule for review; CLAUDE.md "Done" points here. Review asks "is this good code?". This asks "is this claim actually true?" — the failure mode that has cost the most rework.

**Always:** spawn **one fresh general-purpose agent** that did not write the change. Give it ONLY the user's original ask and the raw diff. **Never** pass it your summary, your reasoning, or your conclusion — a checker that reads your reasoning re-derives your mistakes. Instruct it to:

- Confirm **every** part of the ask is met, not most of it.
- Prove it **empirically** — run the tests, the build, the real thing; query the live source for any metric, field, endpoint, model or price — not by reading code.
- Return PASS/FAIL with pasted evidence.

**Only when the change is wide or distributed, or touches auth, payments, data deletion, a migration or a cross-service contract** (or the user asks), go further:

- Make the check adversarial: tell the agent to assume the change is subtly wrong, to confirm datasource/query-language compatibility (a Prometheus query against a Loki datasource has shipped before), and to grep for leftover legacy paths and dead flags.
- Run the review squad alongside it — architecture, security, QA, devil's advocate — **in parallel** via the Agent tool with `subagent_type: general-purpose` (Plan agents go idle without responding). Fix blockers and re-review; fix in-scope warnings and list the rest with a reason; report suggestions without blocking.

**Gate:** On FAIL, fix and re-check — do not argue with it from memory. Do not tell the user the work is done until it returns PASS. Then record the receipt, which also satisfies the `verifier-gate` Stop hook:
`mkdir -p "$(git rev-parse --git-dir)/claude-gates" && echo "<one-line evidence>" > "$(git rev-parse --git-dir)/claude-gates/verify-$(git rev-parse HEAD)"`

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

If `.claude/notify` exists in the repo root, read it and follow it. Shape: blank lines
and `#` comments are ignored; the first two remaining lines are a channel (e.g. `slack`)
and a target id. Send a 3–5 line summary:
- What was changed (one line)
- Verify / check outcomes
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
