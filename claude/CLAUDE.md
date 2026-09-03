# CRITICAL: Read This First

**These instructions are mandatory.** Do not skip or deprioritize them. They override default behavior.

Before writing ANY code:
1. Read and understand the existing codebase patterns
2. Follow the development principles below exactly
3. Validate your changes (lint, test, syntax check) before presenting them
4. For bash scripts: use shellcheck patterns, quote variables, handle errors
5. For YAML: validate syntax before committing
6. For Terraform: remember mac vs x86 differences - run `terraform init` across platforms before push
7. For GitHub workflows: trace the full flow end-to-end, don't let steps fall through the cracks

**Diagnose before you fix — MANDATORY for non-trivial tasks:**
- For non-trivial bugs, features, or refactors: **outline 2-3 possible approaches with tradeoffs FIRST**. Wait for approval before implementing.
- Check actual system state (kubectl, AWS CLI, logs) before proposing changes — don't guess from code alone
- Never jump straight to implementation on debugging tasks
- If you catch yourself writing code before agreeing on an approach: stop, back up, and present options
- Simple/obvious tasks (typo fixes, config tweaks, docs) can skip this — use judgment

**Environment safety — CRITICAL:**
- User works across multiple terminal sessions and environments simultaneously
- **Always verify context before any mutating command**: check `kubectl config current-context` and `AWS_PROFILE`
- **Always use explicit profile/context flags** (`AWS_PROFILE=...`, `--context=...`) — never rely on defaults
- **Never apply infrastructure changes to production locally** — always use CI/CD pipelines
- **State the target environment explicitly** before running mutating commands so the user can confirm

**Verify, don't recall — MANDATORY:**
Never state a model name, price, metric name, API flag, datasource field, or config value from memory. Query the live source and quote the output (`/v1/models`, the Prometheus/Loki label API, `--help`, the live pricing page, the running container). If you cannot verify it, write "unverified" next to the claim rather than guessing. A confident wrong fact costs more than a slow right one.

**Definition of Done:**
Work is not done, ready, or closeable until: legacy code paths, columns, flags, dead integrations and orphaned tests are removed; the full test suite passes; the behaviour is verified against the live system with **pasted evidence** (query output, container SHA, a real log line); and the tracking issue and worktree are closed. Never report completion with "remaining cleanup" outstanding — finish it, or say explicitly what is unfinished and why.


## Philosophy

- **Catch issues early:** Validate before commit, not after pipeline failure
- **Roll forward, not back:** Fix issues by moving forward with fixes, not rollbacks
- **Developer empathy:** Build things people actually want to use


## Development Principles

### Test-Driven Development approach:
- **Red** — write one failing test at a time. Confirm it fails *for the right reason*.
- **Green** — write the minimum code to pass. Ugly is fine; correctness only.
- **Refactor** — **mandatory, not optional.** Once green, you finally know the shape of the solution; that's the moment to make it simpler. Run `/simplify`, kill duplication, tighten names, remove accidental complexity. Tests stay green throughout. Skipping this step is how working-but-messy code accumulates.
- **Commit** after each green (or after the refactor when substantial). Small, focused, oneliner messages — reviewable progress beats big batches.
- Test boundaries and edge cases: -1, 0, 1, null, empty, max values.
- If it's hard to test, redesign it. TDD gives design feedback, not just regression coverage.

### Code principles (guidelines, not rigid rules - use judgment):
- Functions: 15-20 lines max - extract if longer
- Modules: 150-200 lines max - split if larger
- Prefer pure functions that always return values
- Shallow nesting: max 2-3 levels, use early returns
- Shallow module hierarchy: avoid deep dependency chains
- Names should reveal intent; code should read like prose
- Match existing codebase patterns and style
- **Search for existing primitives before introducing new ones.** Before adding a new class, helper, util, module, or pattern, grep the codebase for an existing one that fits. If a primitive exists, use it. If you believe the existing one doesn't fit, say so explicitly and ask before creating a parallel pattern. Reinventing the wheel fragments the codebase faster than any other failure mode.
- Start simple, evolve through refactoring
- Think of single responsibility principle, separation of concerns and open/closed principle
- Prefer a domain structure over layered structure, but stick to current implementation if there is one
- Prefer less code over more abstractions
- Clean as you go: improve names, tighten structure
- Use "scouts honour" so that things we touch are left in equal or better state than previously
- **Never leave dead code behind — ever.** When a function, type, branch, flag, import, fixture, or test case becomes unreachable, remove it in the same commit (or a follow-up cleanup slice). No "might be useful later", no "keep for backward compat" inside a single repo. The git history is the archive. Dead code rots faster than anything else and fragments the codebase.

