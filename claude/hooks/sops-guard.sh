#!/usr/bin/env bash
# PreToolUse(Edit|Write): never edit an encrypted SOPS file in place.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -z "$file" ] && exit 0
case "$file" in
  *.enc.yaml|*.enc.yml|*.enc.json|*.enc.env) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0
head -c 400 "$file" 2>/dev/null | grep -q 'ENC\[AES256' || exit 0
echo "BLOCK (sops-guard): '$file' is SOPS-encrypted. Never edit it directly — decrypt, edit, re-encrypt via sops (EDITOR=\"sed ...\" sops \"$file\"), passing an explicit AWS profile if KMS-backed." >&2
exit 2
