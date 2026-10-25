---
name: scope
description: >
  Kickoff interview. Use it yourself when the user starts something new — a
  feature, an idea, a fresh piece of work — and the ask leaves open what done
  looks like; also when the user types /scope. One short round of multiple-choice
  questions with your recommendation pre-selected, then a brief, then
  autonomous work, one focus per session. A "help me sort this out" opening that mixes several topics,
  questions and wishes counts as a loose start: answer the factual questions
  inside the interview, not in a report before it. Not for a single precise
  ask, a bug with a clear repro, a lone question, or work already under way.
user-invocable: true
---

# /scope — Kickoff Interview

The start of new work is where the ask is loosest and patience shortest. A
loose start costs a dozen corrections later. Spend one short round of
questions up front, then work without stopping.

## 1. Do the homework first

Infer everything you can before asking anything: the repo's CLAUDE.md and
docs (product, plans, decisions), memory, the board or issue, recent commits,
and the repo's product-owner doc if it has one. A question whose answer is
written down somewhere is a question you should not ask.

## 2. One thing at a time

The user often opens with several things at once — that is how a busy head
empties itself, not a request to do them all in parallel. The user's focus is
the scarce resource; hold it for them.

- The first question picks **the one thing this session is for**. Recommend
  the one that matters most now (what unblocks income, users or a deadline
  beats what is nice), and say in a clause why.
- Every other topic is **parked**, not dropped: one line each in the repo's
  parked list if it has one (else keep it for the final report), named back
  in a single line so the user sees nothing was lost. Answer a parked topic's
  quick factual question in a line if it costs nothing; don't start its work.
- When the focus is done, offer the **next one** from the parked items as the
  single ask at the end: "Next in line: X — start it?"
- Mid-session, a new topic from the user is parked the same way, with one line
  saying so, and the work carries on. Switch only when the user says switch.

## 3. Ask one round

Use AskUserQuestion: at most four questions, each with two to four concrete
options and your recommendation first, marked "(Recommended)". Ask in the
user's terms — outcomes and the people it is for — not implementation.
Implementation is yours to decide.

Pick the questions that would most change the work. Usually:

- **What done looks like** — the outcome, and who notices it.
- **In and out** — the one or two things that could plausibly be in either.
- **How hands-on** — whether the result deploys once verified, or waits for a
  go-ahead. Recommend from the change: small and contained deploys once
  verified; wide or sensitive (migrations, data deletion, auth, payments,
  privacy or legal text, infrastructure, secrets) waits. Skip this question
  when nothing will deploy.

Answer the user's factual questions in a few plain lines just before the
questions — the homework already has them. Every decision you need from the
user goes into the questions as options; never leave one as an open question
in prose for the user to write an answer to.

Ask a second round only when an answer opens a real fork. If the user answers
"just do it" or skips, take the recommendations.

## 4. Write the brief and start

Five to ten lines, then begin at once — no approval wait; the user can
interrupt:

```
## Brief: <one line>
Done means: <the observable outcome>
In: <items, including implied ones: tests, docs, migrations, cleanup>
Out: <what this is not>
Deploy: <once verified | waits for your go-ahead — and why>
Decided by me: <calls made from the homework, so they can be overruled>
```

The brief is the cutoff: finish every item on it, and don't stop at most of
them. Something new that belongs in it gets added and named in the report;
something infeasible gets surfaced, not dropped. Put the brief at the top of
every subagent brief so the work stays on it.

## Authoritative inventories, not estimates

When the work is "all the X that need Y", query the source of truth (`gh issue
list`, `git log`, a count, `find`) and put the number or the query in the
brief.
