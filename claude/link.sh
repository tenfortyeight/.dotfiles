#!/usr/bin/env bash
#
# Symlink the portable Claude Code config into ~/.claude.
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

link() { # <src-relative-to-here> <dest-relative-to-~/.claude>
  local src="$HERE/$1" dest="$CLAUDE_DIR/$2"
  [ -e "$src" ] || { warn "missing $1 — skipped"; return 0; }
  mkdir -p "$(dirname "$dest")"
  # `ln -sfn` replaces a symlink, but DESCENDS INTO a real directory and creates
  # the link inside it — silently leaving the real dir in place and unmanaged.
  # Move any real file/dir aside first so the link always lands where intended.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    local stash
    stash="$CLAUDE_DIR/backups/replaced-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$stash/$(dirname "$2")"
    mv "$dest" "$stash/$2"
    warn "replaced real $2 (saved to backups/$(basename "$stash")/$2)"
  fi
  ln -sfn "$src" "$dest"
  # Prove the link resolves — a dangling link is worse than no link.
  [ -e "$dest" ] || { warn "$2 links to a missing target"; return 1; }
  ok ".claude/$2"
}

link CLAUDE.md    CLAUDE.md
link settings.json settings.json

for f in sops-guard deploy-permission-guard deploy-ref-guard review-gate \
         aws-profile-guard commit-hygiene terraform-push-reminder \
         stale-base-guard post-edit-validate verifier-gate test-guards; do
  chmod +x "$HERE/hooks/$f.sh" 2>/dev/null || true
  link "hooks/$f.sh" "hooks/$f.sh"
done

for s in go scope verify checkpoint; do
  link "skills/$s" "skills/$s"
done

for a in nodejs-backend-expert nodejs-domain-integrator \
         nodejs-error-security-guardian nodejs-persistence-expert; do
  link "agents/$a.md" "agents/$a.md"
done

# peon-ping is installed out of band (a Homebrew formula, but NOT declared in this
# repo's Brewfile) and is not tracked here. The hook entries tolerate its absence,
# so nothing breaks on a machine without it.
have() { command -v "$1" >/dev/null 2>&1; }
have jq || warn "jq not found — every hook reads its payload with jq and will no-op without it"
have shellcheck || warn "shellcheck not found — the PostToolUse shell validator will be silent"

ok "done — run 'bash $HOME/.claude/hooks/test-guards.sh' to verify the guards fire"
