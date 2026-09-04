#!/usr/bin/env bash
# Stop hook: refuse to end a turn on substantive, unverified code work.
#
# Hooks run shell, not agents — so this cannot spawn the verifier itself. It
# blocks the stop (exit 2) and feeds the instruction back to Claude, which then
# runs the adversarial verifier and writes a receipt. That is what makes it
# automatic: nobody has to remember to type /go.
#
# Loop safety: Claude Code sets stop_hook_active=true on a hook-driven
# continuation, so this can block at most once per stop-chain. The per-SHA
# receipt stops it re-firing on later turns for the same commit.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the stop_hook_active flag below can never read "true", so the
  # once-per-stop-chain loop guard would be defeated and this hook could block
  # repeatedly. Stand down loudly rather than block blind.
  echo "WARNING (verifier-gate): jq not found — verification gating is disabled." >&2
  exit 0
fi

payload="$(cat 2>/dev/null || true)"
[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
[ -z "$git_dir" ] && exit 0
sha="$(git rev-parse HEAD 2>/dev/null || echo none)"

receipt_dir="$git_dir/claude-gates"
receipt="$receipt_dir/verify-$sha"
[ -f "$receipt" ] && exit 0

# What changed: unpushed commits plus anything still in the working tree.
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
changed=""
if [ -n "$upstream" ]; then
  changed="$(git diff --name-only "$upstream"...HEAD 2>/dev/null || true)"
fi
worktree="$(git status --porcelain 2>/dev/null | awk '{print $NF}' || true)"
all_changed="$(printf '%s\n%s\n' "$changed" "$worktree" | grep -vE '^\s*$' | sort -u || true)"
[ -z "$all_changed" ] && exit 0

# Source-shaped changes only — docs and config tweaks should not nag.
src="$(printf '%s\n' "$all_changed" | grep -iE '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|sh|bash|tf|sql)$' || true)"
[ -z "$src" ] && exit 0
n_files="$(printf '%s\n' "$src" | grep -c . || echo 0)"

lines=0
if [ -n "$upstream" ]; then
  lines="$(git diff --shortstat "$upstream"...HEAD 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)"
fi
lines="${lines:-0}"
[ "$n_files" -lt 2 ] && [ "$lines" -lt 60 ] && exit 0

mkdir -p "$receipt_dir" 2>/dev/null || true
{
  echo "BLOCK (verifier-gate): $n_files source file(s) changed and this work has not been independently verified."
  echo ""
  echo "Before ending the turn, run an ADVERSARIAL VERIFIER — do not self-assess:"
  echo "  1. Spawn a fresh general-purpose subagent. Give it ONLY the user's original"
  echo "     requirement and the raw diff. Never give it your summary or reasoning."
  echo "  2. Instruct it to assume the implementation is subtly wrong and to prove"
  echo "     correctness EMPIRICALLY — query live systems, hit real APIs, confirm every"
  echo "     metric/field/endpoint/model name actually exists. No claims from memory."
  echo "  3. It must also grep for leftover legacy paths, dead flags, orphaned tests, and"
  echo "     confirm EVERY acceptance criterion is met — not most of them."
  echo "  4. In parallel, run the review-squad (architecture, security, QA, devil's"
  echo "     advocate) unless a review receipt already exists for this SHA."
  echo ""
  echo "On FAIL: fix and re-verify. Do NOT tell the user it is done, ready, or complete"
  echo "until the verifier returns PASS with pasted evidence from live systems."
  echo ""
  echo "When it genuinely passes, record it:"
  echo "  echo \"<one-line evidence>\" > \"$receipt\""
  echo ""
  echo "If this work is trivial or the user explicitly waived verification, write the"
  echo "receipt with the reason and stop."
} >&2
exit 2
