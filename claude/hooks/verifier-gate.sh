#!/usr/bin/env bash
# Stop hook: on a large change, run the repo's own checks before ending the turn.
#
# Deliberately cheap. An earlier version fired at 2 files / 60 lines and demanded
# an adversarial subagent plus a four-agent review squad every time — which turned
# three small tasks into twenty commits of process. The single most consequential
# defect it ever caught (a typecheck break that made main undeployable) was found
# by running tsc, not by an agent. So: run the checks, paste the output, move on.
#
# Loop safety: stop_hook_active is set on a hook-driven continuation, so this
# blocks at most once per stop-chain; the per-SHA receipt stops it re-firing.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
[ -z "$git_dir" ] && exit 0
sha="$(git rev-parse HEAD 2>/dev/null || echo none)"
receipt="$git_dir/claude-gates/verify-$sha"
[ -f "$receipt" ] && exit 0

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
changed=""
[ -n "$upstream" ] && changed="$(git diff --name-only "$upstream"...HEAD 2>/dev/null || true)"
worktree="$(git status --porcelain 2>/dev/null | awk '{print $NF}' || true)"
all_changed="$(printf '%s\n%s\n' "$changed" "$worktree" | grep -vE '^\s*$' | sort -u || true)"
[ -z "$all_changed" ] && exit 0

src="$(printf '%s\n' "$all_changed" | grep -iE '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|sh|bash|tf|sql)$' || true)"
[ -z "$src" ] && exit 0
n_files="$(printf '%s\n' "$src" | grep -c . || echo 0)"

lines=0
[ -n "$upstream" ] && lines="$(git diff --shortstat "$upstream"...HEAD 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)"
lines="${lines:-0}"

# Substantial changes only. Small ones surface their own problems fast.
[ "$n_files" -lt 6 ] && [ "$lines" -lt 250 ] && exit 0

{
  echo "PAUSE (verifier-gate): $n_files source files / $lines added lines, unverified."
  echo ""
  echo "Run the repo's own checks and paste the real output — typecheck, lint, test suite,"
  echo "build, whatever this repo has. That is all this gate asks. Do not spawn a review squad."
  echo ""
  echo "Go further only as /go step 3 says: an adversarial check and the review squad"
  echo "are for wide changes and auth, payments, deletion, migrations or cross-service contracts."
  echo ""
  echo "Then record it and stop:"
  echo "  mkdir -p \"$(dirname "$receipt")\" && echo \"<what you ran, what passed>\" > \"$receipt\""
  echo ""
  echo "If the checks pass, say so; if they fail, fix and re-run."
  echo "If this is trivial or verification was waived, write the receipt saying that."
} >&2
exit 2
