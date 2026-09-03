#!/usr/bin/env bash
# PreToolUse(Bash): deploy-shaped commands need explicit user permission.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Universal, employer-neutral deploy verbs only. A deploy script counts at COMMAND
# POSITION (line start, or after ; & | &&, optionally via sudo/bash/sh) — otherwise
# `sed -n 1,50p scripts/deploy.sh`, merely READING it, reads as a deploy.
DEPLOY_RE='(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?((bash|sh|zsh)[[:space:]]+)?(\./)?([A-Za-z0-9_./-]*/)?deploy\.sh|kubectl[[:space:]]+(apply|delete|rollout|patch|create|scale|drain|uncordon|edit)|terraform[[:space:]]+(apply|destroy|taint|untaint|import)|helm[[:space:]]+(upgrade|install|uninstall|rollback)|gh[[:space:]]+pr[[:space:]]+merge|git[[:space:]]+push[[:space:]]+(--force|-f|--tags)|git[[:space:]]+tag[[:space:]]+-[^d]|aws[[:space:]]+eks[[:space:]]+update)'

# Repo-declared entrypoints: one ERE per line in .claude/deploy-commands ("#" comments
# and blank lines ignored). Keeps this hook generic — the repo owns its own specifics.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ] && [ -f "$repo_root/.claude/deploy-commands" ]; then
  extra="$(grep -vE '^[[:space:]]*(#|$)' "$repo_root/.claude/deploy-commands" 2>/dev/null | paste -sd'|' - || true)"
  [ -n "$extra" ] && DEPLOY_RE="$DEPLOY_RE|$extra"
fi

printf '%s' "$cmd" | grep -qE "$DEPLOY_RE" || exit 0
printf '%s' "$cmd" | grep -qE '(# APPROVED|APPROVED_DEPLOY=1)' && exit 0

echo "BLOCK (deploy-permission): deploy-shaped command detected. The user requires explicit permission before any deploy, kubectl mutation, terraform apply, helm release, PR merge, force/tag push, or EKS update. State what you want to run, the TARGET ENVIRONMENT, and why — then wait for explicit go-ahead. If approved, re-run with a trailing '# APPROVED' comment." >&2
exit 2
