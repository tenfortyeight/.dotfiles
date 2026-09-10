#!/usr/bin/env bash
#
# Rebind the built-in macOS window tiling shortcuts to Rectangle's layout.
# Idempotent — re-run it whenever.
#
#   macos/window-shortcuts.sh
#
# macOS ships its own tiling (System Settings → Keyboard → Keyboard Shortcuts →
# Windows) on ^🌐 and ^⇧🌐 combinations, which need the globe key and bear no
# resemblance to the ^⌥ layout Rectangle uses. This puts the system shortcuts on
# the Rectangle chords instead, so the muscle memory carries over and no extra
# app has to run.
#
# Only the actions macOS actually has are mapped. Rectangle's thirds, maximize-
# height, grow/shrink and move-to-next-display have no built-in counterpart, so
# if you want those you still want Rectangle itself.

set -euo pipefail

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

DOMAIN=com.apple.symbolichotkeys
PLISTBUDDY=/usr/libexec/PlistBuddy

# NSEvent modifier flags. ^⌥ is the modifier pair every Rectangle default uses.
#   shift 131072   control 262144   option 524288   command 1048576   fn 8388608
CTRL_OPT=$((262144 + 524288))   # 786432

# id:charCode:keyCode:label
#
# The ids are Apple's own — read them out of the Windows section of
# /System/Library/ExtensionKit/Extensions/KeyboardSettings.appex/Contents/\
# Resources/en.lproj/DefaultShortcutsTable.xml if you ever need to add one.
#
# charCode is the ASCII of the character the key produces, and 65535 for any key
# that produces none. Arrows are the obvious case; return and delete are not —
# giving return its literal ASCII 13 writes a binding that the UI displays
# correctly and that then silently never fires. Use 65535 for both.
BINDINGS=(
  # General
  "237:65535:36:Fill                       ^⌥return"
  "238:99:8:Center                     ^⌥C"
  "239:65535:51:Return to Previous Size    ^⌥delete"
  # Halves
  "240:65535:123:Tile Left Half             ^⌥←"
  "241:65535:124:Tile Right Half            ^⌥→"
  "242:65535:126:Tile Top Half              ^⌥↑"
  "243:65535:125:Tile Bottom Half           ^⌥↓"
  # Quarters
  "244:117:32:Tile Top Left Quarter      ^⌥U"
  "245:105:34:Tile Top Right Quarter     ^⌥I"
  "246:106:38:Tile Bottom Left Quarter   ^⌥J"
  "247:107:40:Tile Bottom Right Quarter  ^⌥K"
)

[ "$(uname -s)" = "Darwin" ] || { warn "not macOS — nothing to do"; exit 0; }

info "Window shortcuts (Rectangle layout)"

# Edit an exported copy and import it back, rather than writing the plist in
# place. cfprefsd caches this domain and would overwrite a direct file edit with
# what it still has in memory.
#
# It has to be PlistBuddy and not `defaults write`, because `defaults write`
# with an old-style plist string stores every value as a *string* — and the
# hotkey system silently ignores an entry whose parameters are "65535" rather
# than 65535. That failure looks exactly like a wrong key code.
tmp="$(mktemp -t symbolichotkeys)"
trap 'rm -f "$tmp"' EXIT

defaults export "$DOMAIN" "$tmp" 2>/dev/null || printf '{}' > "$tmp"
$PLISTBUDDY -c "Add :AppleSymbolicHotKeys dict" "$tmp" >/dev/null 2>&1 || true

for entry in "${BINDINGS[@]}"; do
  IFS=: read -r id char key label <<< "$entry"
  root=":AppleSymbolicHotKeys:$id"
  # Delete first so a re-run replaces the entry instead of failing on Add.
  $PLISTBUDDY -c "Delete $root" "$tmp" >/dev/null 2>&1 || true
  $PLISTBUDDY \
    -c "Add $root dict" \
    -c "Add $root:enabled bool true" \
    -c "Add $root:value dict" \
    -c "Add $root:value:type string standard" \
    -c "Add $root:value:parameters array" \
    -c "Add $root:value:parameters:0 integer $char" \
    -c "Add $root:value:parameters:1 integer $key" \
    -c "Add $root:value:parameters:2 integer $CTRL_OPT" \
    "$tmp" >/dev/null
  ok "$label"
done

defaults import "$DOMAIN" "$tmp"

# Re-registers the hotkeys with the window server. Without this the new
# bindings only take effect at the next login.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

ok "applied"
warn "VS Code needs vscode/keybindings.json too — it binds ^⌥←, ^⌥→ and ^⌥⌫"