For non-obvious choices: add brief inline comments explaining "why", otherwise refrain from using comments in code.

If requirements are unclear, ask questions before implementing.

### Error handling:
- Fail fast with clear error messages
- Handle errors at the appropriate level, don't swallow them
- Prefer explicit error types over generic throws where the language supports it

### Security basics:
- Never log secrets, tokens, or credentials
- Validate and sanitize external input
- Use parameterized queries, never string concatenation for SQL

### SOPS Encrypted Files:
- Never edit `.enc.yaml` (or other `.enc.*`) files directly — decrypt, edit, re-encrypt via `sops`
- Never resolve merge conflicts in SOPS files with text edits — decrypt both versions, merge, re-encrypt


## Observability Safety

Before modifying Prometheus relabel rules, dropping metrics, or changing Grafana dashboard queries:
1. **Check dependencies first**: grep all Grafana dashboard JSONs and alert rules for references to the metrics being changed
2. **List what would break**: identify every dashboard panel and alert that depends on those metrics
3. **Never drop metrics that are actively queried in production** — this has caused production incidents (dashboards showing "DEAD"/"no data")
4. When building dashboards, validate metric names exist by checking the actual Prometheus endpoint before committing panel queries

## Quality Gates (Validate Before Commit)

### Bash Scripts
- Use `shellcheck` patterns even without running it
- Always quote variables: `"$var"` not `$var`
- Use `set -euo pipefail` at script start
- Check command existence before use: `command -v foo >/dev/null`
- Handle errors explicitly, don't let them silently fail

### Everything else
Run `/verify` — it routes YAML, Terraform, shell, JS/TS and GitHub-workflow validation per changed file, and checks AWS_PROFILE / kube-context alignment.


## Git Workflow

Commit early and often in appropriate chunks so history is reviewable. Use oneliner commit messages.

**Never** push git tags, trigger releases/publishes, or run irreversible git operations (force push, reset --hard) without explicit user permission.

**Branching — preference & rules:**
- **Default: trunk-based, work directly on `main`** when the repo's `main` is unprotected. Small commits, push as you go. Don't open a branch/PR just out of habit.
- **Exception: use a worktree** (or branch) when running parallel sessions on the same repo, so concurrent work doesn't collide.
- **NEVER push directly to main on repos with branch protection** — always create a branch and PR, even if bypass is technically possible. Respect the review process; the ability to bypass does not grant permission to bypass.
- If unsure whether `main` is protected on a given repo, check before pushing (`gh api repos/{owner}/{repo}/branches/main/protection`).

Before committing:
- Run tests if available
- Validate changed file types (lint, syntax check)

Before pushing:
- For Terraform changes: ensure `terraform init` works on x86 (CI environment)


## Skills

Skill descriptions are already in the session listing — these are the non-obvious *when to reach for them* rules:

- **`/scope`** — use *instead of* an inline plan on any non-trivial task, and treat its checklist as the cutoff.
- **`/simplify`** — inside the refactor step of TDD, and again before PR. Not a one-shot end-of-work polish.
- **`/checkpoint`** — suggest proactively before output-token-limit territory, not only when asked.

## Workflow Guidance

- For non-trivial tasks, run `/scope` first to lock in the full checklist before implementing — and treat that checklist as the cutoff (don't stop at a partial plan waiting to be re-prompted).
- Use subagents for high-volume operations (analyzing test output, logs, deep code searches).
- When investigating, prefer parallel exploration over sequential.
- For long or risky sessions, suggest `/checkpoint` proactively so work survives a session death.

### Agent Teams for Complex Tasks

For changes spanning multiple repos or complex distributed flows, run `/review-squad` — it spawns the architecture, security, QA and devil's-advocate reviewers in parallel. Run it *during* implementation, not just at the end.

### When stuck or uncertain:
- Say what's unclear and what options you see
- Don't guess at business logic - ask
- If you hit a wall, describe what you tried


## Review and Verification

- After significant changes, review your own work before presenting it
- For complex refactors, explain the reasoning behind structural choices
- For multi-file changes: verify the full flow still works end-to-end
