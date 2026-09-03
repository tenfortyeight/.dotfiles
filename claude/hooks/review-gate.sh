#!/usr/bin/env bash
# PreToolUse(Bash): no PR opens without a review-squad pass for this SHA.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create' || exit 0
printf '%s' "$cmd" | grep -qE '# REVIEWED' && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
sha="$(git rev-parse HEAD 2>/dev/null || echo none)"
receipt="$git_dir/claude-gates/review-$sha"
[ -f "$receipt" ] && exit 0

{
  echo "BLOCK (review-gate): opening a PR without a review-squad pass for $sha."
  echo "Run the review-squad — architecture, security, QA and devil's-advocate agents IN PARALLEL"
  echo "via the Agent tool (subagent_type: general-purpose; Plan agents go idle)."
  echo "Resolve every blocker, then record it:"
  echo "  mkdir -p \"$git_dir/claude-gates\" && echo \"<blockers resolved>\" > \"$receipt\""
  echo "Only if the user explicitly waived review, re-run with a trailing '# REVIEWED'."
} >&2
exit 2
