#!/usr/bin/env bash
# PreToolUse(Edit|Write): never edit an encrypted SOPS file in place.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
# Shared helper is checked separately; runtime path also works through symlinks.
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/file-input.sh"
payload="$(cat 2>/dev/null || true)"
while IFS= read -r file; do
case "$file" in
  *.enc.yaml|*.enc.yml|*.enc.json|*.enc.env) ;;
  *) continue ;;
esac
[ -f "$file" ] || continue
head -c 400 "$file" 2>/dev/null | grep -q 'ENC\[AES256' || continue
echo "BLOCK (sops-guard): '$file' is SOPS-encrypted. Never edit it directly — decrypt, edit, re-encrypt via sops (EDITOR=\"sed ...\" sops \"$file\"), passing an explicit AWS profile if KMS-backed." >&2
exit 2
done < <(hook_files "$payload")
