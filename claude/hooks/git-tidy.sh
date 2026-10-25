#!/usr/bin/env bash
#
# SessionStart: clear away merged worktrees and branches in the current repo,
# or, when the session starts in a folder of repos, in each repo directly
# below it (one level; linked worktrees are left to the repo that owns them).
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
# One line, and only if it removed something or a repo could not be tidied;
# never fails the session.
set -Eeuo pipefail   # -E: the ERR trap reaches functions and subshells too
trap 'echo "git-tidy: stopped early at line $LINENO"; exit 0' ERR

IDLE_MINUTES=60
BUDGET_SECONDS=90   # stop starting new repos after this; each fetch/push has its own timeout
# Branches that live on even when merged: deploy, release and integration lines.
LONG_LIVED='^(main|master|develop|dev|staging|stage|production|prod|release.*|gh-pages|HEAD)$'
SESSION_DIR="$(pwd -P)"

with_timeout() {
  local t
  t="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$t" ]; then "$t" 20 "$@"; else "$@"; fi
}

# A linked worktree shares another repo's history; that repo tidies it.
is_main_checkout() { # <dir>
  [ "$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" = \
    "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]
}

repos_to_tidy() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$PWD"
    return
  fi
  local d
  for d in "$PWD"/*/; do
    d="${d%/}"
    if [ -e "$d/.git" ] && is_main_checkout "$d"; then echo "$d"; fi
  done
}

default_branch() {
  local d b
  d="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  d="${d#origin/}"
  if [ -z "$d" ]; then
    for b in main master; do
      if git show-ref --quiet --verify "refs/remotes/origin/$b"; then d="$b"; break; fi
    done
  fi
  echo "$d"
}

merged() { git merge-base --is-ancestor "$1" "$base" 2>/dev/null; }

recently_touched() { # <worktree path>
  local gitdir
  gitdir="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null || true)"
  [ -n "$(find "$1" -name node_modules -prune -o -mmin -"$IDLE_MINUTES" -print -quit 2>/dev/null)" ] ||
    { [ -n "$gitdir" ] && [ -n "$(find "$gitdir" -mmin -"$IDLE_MINUTES" -print -quit 2>/dev/null)" ]; }
}

removable_worktree() { # <path> <head>
  [ -d "$1" ] || return 1
  case "$SESSION_DIR/" in "$1"/*) return 1 ;; esac   # never the one this session is in
  merged "$2" || return 1
  ! recently_touched "$1" || return 1   # before status, which can rewrite the index
  [ -z "$(git -C "$1" status --porcelain 2>/dev/null || echo dirty)" ]
}

tidy_worktrees() {
  local main_wt="" path="" head="" locked="" line
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
}

tidy_branches() {
  local checked_out b
  checked_out="$(git worktree list --porcelain | sed -n 's|^branch refs/heads/||p')"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    [[ "$b" =~ $LONG_LIVED ]] && continue
    grep -qxF "$b" <<<"$checked_out" && continue
    if git branch -d --quiet "$b" >/dev/null 2>&1; then branches=$((branches + 1)); fi
  done < <(git branch --merged "$base" --format='%(refname:short)')
}

# Only your own: a merged branch someone else pushed is theirs to delete.
tidy_remote_branches() {
  local me ref b gone=()
  me="$(git config user.email || true)"
  while IFS= read -r ref; do
    b="${ref#origin/}"
    [ "$b" != "$default" ] && [ "$ref" != origin ] || continue
    [[ "$b" =~ $LONG_LIVED ]] && continue
    [ -n "$me" ] && [ "$(git log -1 --format=%ae "$ref")" = "$me" ] || continue
    gone+=("$b")
  done < <(git branch -r --merged "$base" --format='%(refname:short)' | grep '^origin/' || true)
  if [ "${#gone[@]}" -gt 0 ] && with_timeout git push --quiet origin --delete "${gone[@]}" 2>/dev/null; then
    remotes="${#gone[@]}"
  fi
}

tidy_checkpoints() {
  local dir
  dir="$(git rev-parse --show-toplevel)/.claude/checkpoints"
  if [ -d "$dir" ]; then
    checkpoints="$(find "$dir" -maxdepth 1 -name '*.md' -type f -mtime +14 -print -delete | wc -l | tr -d ' ')"
  fi
}

# Runs in a subshell so one repo's failure cannot stop the others.
# Prints "<worktrees> <branches> <remotes> <checkpoints>", or a reason it gave up.
tidy_repo() { # <dir>
  (
    set -e
    trap 'echo "stopped at line $LINENO"; exit 0' ERR
    cd "$1"
    worktrees=0 branches=0 remotes=0 checkpoints=0
    git remote get-url origin >/dev/null 2>&1 || { echo "0 0 0 0"; exit 0; }
    with_timeout git fetch --quiet --prune origin 2>/dev/null || { echo "fetch failed"; exit 0; }
    default="$(default_branch)"
    [ -n "$default" ] || { echo "0 0 0 0"; exit 0; }
    base="origin/$default"
    tidy_worktrees
    tidy_branches
    tidy_remote_branches
    tidy_checkpoints
    echo "$worktrees $branches $remotes $checkpoints"
  )
}

worktrees=0 branches=0 remotes=0 checkpoints=0 problems=""
while IFS= read -r repo; do
  if [ "$SECONDS" -ge "$BUDGET_SECONDS" ]; then problems="$problems; out of time at ${repo##*/}"; break; fi
  result="$(tidy_repo "$repo")"
  if [[ "$result" =~ ^[0-9]+\ [0-9]+\ [0-9]+\ [0-9]+$ ]]; then
    read -r w b r c <<<"$result"
    worktrees=$((worktrees + w)) branches=$((branches + b))
    remotes=$((remotes + r)) checkpoints=$((checkpoints + c))
  else
    problems="$problems; ${repo##*/}: $result"
  fi
done < <(repos_to_tidy)

[ $((worktrees + branches + remotes + checkpoints)) -gt 0 ] || [ -n "$problems" ] || exit 0
echo "git-tidy: removed $worktrees worktree(s), $branches branch(es), $remotes remote branch(es), $checkpoints old checkpoint(s)$problems"
