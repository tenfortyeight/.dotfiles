#!/usr/bin/env bash
# Guard test cases. Kept in a file because the strings would otherwise trip the
# very guard under test when passed as a Bash tool command.
GUARD="$HOME/.claude/hooks/deploy-permission-guard.sh"

check() {
  local want="$1" cmd="$2" got
  printf '%s' "$cmd" | jq -Rc '{tool_input:{command:.}}' | bash "$GUARD" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then printf '  ok   (exit %s) %s\n' "$got" "$cmd"
  else printf '  FAIL want %s got %s: %s\n' "$want" "$got" "$cmd"; fi
}

echo "--- should PASS: merely reading the script ---"
check 0 "sed -n '70,103p' scripts/deploy.sh"
check 0 "grep -n rev-parse scripts/deploy.sh"
check 0 "cat scripts/deploy.sh | head -20"
check 0 "git log --oneline scripts/deploy.sh"

echo "--- should BLOCK: actually executing a deploy ---"
DOT_SLASH='./scripts/deploy.sh --only api'
check 2 "$DOT_SLASH"
check 2 'bash scripts/deploy.sh'
check 2 'cd /tmp; ./deploy.sh'
check 2 'kubectl apply -f x.yaml'
check 2 'terraform apply'
