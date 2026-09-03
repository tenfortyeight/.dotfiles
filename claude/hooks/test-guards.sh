#!/usr/bin/env bash
#
# Regression suite for the deploy guards. Exits non-zero if any case fails, so
# it is usable as a CI gate — an earlier version always exited 0 and therefore
# could not catch anything.
#
# Cases live here rather than in a Bash tool call because the strings would trip
# the very guards under test.
set -uo pipefail

HOOKS="${HOOKS_DIR:-$HOME/.claude/hooks}"
PERM="$HOOKS/deploy-permission-guard.sh"
REF="$HOOKS/deploy-ref-guard.sh"
pass=0; fail=0

payload() { printf '%s' "$1" | jq -Rc '{tool_input:{command:.}}'; }

check() { # <expected-exit> <guard> <command> [label]
  local want="$1" guard="$2" cmd="$3" label="${4:-$3}" got
  payload "$cmd" | bash "$guard" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then pass=$((pass+1)); printf '  ok   (%s) %s\n' "$got" "$label"
  else fail=$((fail+1)); printf '  FAIL want %s got %s: %s\n' "$want" "$got" "$label"; fi
}

echo "== permission guard: reading a deploy script is not deploying =="
check 0 "$PERM" "sed -n '70,103p' scripts/deploy.sh"
check 0 "$PERM" "grep -n rev-parse scripts/deploy.sh"
check 0 "$PERM" "cat scripts/deploy.sh | head -20"
check 0 "$PERM" "git log --oneline scripts/deploy.sh"

echo "== permission guard: executing one is =="
check 2 "$PERM" './scripts/deploy.sh --only api'
check 2 "$PERM" 'bash scripts/deploy.sh'
check 2 "$PERM" 'cd /tmp; ./deploy.sh'
check 2 "$PERM" 'kubectl apply -f x.yaml'
check 2 "$PERM" 'terraform apply'
check 2 "$PERM" 'helm upgrade api ./chart'
check 2 "$PERM" 'gh pr merge 12'
# Regression: an unbalanced trailing ")" once made this rule dead, matching only
# the impossible literal "aws eks update)".
check 2 "$PERM" 'aws eks update-kubeconfig --name prod-cluster'
check 2 "$PERM" 'aws eks update-nodegroup-version --cluster-name prod'
check 0 "$PERM" './scripts/deploy.sh --only api # APPROVED'

echo "== ref guard: only deploy what is on origin =="
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q --bare origin.git
  git clone -q origin.git work 2>/dev/null
  cd work || exit 1
  git config user.email t@t; git config user.name t
  echo one > a.txt; git add .; git commit -qm one
  git branch -M main; git push -q origin main
  git remote set-head origin main >/dev/null 2>&1

  cd "$TMP/work" || exit 1
  check 0 "$REF" './scripts/deploy.sh' 'synced + clean -> allowed'
  echo dirt >> a.txt
  check 2 "$REF" './scripts/deploy.sh' 'dirty tree -> blocked'
  git checkout -q -- a.txt
  echo two > b.txt; git add .; git commit -qm two
  check 2 "$REF" './scripts/deploy.sh' 'unpushed commit -> blocked'
  check 0 "$REF" './scripts/deploy.sh # REF-OVERRIDE' 'explicit override -> allowed'

  echo "== repo-declared patterns =="
  mkdir -p .claude
  printf 'coolify-create-app\\.sh\n' > .claude/deploy-commands
  check 2 "$PERM" './scripts/coolify-create-app.sh' 'repo pattern -> blocked inside repo'
  # A malformed repo pattern must fail CLOSED, not wave the deploy through.
  printf 'coolify-create-app(\n' > .claude/deploy-commands
  check 2 "$PERM" './scripts/coolify-create-app.sh' 'malformed repo pattern -> fails closed'
  rm -rf .claude
  printf '  (subshell: %s passed, %s failed)\n' "$pass" "$fail"
  exit "$fail"
)
inner=$?
rm -rf "$TMP"
fail=$((fail + inner))

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
