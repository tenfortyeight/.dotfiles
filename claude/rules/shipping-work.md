# Shipping work

The team is spread across time zones and picks up each other's work at the start
of their own morning. Work that exists only on this laptop is invisible to them —
a commit nobody can fetch is worth the same as no commit.

- **Push every commit.** Standing permission, no need to ask: pushing is the end
  of committing, not a separate decision. Half-finished is fine — a pushed WIP
  branch beats a perfect branch nobody else can see.
- **A branch lives half a working day; a day at most.** Past that, say so and ask
  whether it is time to merge — don't wait to be asked. Work that can't land
  inside a day was scoped too large: split it into pieces that each land alone.
- **Merging still needs my go-ahead** (see `CLAUDE.md`). Raising the question is
  your job; deciding is mine. Same for deploy, release, tag, force-push.
- **End a session with nothing unpushed.** If work is genuinely unfinished, push
  the branch anyway and leave the state legible for whoever opens it next — what
  works, what doesn't, what's next — in the commit messages or the PR body.
- **Fetch first still applies.** Others push while you work; reconcile before you
  build more on a stale base.
- **Delete the branch when it merges — local and remote.** A branch that outlives
  its merge advertises an intention that is now simply history, and the next
  person can't tell the two apart. `gh pr merge --delete-branch` does both sides
  in one step; otherwise `git push origin --delete <branch>` then
  `git branch -d <branch>`. `fetch.prune` only clears stale `origin/*` tracking
  refs and never deletes a local branch, so that half stays a deliberate act.
  Worth setting `gh repo edit --delete-branch-on-merge` once per repo.
- **Close the day with a handover.** Run `/handover` before stepping away: a
  short forward-looking note for the team chat — where things stand, what's next,
  what's still open — so whoever starts their morning next knows where to go
  without reading the diff.
