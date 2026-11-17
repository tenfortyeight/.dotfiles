#!/usr/bin/env bash
# Shared Claude Edit/Write and Codex apply_patch file list. Payload is JSON.
hook_files() {
  local payload="$1" cwd file
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
  while IFS= read -r file; do
    case "$file" in
      /*) printf '%s\n' "$file" ;;
      *) printf '%s/%s\n' "${cwd:-$PWD}" "$file" ;;
    esac
  done < <(printf '%s' "$payload" | jq -r '
    if .tool_input.file_path? then .tool_input.file_path
    elif .tool_name == "apply_patch" then
      .tool_input.command // "" | split("\n")[] |
      select(test("^\\*\\*\\* (Add File|Update File|Delete File|Move to): ")) |
      sub("^\\*\\*\\* (Add File|Update File|Delete File|Move to): "; "")
    else empty end
  ' | sort -u)
}
