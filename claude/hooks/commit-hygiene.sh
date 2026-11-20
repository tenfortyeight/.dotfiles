#!/usr/bin/env bash
# PreToolUse(Bash): commit messages stay one line. No heredocs, no -F -, no $(cat ...).
#
# Only the command segment that runs `git commit` is inspected, so an unrelated
# heredoc elsewhere in the same command (a python script, a `cat <<EOF`) passes.
# Segments are split naively on ; && || | and newlines — no shell parser.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# `git commit`, also as `git -C dir commit` / `git -c k=v commit`.
commit_re='(^|[[:space:]])git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
bad_re='<<|(-F|--file)[[:space:]=]*-([[:space:]]|$)|\$\(cat '

segment="$(printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||[;|]/, "\n") } 1' | grep -E "$commit_re" || true)"
[ -z "$segment" ] && exit 0

if printf '%s' "$segment" | grep -qE "$bad_re"; then
  echo "BLOCK (commit-hygiene): use a simple 'git commit -m \"oneliner\"'. No heredocs, -F -, or \$(cat ...) in commit messages." >&2
  exit 2
fi
exit 0
