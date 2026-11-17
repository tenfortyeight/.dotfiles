#!/usr/bin/env bash
# Exercise actual Codex patch payloads and Claude's single-file payload.
set -euo pipefail
HOOKS="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS/file-input.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'ENC[AES256,data:example]\n' > "$TMP/secret.enc.yaml"
printf '{ broken\n' > "$TMP/first.json"
printf '{ broken\n' > "$TMP/second.json"
patch='*** Begin Patch
*** Update File: first.json
@@
-old
+new
*** Update File: old name.json
*** Move to: second.json
@@
-old
+new
*** Add File: added.json
+{}
*** Delete File: deleted.json
*** End Patch'
payload="$(jq -n --arg cwd "$TMP" --arg patch "$patch" '{cwd:$cwd,tool_name:"apply_patch",tool_input:{command:$patch}}')"
expected="$(printf '%s\n' "$TMP/added.json" "$TMP/deleted.json" "$TMP/first.json" "$TMP/old name.json" "$TMP/second.json")"
[ "$(hook_files "$payload")" = "$expected" ]
output="$(printf '%s' "$payload" | bash "$HOOKS/post-edit-validate.sh")"
[[ "$output" == *"INVALID JSON: $TMP/first.json"* ]]
[[ "$output" == *"INVALID JSON: $TMP/second.json"* ]]
for directive in 'Update File' 'Delete File' 'Move to'; do
  payload="$(jq -n --arg cwd "$TMP" --arg patch "*** Begin Patch
*** $directive: secret.enc.yaml
*** End Patch" '{cwd:$cwd,tool_name:"apply_patch",tool_input:{command:$patch}}')"
  rc=0
  printf '%s' "$payload" | bash "$HOOKS/sops-guard.sh" >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ]
done
payload="$(jq -n --arg cwd "$TMP" '{cwd:$cwd,tool_input:{file_path:"secret.enc.yaml"}}')"
[ "$(hook_files "$payload")" = "$TMP/secret.enc.yaml" ]
[ -z "$(hook_files '{"tool_name":"Bash","tool_input":{"command":"echo *** Delete File: secret.enc.yaml"}}')" ]
echo 'file-input: patch paths, multiple validators, SOPS update/delete/move, Claude input passed'
