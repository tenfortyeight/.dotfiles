#!/usr/bin/env bash
#
# PreToolUse(Bash): warn when committing onto a base that is behind origin.
#
# Documented rules get violated — that is the whole lesson of this hook set. The
# "fetch before you start" rule in CLAUDE.md was broken on its first outing, and
# 16 commits were built on a stale base before anyone noticed. This catches it at
# commit #1 instead.
#
# Warns, never blocks: being deliberately behind is legitimate (offline, a pinned
# base, a deliberate revert), and a blocking gate on every commit would just earn
# itself a reflexive override. Cheap because it only runs on `git commit` via the
# `if` filter in settings.json.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
branch="${branch#origin/}"
[ -n "$branch" ] || branch=main

# Only fetch once per HEAD per hour — a network round trip on every commit would
# be its own kind of annoying.
git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
stamp="$git_dir/claude-gates/fetched-$branch"
if [ ! -f "$stamp" ] || [ -n "$(find "$stamp" -mmin +60 2>/dev/null)" ]; then
  TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" 10 git fetch --quiet origin "$branch" 2>/dev/null || exit 0
  else
    git fetch --quiet origin "$branch" 2>/dev/null || exit 0
  fi
  mkdir -p "$(dirname "$stamp")" 2>/dev/null || true
  : > "$stamp"
fi

behind="$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)"
[ "${behind:-0}" -gt 0 ] || exit 0

echo "⚠️  REMINDER: HEAD is $behind commit(s) behind origin/$branch. You are committing onto a stale base — another session has pushed since this work started. Reconcile now (git pull --rebase, or merge) rather than after N commits."
exit 0
