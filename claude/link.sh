#!/usr/bin/env bash
#
# Symlink the portable Claude Code config into ~/.claude, and build
# ~/.claude/settings.json from it plus this machine's settings.local.json.
#
# Called by ../install.sh; safe to run on its own. Idempotent.
#
# ~/.claude is NOT symlinked wholesale — it also holds transcripts, history,
# per-project memory and caches that are machine-local and, in several cases,
# confidential. Only the files listed below are linked, and the list is
# explicit rather than a glob for the same reason the dotfiles symlink loop is.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

info "Claude Code config"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

have() { command -v "$1" >/dev/null 2>&1; }

stash() { # <path-relative-to-~/.claude> — move a real file/dir aside before replacing it
  local dir
  dir="$CLAUDE_DIR/backups/replaced-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dir/$(dirname "$1")"
  mv "$CLAUDE_DIR/$1" "$dir/$1"
  warn "replaced real $1 (saved to backups/$(basename "$dir")/$1)"
}

link() { # <src-relative-to-here> <dest-relative-to-~/.claude>
  local src="$HERE/$1" dest="$CLAUDE_DIR/$2"
  [ -e "$src" ] || { warn "missing $1 — skipped"; return 0; }
  mkdir -p "$(dirname "$dest")"
  # `ln -sfn` replaces a symlink, but DESCENDS INTO a real directory and creates
  # the link inside it — silently leaving the real dir in place and unmanaged.
  # Move any real file/dir aside first so the link always lands where intended.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    stash "$2"
  fi
  ln -sfn "$src" "$dest"
  # Prove the link resolves — a dangling link is worse than no link.
  [ -e "$dest" ] || { warn "$2 links to a missing target"; return 1; }
  ok ".claude/$2"
}

# settings.json is BUILT, not linked: the portable settings.json here, merged
# with an optional untracked ~/.claude/settings.local.json holding this
# machine's own permissions, hooks and model. Claude Code has no user-level
# local file of its own (it reads ~/.claude/settings.local.json only in sessions
# started in ~), so the overlay is folded in here. Objects merge recursively,
# lists concatenate without duplicates, and a scalar in the overlay wins.
#
# Anything Claude Code writes into settings.json itself (/config, /model) is
# overwritten by the next build — backed up first, so move keepers into the
# overlay.
build_settings() {
  local dest="$CLAUDE_DIR/settings.json" tmp
  local sources=("$HERE/settings.json")
  [ -f "$CLAUDE_DIR/settings.local.json" ] && sources+=("$CLAUDE_DIR/settings.local.json")
  have jq || { warn "jq not found — cannot build settings.json"; return 1; }

  tmp="$(mktemp "$CLAUDE_DIR/settings.json.XXXXXX")"
  jq -s '
    def merge($a; $b):
      if ($a|type) == "object" and ($b|type) == "object" then
        reduce ($b|keys_unsorted[]) as $k ($a; .[$k] = merge($a[$k]; $b[$k]))
      elif ($a|type) == "array" and ($b|type) == "array" then $a + ($b - $a)
      elif $b == null then $a
      else $b end;
    reduce .[] as $s ({}; merge(.; $s))
  ' "${sources[@]}" > "$tmp" || { rm -f "$tmp"; warn "settings merge failed — settings.json left as is"; return 1; }
  chmod 644 "$tmp"

  # A real file that differs from the build holds edits made outside both
  # sources — keep a copy rather than silently dropping them.
  if [ -f "$dest" ] && [ ! -L "$dest" ] &&
     ! diff -q <(jq -S . "$dest" 2>/dev/null) <(jq -S . "$tmp") >/dev/null; then
    stash settings.json
  fi
  mv "$tmp" "$dest"
  ok ".claude/settings.json (built from ${#sources[@]} source(s))"
}

link CLAUDE.md    CLAUDE.md
build_settings

for f in sops-guard deploy-permission-guard deploy-ref-guard review-gate \
         aws-profile-guard commit-hygiene terraform-push-reminder \
         stale-base-guard post-edit-validate verifier-gate test-guards; do
  chmod +x "$HERE/hooks/$f.sh" 2>/dev/null || true
  link "hooks/$f.sh" "hooks/$f.sh"
done

for s in go scope verify checkpoint; do
  link "skills/$s" "skills/$s"
done

for a in nodejs-error-security-guardian nodejs-persistence-expert; do
  link "agents/$a.md" "agents/$a.md"
done

# peon-ping is installed out of band (a Homebrew formula, but NOT declared in this
# repo's Brewfile) and is not tracked here. The hook entries tolerate its absence,
# so nothing breaks on a machine without it.
have jq || warn "jq not found — every hook reads its payload with jq and will no-op without it"
have shellcheck || warn "shellcheck not found — the PostToolUse shell validator will be silent"

ok "done — run 'bash $HOME/.claude/hooks/test-guards.sh' to verify the guards fire"
