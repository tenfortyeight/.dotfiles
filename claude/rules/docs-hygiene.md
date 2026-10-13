# One source of truth for docs

Docs are read by people picking up work cold and by Claude sessions starting with
an empty context window. Two documents that disagree are worse than one that is
merely out of date: the reader can't tell which one describes reality, so they
have to reconstruct it from the code anyway — and the wrong one keeps sending
people down a path that no longer exists.

- **Update in place. Don't add a second copy.** Grep for an existing doc on the
  subject before writing a new one, the same way you'd look for an existing
  primitive in code.
- **When reality moves, migrate or delete the stale doc in the same change** —
  not as a follow-up that never comes. Git history is the archive; a superseded
  doc left in the tree is not archived, it's a competing claim.
- **Delete rather than deprecate** where you can. A doc marked "outdated" still
  gets read and still costs everyone the read.
- Same rule for checkpoints, plans and scratch notes once the work lands: they
  described an intention, and intentions that became reality belong in the code
  and the commit history, not in a file that outlives them.
- If the cleanup is genuinely bigger than the task at hand, say so plainly rather
  than silently leaving two truths behind.
