#!/usr/bin/env bash
# PostToolUse(Edit|Write): run the right validator for the file that changed.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
# Shared helper is checked separately; runtime path also works through symlinks.
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/file-input.sh"
payload="$(cat 2>/dev/null || true)"
while IFS= read -r file; do
[ -f "$file" ] || continue

case "$file" in
  *.tf|*.tfvars)
    command -v terraform >/dev/null 2>&1 && terraform fmt "$file" >/dev/null 2>&1 && echo "✓ terraform fmt: $file"
    ;;
  *.yml|*.yaml)
    if command -v yamllint >/dev/null 2>&1; then yamllint -d relaxed "$file" 2>&1 | head -20; fi
    case "$file" in
      *kustomization.yaml|*kustomization.yml)
        dir="$(dirname "$file")"
        if command -v kustomize >/dev/null 2>&1; then
          if kustomize build "$dir" >/dev/null 2>&1; then echo "✓ kustomize build ok: $dir"
          else kustomize build "$dir" 2>&1 | head -15; echo "⚠️  kustomize build FAILED in $dir"; fi
        fi
        ;;
    esac
    ;;
  *.sh|*.bash)
    command -v shellcheck >/dev/null 2>&1 && shellcheck "$file" 2>&1 | head -30
    ;;
  *.json)
    command -v jq >/dev/null 2>&1 && { jq -e . "$file" >/dev/null 2>&1 || echo "⚠️  INVALID JSON: $file"; }
    ;;
esac
done < <(hook_files "$payload")
exit 0
