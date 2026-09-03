#!/usr/bin/env bash
# PreToolUse(Bash) guard: refuse deploy-shaped commands unless the working tree
# is clean and HEAD is exactly origin/<default-branch>.
#
# Why: approval was never the missing piece — the *ref* was. The existing
# permission hook asks "may I deploy?"; this one asks "are you deploying what
# is actually on main?". They need separate override markers, otherwise saying
# yes to the first silently says yes to the second.
#
# Exit 2 + stderr = blocked, message fed back to Claude.
set -uo pipefail

raw="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$raw" ] && [ ! -t 0 ]; then raw="$(cat 2>/dev/null || true)"; fi
[ -z "$raw" ] && exit 0

cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$raw" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
fi
[ -z "$cmd" ] && cmd="$raw"

# Universal, employer-neutral deploy verbs. A repo adds its own entrypoints via
# .claude/deploy-commands rather than by editing this file.
DEPLOY_RE='(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?((bash|sh|zsh)[[:space:]]+)?(\./)?([A-Za-z0-9_./-]*/)?deploy\.sh|kubectl[[:space:]]+(apply|rollout|patch|scale)|terraform[[:space:]]+apply|helm[[:space:]]+(upgrade|install)|gh[[:space:]]+pr[[:space:]]+merge|aws[[:space:]]+eks[[:space:]]+update)'

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ] && [ -f "$repo_root/.claude/deploy-commands" ]; then
  extra="$(grep -vE '^[[:space:]]*(#|$)' "$repo_root/.claude/deploy-commands" 2>/dev/null | paste -sd'|' - || true)"
  [ -n "$extra" ] && DEPLOY_RE="$DEPLOY_RE|$extra"
fi

printf '%s' "$cmd" | grep -qE "$DEPLOY_RE" || exit 0

# Deliberately NOT the same marker as the permission hook's "# APPROVED".
printf '%s' "$cmd" | grep -qE '(# REF-OVERRIDE|DEPLOY_REF_OVERRIDE=1)' && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
branch="${branch#origin/}"
[ -z "$branch" ] && branch="main"

TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
fetch_ok=0
if [ -n "$TIMEOUT_BIN" ]; then
  "$TIMEOUT_BIN" 20 git fetch --quiet origin "$branch" 2>/dev/null || fetch_ok=1
else
  git fetch --quiet origin "$branch" 2>/dev/null || fetch_ok=1
fi
if [ "$fetch_ok" -ne 0 ]; then
  echo "BLOCK (deploy-ref-guard): could not fetch origin/$branch, so ref parity is UNVERIFIED. Do not deploy blind. Fix connectivity, or re-run with a trailing '# REF-OVERRIDE' only if the user explicitly accepts an unverified ref." >&2
  exit 2
fi

dirty="$(git status --porcelain 2>/dev/null)"
if [ -n "$dirty" ]; then
  echo "BLOCK (deploy-ref-guard): working tree is DIRTY — deploy.sh would build images from these uncommitted edits and tag them '-dirty'. Commit and push first." >&2
  printf '%s\n' "$dirty" | head -20 >&2
  exit 2
fi

local_sha="$(git rev-parse HEAD 2>/dev/null || true)"
remote_sha="$(git rev-parse "origin/$branch" 2>/dev/null || true)"
if [ -z "$remote_sha" ]; then
  echo "BLOCK (deploy-ref-guard): origin/$branch does not resolve. Cannot verify what production should be running." >&2
  exit 2
fi

if [ "$local_sha" != "$remote_sha" ]; then
  counts="$(git rev-list --left-right --count "origin/$branch...HEAD" 2>/dev/null || echo "? ?")"
  behind="$(printf '%s' "$counts" | awk '{print $1}')"
  ahead="$(printf '%s' "$counts" | awk '{print $2}')"
  {
    echo "BLOCK (deploy-ref-guard): HEAD != origin/$branch. This is the prod/main drift that has bitten this setup repeatedly."
    echo "  HEAD            = $local_sha"
    echo "  origin/$branch  = $remote_sha"
    echo "  ahead of origin: $ahead commit(s)   behind origin: $behind commit(s)"
    echo "Fix: merge to $branch, push, 'git fetch origin', check out origin/$branch, THEN deploy."
    echo "Deploying a branch SHA or unpushed local commit means production runs code no one can review from $branch."
  } >&2
  exit 2
fi

echo "✓ deploy-ref-guard: HEAD == origin/$branch ($local_sha), tree clean"
exit 0
