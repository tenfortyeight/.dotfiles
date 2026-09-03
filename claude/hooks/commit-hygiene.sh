#!/usr/bin/env bash
# PreToolUse(Bash): keep commit messages simple; nudge tests before committing.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+commit' || exit 0

if printf '%s' "$cmd" | grep -qE '(<<[-]?.?EOF|<<[-]?.?MSG|\$\(cat )'; then
  echo "BLOCK (commit-hygiene): use a simple 'git commit -m \"oneliner\"'. No heredocs or \$(cat ...) in commit messages." >&2
  exit 2
fi
if [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then
  echo "⚠️  REMINDER: run the test suite before committing (npm test or equivalent)."
fi
exit 0
