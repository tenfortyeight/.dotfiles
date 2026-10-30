---
name: release-notes
description: >
  Use when the user asks for release notes, or types /release-notes: cheerful,
  emoji-led notes, one item per change, 1–2 plain sentences each, written as a
  chat message they can paste anywhere. Covers the work done in this session
  unless the user names a range, a date or a set of PRs.
user-invocable: true
---

# /release-notes — Cheerful notes on what shipped

The user wants to share what got done with people who were not in the session, and
wants it to feel like good news. Same format every time, so nobody has to describe it
again.

## What to cover

**Default: the work done in this session** — what was built, shipped, fixed, moved or
cleaned up, and what is open but not merged. Nothing from other sessions or other
people unless the user asks.

If the user names a scope instead — "since Monday", "the last release", a tag, a
list of PRs — or the session has no work of its own to report, gather from git:

```bash
git fetch origin --quiet
git log --no-merges --pretty='%h %ad %s' --date=short <from>..origin/<default>
gh pr list --state merged --search 'merged:>=<date>' --json number,title,url
gh pr list --state open --draft --json number,title     # candidates for "Coming soon"
```

Only claim what you can point to: a merged PR, a commit on the default branch, a
deploy you watched. Work that is open goes under **Coming soon**, never in the main
list.

## Format

```markdown
🎉 **Release notes: <short theme of the work>** 🎉

<emoji> **<What changed, as one bold sentence.>** <1–2 plain sentences: what this means for whoever uses it, and the one detail that makes it believable.>

<emoji> **<Next item.>** <…>

🔜 **Coming soon:**
- <open PR or next step, with its number when there is one>
```

- **One paragraph per item**, a blank line between them. No bullet list for the main
  items; only *Coming soon* is a list.
- **Each item opens with one emoji that fits it** (🗂️ for a move, 🧹 for a cleanup,
  🔐 for auth, 📊 for metrics, 🐛 for a fix) and a **bold lead sentence** that says
  what changed. A second emoji at the end of an item is fine now and then, not on
  every one.
- **1–2 sentences after the bold lead, no more.** Say what it means for the people
  who use it rather than how it was built. Name the service, page or command they
  will recognise.
- **Plain, warm voice.** No jargon a reader would have had to be in the session to
  follow, no internal ticket shorthand. "Nobody's flow broke" beats "zero regressions
  observed".
- **Group small things.** Several minor removals become one *Spring cleaning* item.
  Aim for 5–12 items; past that, merge or drop the least interesting.
- **Order by what readers care about most**, not by when it happened.
- Drop *Coming soon* when nothing is open.

## Delivering it

Reply with the notes as a chat message and nothing around them, ready to paste. Don't
write a file, post anywhere, or create a GitHub release unless the user asks — then
the same text goes in as-is.

## Example

```markdown
🎉 **Release notes: one place for every API key** 🎉

🔑 **Every API key now lives in one list.** The billing and search apps both read from the key registry, so a key gets created once and works everywhere.

🏷️ **"Clients" are now "Accounts".** The new name matches what support already calls them, in the UI, the API and the database.

🧹 **Spring cleaning.** Three unused admin pages are gone, and the reports service no longer asks for write access it never used.

🐛 **Exports finish again.** Large CSV exports that stalled at 99% now complete, and a failed export says why instead of spinning forever.

🔜 **Coming soon:**
- Key rotation from the settings page (#212).
```
