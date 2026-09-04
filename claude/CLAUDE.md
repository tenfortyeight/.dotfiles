# How I want you to work

Get things done. Quality comes from simple, obvious code — not from process. If something is
easy to do, that is usually a sign it is shaped correctly. If it is hard, ask what is wrong
with the design before reaching for more scaffolding. Never make it hard to do the right thing.

Code should be easy for a human to read and follow. That includes this file, the hooks and the
dotfiles: config is code, and the same standard applies.

Roll forward, not back — fix by moving forward, not by reverting.

## Before you change code

- Read the surrounding code and match its patterns.
- Check live state before proposing a fix — kubectl, AWS CLI, logs, the actual database. Don't guess from code alone.
- **When the cause is unclear, or the change is risky or wide-reaching: outline 2–3 approaches with tradeoffs and wait.** When the fix is obvious, just make it. Use judgment — don't turn every task into a planning exercise.
- If requirements are genuinely ambiguous, ask. Don't guess at business logic.
- For GitHub workflows, trace the full flow end-to-end so steps don't fall through the cracks.

## Verify, don't recall

Never state a model name, price, metric name, API flag, datasource field or config value from
memory. Query the live source and quote the output (`/v1/models`, the Prometheus/Loki label
API, `--help`, the live pricing page, the running container). If you cannot verify it, write
"unverified" next to the claim. A confident wrong fact costs more than a slow right one.

## Environment safety

I work across several terminals and environments at once.

- Verify context before any mutating command: `kubectl config current-context`, `AWS_PROFILE`.
- Always pass explicit profile/context flags — never rely on defaults.
- Never apply infrastructure changes to production locally. Use CI/CD.
- State the target environment before running a mutating command, so I can stop you.
- Never deploy, merge, release, tag, force-push or `reset --hard` without me saying so.

## What to test

Test business logic and policy decisions: pure functions, calculations, state transitions,
authorization rules, parsers — anything with real edge cases. These are cheap to test, and
that ease is the signal: they're easy because they're shaped right. Cover boundaries: -1, 0,
1, null, empty, max. Test observable outcomes, not "did it call this mock".

**Don't test orchestration or wiring.** Which component composes which, what gets constructed
when an env var is set, which branch runs at startup. If that breaks, the app is visibly
broken on first load — and a source-grep "test" over wiring is a tautology that costs
maintenance and proves nothing. No integration tests. Don't test third parties; trust that
their library works.

Contract checks earn their place only where two things live in separate files, must agree, and
drift silently — a log format an alert parses, an i18n key set, a design token list.

**Build gates beat tests for a whole class of problems.** Run `tsc`, the linter, the build.
That is where broken wiring actually surfaces, and it costs nothing.

If something is hard to test, that's design feedback: redesign it rather than building
scaffolding around it. Never add an abstraction whose only purpose is to satisfy a test.

## TDD, for the things worth testing

- **Red** — one failing test at a time, failing for the right reason.
- **Green** — minimum code to pass. Ugly is fine; correctness only.
- **Refactor** — now that you know the shape, make it simpler. Kill duplication, tighten names. Tests stay green.
- **Commit** — small, focused, oneliner messages.

## Code

Guidelines, not rules — use judgment:

- Functions ~15–20 lines, modules ~150–200. Longer is a prompt to look, not a violation.
- Prefer pure functions. Shallow nesting (2–3 levels), early returns, shallow dependency chains.
- Names reveal intent; code reads like prose.
- **Look for an existing primitive before adding a new one.** Grep first. If the existing one genuinely doesn't fit, say so before creating a parallel pattern — reinventing fragments a codebase faster than anything else.
- Prefer less code over more abstraction. Start simple, evolve by refactoring.
- Single responsibility, separation of concerns. Domain structure over layered — but follow what the repo already does.
- Scout's honour: leave what you touch equal or better.
- Remove dead code as you go — unreachable functions, flags, imports, orphaned tests. Git history is the archive. If the cleanup is bigger than the task at hand, say so rather than silently leaving it.
- Comment the "why" of non-obvious choices; otherwise let the code speak.

### Error handling
- Fail fast with clear messages. Handle errors at the right level; never swallow them.
- Prefer explicit error types where the language supports it.
- No silent degradation of core features in production. Degrade gracefully only in dev.

### Security
- Never log secrets, tokens or credentials.
- Validate and sanitize external input.
- Parameterized queries only — never string-concatenated SQL.

### SOPS
- Never edit `.enc.*` files directly — decrypt, edit, re-encrypt via `sops`, with an explicit AWS profile when KMS is involved.
- Never text-merge a SOPS conflict — decrypt both sides, merge, re-encrypt.

## Observability

Before changing Prometheus relabel rules, dropping metrics, or editing dashboard queries: grep
the Grafana JSONs and alert rules for the metric and list what would break. Dropping a metric
that production dashboards query has caused incidents here. Validate metric names against the
live Prometheus endpoint before committing a panel.

## Git

**Fetch first.** Before editing or committing in any repo: `git fetch origin`, compare HEAD to
`origin/<default>`, reconcile if behind. Several sessions run against these repos at once, so
origin moves while you work. Re-fetch before pushing.

Commit early and often in reviewable chunks. Oneliner messages.

- Default to trunk-based on `main` when it's unprotected. Don't open a PR out of habit.
- Use a worktree when parallel sessions share a repo.
- Never push to a protected `main` — branch and PR. The ability to bypass is not permission to bypass. Check with `gh api repos/{owner}/{repo}/branches/main/protection` if unsure.
- Terraform: confirm `terraform init` works on x86 before pushing.
- Bash: `set -euo pipefail`, quote variables, `command -v` before use, shellcheck patterns.

## Tools

- `/verify` — routes the right validator per changed file type. Use before committing a mixed diff.
- `/simplify` — in the refactor step, and again before a PR.
- `/scope` — for genuinely multi-step work with a fuzzy ask. Not for every task.
- `/review-squad` — available when a change is wide or distributed. Not a gate.
- `/checkpoint` — suggest proactively on long or risky sessions.
- Use subagents for high-volume reading — logs, test output, deep searches. Explore in parallel.

## Done

Done means the behaviour works and you have seen it work: checks run, output pasted, or the
real thing exercised. Close the tracking issue and the worktree. If part is unfinished, say
plainly what and why — never report something as working when you haven't watched it work.
