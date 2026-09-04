#!/usr/bin/env bash
# PreToolUse(Bash): deploy-shaped commands need explicit user permission.
set -uo pipefail
if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING (deploy-permission): jq not found — the deploy permission gate is NOT being enforced." >&2
  exit 0
fi

payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Universal, employer-neutral deploy verbs only. A deploy script counts at COMMAND
# POSITION — line start or after ; & |, optionally behind sudo, an env-var prefix
# (AWS_PROFILE=prod kubectl ...) or an interpreter. Anchoring EVERY verb, not just
# deploy.sh, is what stops `grep -r "terraform apply" .` and `echo "kubectl apply"`
# from reading as deploys; those false positives blocked ordinary work.
# sudo / env / VAR=value may appear in any order and repeat.
CMDPOS='(^|[;&|])[[:space:]]*((sudo|env)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
# Flags may sit between the binary and its verb — `kubectl --context=prod apply`.
# CLAUDE.md mandates explicit --context/--profile flags, so a guard that required
# the verb to follow the binary directly missed the very form it tells you to use.
# Tokens cannot contain ; & |, so a match can never span a command boundary.
FLAGS='([[:space:]]+[^[:space:];&|]+)*'
VERBS="((bash|sh|zsh)[[:space:]]+)?(\./)?([A-Za-z0-9_./-]*/)?deploy\.sh|kubectl${FLAGS}[[:space:]]+(apply|delete|rollout|patch|create|scale|drain|uncordon|edit)|terraform${FLAGS}[[:space:]]+(apply|destroy|taint|untaint|import)|helm${FLAGS}[[:space:]]+(upgrade|install|uninstall|rollback)|gh${FLAGS}[[:space:]]+pr[[:space:]]+merge|git[[:space:]]+push[[:space:]]+(--force|-f|--tags)|git[[:space:]]+tag[[:space:]]+-[^d]|aws${FLAGS}[[:space:]]+eks[[:space:]]+update"
DEPLOY_RE="${CMDPOS}(${VERBS})"

# Repo-declared entrypoints: one ERE per line in .claude/deploy-commands ("#" comments
# and blank lines ignored). Keeps this hook generic — the repo owns its own specifics.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ] && [ -f "$repo_root/.claude/deploy-commands" ]; then
  extra="$(grep -vE '^[[:space:]]*(#|$)' "$repo_root/.claude/deploy-commands" 2>/dev/null | paste -sd'|' - || true)"
  [ -n "$extra" ] && DEPLOY_RE="$DEPLOY_RE|$extra"
fi

printf '%s' "$cmd" | grep -qE "$DEPLOY_RE"
rc=$?
# grep exits 0=match, 1=no-match, 2=error (e.g. a malformed repo-supplied pattern).
# Treating 2 as "no match" would fail OPEN and wave a real deploy through.
case "$rc" in
  0) ;;
  1) exit 0 ;;
  *) echo "BLOCK (deploy guard): deploy pattern failed to compile (grep exit $rc). Refusing to run a deploy-shaped command behind a broken guard — check .claude/deploy-commands." >&2; exit 2 ;;
esac
printf '%s' "$cmd" | grep -qE '(# APPROVED|APPROVED_DEPLOY=1)' && exit 0

echo "BLOCK (deploy-permission): deploy-shaped command detected. The user requires explicit permission before any deploy, kubectl mutation, terraform apply, helm release, PR merge, force/tag push, or EKS update. State what you want to run, the TARGET ENVIRONMENT, and why — then wait for explicit go-ahead. If approved, re-run with a trailing '# APPROVED' comment." >&2
exit 2
