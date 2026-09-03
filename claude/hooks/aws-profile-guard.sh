#!/usr/bin/env bash
# PreToolUse(Bash): mutating AWS calls must name an explicit profile.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | grep -qE '(^|[[:space:]])aws[[:space:]]' || exit 0
printf '%s' "$cmd" | grep -qE '[[:space:]](put-|create-|delete-|update-|modify-|attach-|detach-|associate-|disassociate-|run-instances|terminate-instances|start-instances|stop-instances|reboot-|authorize-|revoke-)' || exit 0
printf '%s' "$cmd" | grep -qE '(AWS_PROFILE=|--profile[[:space:]=])' && exit 0
echo "BLOCK (aws-profile): mutating AWS command without an explicit profile. Prefix with AWS_PROFILE=<profile> or pass --profile <profile>. Defaults are unsafe when several terminals are open at once." >&2
exit 2
