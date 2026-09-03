#!/usr/bin/env bash
# PreToolUse(Bash): warn before pushing Terraform changes.
#
# CI runs linux/amd64 while this machine is arm64 macOS, so a provider set that
# resolves locally can still fail `terraform init` in the pipeline. Advisory
# only — never blocks a push.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | grep -qE '(^|[;&|])[[:space:]]*git[[:space:]]+push' || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
branch="${branch#origin/}"
[ -n "$branch" ] || branch=main

changed="$(git diff --name-only "origin/$branch"...HEAD 2>/dev/null | grep -E '\.tf$' || true)"
[ -z "$changed" ] && exit 0

echo "⚠️  REMINDER: Terraform files changed in this push. CI runs linux/amd64 — confirm 'terraform init' resolves there, not just on arm64 macOS."
printf '%s\n' "$changed" | head -10
exit 0
