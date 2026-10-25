#!/usr/bin/env bash
#
# SessionStart: clear away merged worktrees and branches in the current repo.
#
# Sessions were told to clean up after merging and kept leaving worktrees and
# branches behind anyway, so this does it for them. Safe to run by hand too.
#
# Removes only what has nothing left to lose:
#   - worktrees that are clean, whose HEAD is already on origin/<default>, and
#     that nothing has touched for an hour (so a live peer session keeps its own)
#   - local branches merged into origin/<default>, with `git branch -d` only
#   - your own remote branches merged into origin/<default>, never long-lived ones
#   - .claude/checkpoints/*.md older than 14 days
#
# Quiet unless it removed something; never fails the session.
set -euo pipefail
trap 'echo "git-tidy: stopped early at line $LINENO"; exit 0' ERR

IDLE_MINUTES=60
# Branches that live on even when merged: deploy, release and integration lines.
LONG_LIVED='^(main|master|develop|dev|staging|stage|production|prod|release.*|gh-pages|HEAD)$'

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

with_timeout() {
  local t
  t="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$t" ]; then "$t" 20 "$@"; else "$@"; fi
}

with_timeout git fetch --quiet --prune origin 2>/dev/null || { echo "git-tidy: fetch failed, skipped"; exit 0; }

default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default="${default#origin/}"
if [ -z "$default" ]; then
  for b in main master; do
    git show-ref --quiet --verify "refs/remotes/origin/$b" && default="$b" && break
  done
fi
[ -n "$default" ] || exit 0
base="origin/$default"

merged() { git merge-base --is-ancestor "$1" "$base" 2>/dev/null; }

recently_touched() { # <worktree path>
  local gitdir
  gitdir="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null || true)"
  [ -n "$(find "$1" -name node_modules -prune -o -mmin -"$IDLE_MINUTES" -print -quit 2>/dev/null)" ] ||
    { [ -n "$gitdir" ] && [ -n "$(find "$gitdir" -mmin -"$IDLE_MINUTES" -print -quit 2>/dev/null)" ]; }
}

removable_worktree() { # <path> <head>
  [ -d "$1" ] || return 1
  case "$(pwd -P)/" in "$1"/*) return 1 ;; esac   # never the one this session is in
  merged "$2" || return 1
  ! recently_touched "$1" || return 1   # before status, which can rewrite the index
  [ -z "$(git -C "$1" status --porcelain 2>/dev/null || echo dirty)" ]
}

worktrees=0
main_wt="" path="" head="" locked=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) path="${line#worktree }"; head=""; locked=""
                  [ -n "$main_wt" ] || main_wt="$path" ;;
    "HEAD "*)     head="${line#HEAD }" ;;
    locked*)      locked=1 ;;
    "")           if [ "$path" != "$main_wt" ] && [ -z "$locked" ] && [ -n "$head" ] &&
                     removable_worktree "$path" "$head" &&
                     git worktree remove "$path" 2>/dev/null; then
                    worktrees=$((worktrees + 1))
                  fi
                  path="" ;;
  esac
done < <(git worktree list --porcelain; echo)
git worktree prune

checked_out="$(git worktree list --porcelain | sed -n 's|^branch refs/heads/||p')"
branches=0
while IFS= read -r b; do
  [ -n "$b" ] || continue
  [[ "$b" =~ $LONG_LIVED ]] && continue
  grep -qxF "$b" <<<"$checked_out" && continue
  git branch -d --quiet "$b" >/dev/null 2>&1 && branches=$((branches + 1))
done < <(git branch --merged "$base" --format='%(refname:short)')

# Only your own: a merged branch someone else pushed is theirs to delete.
me="$(git config user.email || true)"
gone=()
while IFS= read -r ref; do
  b="${ref#origin/}"
  [ "$b" != "$default" ] && [ "$ref" != origin ] || continue
  [[ "$b" =~ $LONG_LIVED ]] && continue
  [ -n "$me" ] && [ "$(git log -1 --format=%ae "$ref")" = "$me" ] || continue
  gone+=("$b")
done < <(git branch -r --merged "$base" --format='%(refname:short)' | grep '^origin/' || true)
remotes=0
if [ "${#gone[@]}" -gt 0 ] && with_timeout git push --quiet origin --delete "${gone[@]}" 2>/dev/null; then
  remotes="${#gone[@]}"
fi

checkpoints=0
dir="$(git rev-parse --show-toplevel)/.claude/checkpoints"
if [ -d "$dir" ]; then
  checkpoints="$(find "$dir" -maxdepth 1 -name '*.md' -type f -mtime +14 -print -delete | wc -l | tr -d ' ')"
fi

[ $((worktrees + branches + remotes + checkpoints)) -gt 0 ] || exit 0
echo "git-tidy: removed $worktrees worktree(s), $branches branch(es), $remotes remote branch(es), $checkpoints old checkpoint(s)"
