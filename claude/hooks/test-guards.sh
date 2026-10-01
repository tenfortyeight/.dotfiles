#!/usr/bin/env bash
#
# Regression suite for the deploy guard. Exits non-zero if any case fails, so
# it is usable as a CI gate — an earlier version always exited 0 and therefore
# could not catch anything.
#
# Cases live here rather than in a Bash tool call because the strings would trip
# the very guard under test.
set -uo pipefail

HOOKS="${HOOKS_DIR:-$HOME/.claude/hooks}"
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

# Run in-process rather than a subshell so the counters are a single set — a
# subshell's tallies are lost on exit, which is how an earlier version silently
# reported the wrong totals and could not fail.
TMP="$(mktemp -d)"
ORIG_PWD="$PWD"
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/work" 2>/dev/null
cd "$TMP/work" || { echo "  FAIL: could not set up throwaway repo"; exit 1; }
git config user.email t@t; git config user.name t
echo one > a.txt; git add .; git commit -qm one
git branch -M main; git push -q origin main
git remote set-head origin main >/dev/null 2>&1

echo "== only deploy what is on origin =="
check 0 "$REF" './scripts/deploy.sh' 'synced + clean -> allowed'
echo dirt >> a.txt
check 2 "$REF" './scripts/deploy.sh' 'dirty tree -> blocked'
git checkout -q -- a.txt
echo two > b.txt; git add .; git commit -qm two
check 2 "$REF" './scripts/deploy.sh' 'unpushed commit -> blocked'
check 0 "$REF" './scripts/deploy.sh # REF-OVERRIDE' 'explicit override -> allowed'

# From here HEAD is ahead of origin, so every deploy-shaped command is blocked
# (2) and anything else passes untouched (0): the cases below test the matcher.

echo "== reading a deploy script is not deploying =="
check 0 "$REF" "sed -n '70,103p' scripts/deploy.sh"
check 0 "$REF" "grep -n rev-parse scripts/deploy.sh"
check 0 "$REF" "cat scripts/deploy.sh | head -20"
check 0 "$REF" "git log --oneline scripts/deploy.sh"

echo "== executing one is =="
check 2 "$REF" './scripts/deploy.sh --only api'
check 2 "$REF" 'bash scripts/deploy.sh'
check 2 "$REF" 'cd /tmp; ./deploy.sh'
check 2 "$REF" 'kubectl apply -f x.yaml'
check 2 "$REF" 'terraform apply'
check 2 "$REF" 'helm upgrade api ./chart'
check 2 "$REF" 'gh pr merge 12'
# Regression: an unbalanced trailing ")" once made this rule dead, matching only
# the impossible literal "aws eks update)".
check 2 "$REF" 'aws eks update-kubeconfig --name prod-cluster'
check 2 "$REF" 'aws eks update-nodegroup-version --cluster-name prod'

echo "== MENTIONING a verb is not running it =="
# These blocked ordinary work — grepping for a verb, documenting one, or feeding
# one to a test harness all matched, because only deploy.sh was anchored to a
# command position while the infra verbs matched anywhere in the string.
check 0 "$REF" 'grep -r "terraform app''ly" .'
check 0 "$REF" 'echo "kube''ctl apply -f x.yaml"'
check 0 "$REF" 'git commit -m "docs: note kube''ctl apply ordering"'

echo "== prefixed invocations still count =="
check 2 "$REF" 'AWS_PROFILE=prod kubectl apply -f x.yaml'
check 2 "$REF" 'sudo kubectl apply -f x.yaml'
check 2 "$REF" 'cd /infra && terraform apply'
check 2 "$REF" 'env AWS_PROFILE=prod kubectl apply -f x.yaml'
check 2 "$REF" 'sudo env KUBECONFIG=/tmp/k kubectl apply -f x.yaml'
# Prefix parts may appear in any order, not just sudo -> env -> VAR=.
check 2 "$REF" 'KUBECONFIG=/tmp/k sudo kubectl apply -f x.yaml'

echo "== flags between the binary and the verb =="
# CLAUDE.md mandates explicit --context/--profile flags, so the guard MUST see
# through them; requiring the verb to follow the binary directly missed the exact
# invocation form the instructions require.
check 2 "$REF" 'kubectl --context=prod apply -f x.yaml'
check 2 "$REF" 'kubectl --context prod apply -f x.yaml'
check 2 "$REF" 'kubectl -n payments apply -f x.yaml'
check 2 "$REF" 'helm --kube-context prod upgrade api ./chart'
# ...but not across a command boundary: this is two commands, neither a deploy.
check 0 "$REF" 'kubectl get pods; echo apply'

echo "== repo-declared patterns =="
mkdir -p .claude
printf 'example-create-app\\.sh\n' > .claude/deploy-commands
check 2 "$REF" './scripts/example-create-app.sh' 'repo pattern -> blocked inside repo'
# A malformed repo pattern must fail CLOSED, not wave the deploy through.
printf 'example-create-app(\n' > .claude/deploy-commands
check 2 "$REF" './scripts/example-create-app.sh' 'malformed repo pattern -> fails closed'

cd "$ORIG_PWD" || true
rm -rf "$TMP"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
