#!/usr/bin/env bash
#
# Make an iTerm2 split pane open in the directory the pane you split was in.
# Idempotent — re-run it whenever.
#
#   macos/iterm-working-directory.sh
#
# iTerm2 keeps one working-directory setting per profile (Settings → Profiles →
# General → Working Directory). Of its four modes only "Advanced" can answer
# differently for panes than for tabs and windows, which is exactly the split
# wanted here: a split pane carries on where you already are, while a new tab or
# window starts clean at $HOME.
#
# "Advanced" then stores one option per kind of session in these AWDS (advanced
# working directory setting) keys:
#
#   Recycle  reuse the directory of the session you came from
#   No       home directory
#   Yes      the fixed path in the matching "AWDS ... Directory" key
#
# Recycle needs no shell integration — iTerm2 asks the pane's process where it
# is through the pidinfo XPC service it ships with.

set -euo pipefail

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

DOMAIN=com.googlecode.iterm2
PROFILES="New Bookmarks"   # iTerm2's own name for the profile array

# Applied to every profile, so a second one — a hotkey window, say — behaves
# like the first instead of being a surprise months later. "Advanced" is what
# makes the other three mean anything at all.
SETTINGS=(
  "Custom Directory=Advanced"
  "AWDS Pane Option=Recycle"
  "AWDS Tab Option=No"
  "AWDS Window Option=No"
)

[ "$(uname -s)" = "Darwin" ] || { warn "not macOS — nothing to do"; exit 0; }

info "iTerm2 working directory"

# Edit an exported copy and import it back rather than writing the plist in
# place: cfprefsd caches this domain and would overwrite a direct file edit with
# what it still holds in memory.
tmp="$(mktemp -t iterm2)"
trap 'rm -f "$tmp"' EXIT
defaults export "$DOMAIN" "$tmp" 2>/dev/null || printf '{}' > "$tmp"

# iTerm2 writes its profiles on first launch. There is nothing to patch before
# that, and inventing a profile here would only fight with the one it creates.
# `-extract <array> raw` prints the element count.
if ! count=$(plutil -extract "$PROFILES" raw -o - "$tmp" 2>/dev/null); then
  warn "iTerm2 has not run on this machine yet — open it once, then re-run this"
  exit 0
fi

for ((i = 0; i < count; i++)); do
  for setting in "${SETTINGS[@]}"; do
    # -replace adds the key when it is missing, so this covers both.
    plutil -replace "$PROFILES.$i.${setting%%=*}" -string "${setting#*=}" "$tmp"
  done
  ok "$(plutil -extract "$PROFILES.$i.Name" raw -o - "$tmp")"
done

defaults import "$DOMAIN" "$tmp"
ok "applied to $count profile(s)"

# iTerm2 holds every profile in memory and saves the set back when it quits, so
# a change made underneath a running copy can be undone the moment you quit it.
# Re-running after quitting costs nothing and settles it.
#
# shellcheck disable=SC2009  # pgrep finds nothing for iTerm2 at all: it matches
# the short accounting name, which a bundled GUI app does not carry. ps does.
if ps -Ao comm= | grep -q '/iTerm.app/Contents/MacOS/iTerm2$'; then
  warn "iTerm2 is running and may save over this when it quits — quit it and re-run"
fi
