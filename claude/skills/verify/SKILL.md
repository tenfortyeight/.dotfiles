---
name: verify
description: >
  Use when the user asks to verify, validate, or sanity-check their current
  changes before committing, or types /verify. Runs the right validator for
  every file type in the current diff and checks environment/profile alignment
  for AWS/K8s work.
user-invocable: true
---

# /verify — Local Pre-Commit Validation Router

Run the appropriate validator for every file type touched in the current branch. Verify environment/profile alignment for AWS/K8s work. Fail fast on violations so the user sees problems before committing.

## How to Run

1. **Determine the diff scope.**
   ```bash
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
   changed=$(git diff --name-only "$(git merge-base HEAD origin/$default_branch)"...HEAD ; git diff --name-only HEAD ; git diff --name-only --cached)
   changed=$(printf '%s\n' $changed | sort -u | grep -v '^$' || true)
   ```
   If `$changed` is empty, report "No changes to verify" and stop.

2. **Dispatch per file type.** Run each block only if at least one matching file is in `$changed`. Capture output and keep going — don't stop at first failure; collect everything for the final report.

   ### Terraform (`*.tf`, `*.tfvars`)
   ```bash
   terraform fmt -check -recursive
   terraform validate
   ```
   If files live under `tf-modules/` or a `terraform/` dir, also remind:
   > "⚠ Run `terraform init -upgrade` on x86 before pushing — CI fails otherwise."

   ### YAML (`*.yml`, `*.yaml`, excluding `*.enc.*`)
   ```bash
   command -v yamllint >/dev/null && yamllint -d relaxed <files>
   ```
   If any file is under a `kustomize/` dir, or there's a sibling `kustomization.yaml`, also:
   ```bash
   kustomize build <overlay-dir>
   ```
   If the project ships its own validator CLI (e.g. a `*-validate` command in `package.json` or a project `*.yaml` config), prefer that.

   ### Shell (`*.sh`, `*.bash`)
   ```bash
   command -v shellcheck >/dev/null && shellcheck <files>
   bash -n <files>
   ```

   ### JS/TS (`*.ts`, `*.tsx`, `*.js`, `*.jsx`)
   Detect project commands from `package.json` scripts and run what exists, in order: `lint`, `typecheck` (or `tsc --noEmit`), `test`. Skip any that aren't defined.

   ### GitHub workflows (`.github/workflows/*.yml`)
   Remind the user to trace inputs/outputs end-to-end; flag any `needs:` or `uses:` reference that doesn't resolve. If `actionlint` is installed, run it.

3. **Environment & profile checks** (if any changed file touches AWS, K8s, or infra):
   - Trigger files: anything under `terraform/`, `kustomize/`, `*.tf`, `kubernetes/*.yaml`, anything referencing `AWS_PROFILE` or `kubectl`.
   - Check `AWS_PROFILE`:
     - Must be set explicitly. If empty → **fail** with "Set AWS_PROFILE explicitly to a profile that matches the target environment."
     - Must match the target env implied by the change (e.g. staging overlay → staging-flavored profile; prod overlay → prod-flavored profile). On mismatch → **fail** and name both the current profile and the detected target env so the user can correct.
   - Check kube context: `kubectl config current-context` should match the target cluster; report mismatch as a warning.

4. **SOPS-encrypted file sanity**:
   - For any `*.enc.*` file in the diff, run `file <path>` or inspect the first line. If it looks like plaintext (not the SOPS envelope), **fail** with: "Encrypted file was edited directly — decrypt, edit, re-encrypt via `sops`."
   - If it's still valid SOPS format, say nothing.

5. **Report format.**
   Group findings by severity and filetype:
   ```
   ✗ terraform (2 issues)
     - path/to/file.tf: <message>
   ⚠ yaml warnings (1)
     - path/to/file.yaml: <message>
   ✓ shell (3 files checked)
   ✓ AWS_PROFILE: <profile-name> (matches target overlay)
   ```

   Severity:
   - `✗` **blocker** — syntax errors, validation failures, env mismatch, sops violations. User should fix before commit.
   - `⚠` **warning** — yamllint style, missing lint scripts, platform reminders. Worth noting.
   - `✓` **pass** — quick confirmation lines.

   End with a one-liner: `VERIFY: 3 blocker(s), 1 warning(s)` or `VERIFY: all clean`.

## What /verify does NOT do

- Does not run tests unless they're part of the project's default script chain (`npm test`, etc.). For TDD-first bug work, the user writes the failing test manually.
- Does not commit, push, or deploy.
- Does not auto-fix (other than `terraform fmt`, which is safe). Report and let the user decide.
- Does not pass judgment on architecture or design — that's `/review-squad`.
