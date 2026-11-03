---
name: wwad
description: >
  Web design and UI work: use whenever you build or change anything a person sees
  in a web app — a page, a component, an empty state, a chart, a whole new UI —
  or when the user types /wwad. Makes the result look thought-through rather than
  generated, without the user spelling out the design each time.
user-invocable: true
---

<!-- "What would Ahlinder do": distilled from apps built by Mikael Ahlinder
     (https://github.com/mikaelahlinder). -->

# /wwad — draw the picture first, then build it

Good-looking apps are not decorated. They are decided: what the screen is for, what the
eye lands on, what each colour and shape means, and what every state says. This skill is
that deciding, written as steps, for someone who thinks in boxes and arrows.

**The bridge for a backend mind:** a screen is a data model drawn. Things become shapes,
their most important number becomes size or position, relations become wires or nearness,
and state becomes a mark or motion. You already know the model; pick the drawing for it.

## 0. Read what is already decided

Before touching UI, find the repo's design doc (`docs/design*.md`, `docs/ui.md`, a design
section in the README or CLAUDE.md), its tokens file and its shared components. Build only
from those. A piece that is missing is added to the kit first, then used. No design doc
yet: start one (step 7) as you make the first decisions.

## 1. Every screen answers three questions

Write these down before any code — one sentence each:

1. **Where am I?** The rail or crumb shows it; the heading names the thing in the user's
   own nouns. The browser tab title comes from the heading.
2. **What is this?** One sentence under the heading. Anything longer goes in a fold
   ("More about this").
3. **What do I do next?** One primary action, or one status line that names the next step
   ("2 to fix, 1 to weigh"). If nothing needs doing, say so: "Nothing needs you."

If you cannot write the three sentences, the screen is not understood yet. Write your
best guess, say it in a line, and carry on; ask only if the answer is a business decision.

## 2. Find the picture

Ask what the user holds in their head when they think about this thing. If the data has
a shape — things that flow, depend, own, call each other, change over time — draw that
shape: a canvas of steps and wires, a star with the main thing at the centre, a map where
nearness means "talks to", a timeline with notches. If it is a list, it is a list; a
diagram that says nothing the list doesn't gets deleted.

Then assign the encodings, **one meaning per visual channel**, and write the key:

| Channel | Spend it on | Example |
|---|---|---|
| Size | the one number that matters most (log scale, capped) | traffic, spend |
| Position / nearness | relationship or flow direction | callers sit close; inputs left, result right |
| Colour | category or owner, never decoration | one hue per kind or team |
| Red / warm accent | failure only | failing node, error tint |
| Line style | solid = real, dashed = not there yet / optional | a dashed "not joined" card |
| Motion | only what is live right now | dots travelling along a busy wire |

Show the key on screen in plain words ("Size: traffic · Red: failing"). Make the main
thing the one hero: bigger, stronger, centred. Everything else steps back. Detail comes
with zoom or hover: overview when zoomed out, labels when zoomed in, neighbours lit and
the rest dimmed on hover. Compute the layout before the first paint and fit the view to
what matters, so it opens settled — no layout that jiggles into place.

**Worked example.** A backend has a table of services: `name, owner_team, calls[],
req_per_s, failing, deploying`. The list view is fine for finding one. The picture
answers "what does the system look like right now":

- service → a dot; `req_per_s` → dot size (log scale, capped) and how many dots travel
  each wire.
- `calls[]` → curved wires, with callers pulled close by a force layout.
- `owner_team` → a faint ring around each team's dots, labelled, one colour per team.
- `failing` → red with a label in the hover card; `deploying` → a dashed ring.
- Key along the bottom; live totals along the top ("72 services · 158 req/s · 0 errors").
- Hover lights a dot and its neighbours, with a card listing "Called by" and "Calls".
  Click opens the service's own page.

Same data and the same backend; the only new work is choosing what each column becomes.

## 3. A small closed system

One tokens file is the contract. No literal colours, sizes or durations in a component.
If the repo has none, start with:

- **Surfaces as steps**, not ad-hoc greys: `bg`, `raised`, `overlay`, `hover`, plus `line`
  (a hairline) and `fg` / `muted` / `faint`. Tint the neutrals slightly warm or toward the
  brand hue; plain blue-grey is the generic look. Depth comes from fills, at most a
  hairline; a shadow only for what floats.
- **One accent, rationed to "act here"**: the primary button, the current selection,
  links, focus. Mostly worn as a soft tint (~10–15% alpha), solid only on the one button.
- **Semantic hues for meaning only**: ok, busy, warning, failure — separate tokens, never
  reused as decoration, and each with a text-safe "ink" for use on its tint.
- **Type**: a display face for headings, one body face, mono for ids and code. A short
  named scale (caption ~11px tracked caps, body ~14, title ~15–24, one hero size).
- **Spacing** 4/8/12/16/24/32/48 and one gap between blocks, so every page has the same
  rhythm. **One corner radius** for cards, a smaller one for small things, pills for
  chips. One content width per page kind (a reading column ~720px, a work page ~1100–1240).
- **Motion**: 120 / 220 / 480 ms, eased out (`cubic-bezier(.2,.8,.2,1)`).
- **Dark and light are a token swap**, not a second stylesheet. Measure contrast and
  write the ratios in a comment next to the tokens.

## 4. Quiet by default

- **One loud thing per screen.** At most one solid button; most screens have none.
- **Hierarchy over badges.** A row leads with its name; kind and state are quiet text or
  one tag, not a row of equal coloured pills. Rows read: what it is, state, detail, dates,
  actions.
- **The expected state says nothing.** "On" needs no badge; "Off" or "not published" does.
- **Hover changes colour, never position.** A ring or glow; nothing lifts, grows or scales.
- **Edit the thing where it is.** Side panels beside the content rather than modals over
  it; the app's own dialog for anything destructive, never the browser's `confirm()`.
- **Nothing left to the browser's own look**: selects, tooltips and focus rings are drawn
  in the system.
- **Line things up.** Everything sits on a few shared left edges. The same kind of block
  repeats the same inner layout (caption, title, meta line), so cards read alike. Labels
  sit next to their values and hints sit right under their control, never pushed to the
  far edge. Reading order is top-left to bottom-right: what it is, then its state, then
  what to do.

## 5. Colour is meaning, and never alone

Every coloured mark also carries a word, a number, an icon, a shape or a position. A
number nobody has judged gets no colour. Every chart has its table. Check the palette
under protanopia, deuteranopia and tritanopia simulation and report the contrast numbers,
not "looks fine".

## 6. Design every state, and write it

For each view, design and write: **loading** (skeleton rows the shape of the real ones,
plus a plain line saying what is happening — "Reading the traffic…"), **empty** (what
would be here and how to make it appear, in the same box: "No drafts yet. Start one and it
is kept here."; on first run, teach the object, e.g. a faint dashed sketch of what a
finished one looks like), **failed** (name the source, say nothing is lost if true, offer
retry — a placeholder never stays up after a failure), **working** (a busy button keeps
its words and says what it is doing — "Adding source…"), **too small** (if it can't work
on a phone, say so and where to go instead), and **disabled** (says why on hover and
focus).

**Words:**
- Plain, calm, second person, real nouns. No exclamation marks.
- No "No data found" or "Something went wrong".
- Names, not ids: the name first, then its kind and id small.
- Links named for what they do ("Create a consumer →"), not for where they go.
- One formatter for dates and numbers; tabular figures for counts.
- Honest placeholders for unnamed things ("Not described yet"), dimmed so they never pass
  for typed text.

Motion is for what is alive or just changed: a pulse on the running step, a one-time pulse
on what an action changed, a 4–12px rise on arrival. Honour `prefers-reduced-motion`.
Delight — a joke, a game layer — is welcome, but it is opt-out and never in the way.

## 7. Look at it, then write it down

- **Screenshot the real thing at 2×** (headless Chrome with `deviceScaleFactor` 2, or a
  browser tool), then open the images and look: the whole page, not only the part that
  changed, in dark and light, and at phone width. Put it beside its sibling pages — does it read as
  the same app? Is it the best-looking screen in the app? If not, it is not done.
- **Run the tells check** below and fix every hit.
- **Record each decision in the design doc**, dated and with its reason — and the reason
  when a decision reverses. That doc is what lets the next session get it right without
  being told. A new surface, type size or width needs a reason stronger than its own page;
  put it in the commit.

## Tells of generated UI — remove on sight

- gradient hero, glowing purple/indigo, gradient text
- default blue/indigo accent; cool blue-grey neutrals
- icon-in-a-circle feature grids; emoji as icons
- rows of equal coloured pills; coloured card borders; several solid buttons
- cards that lift or scale on hover
- "Welcome to your dashboard!", "Get started", "No data found"
- stat tiles nobody asked for
- placeholder text dark enough to pass for input
- a tooltip as the only explanation; controls that appear only on hover
- modals for everyday edits; `confirm()`
- one-off sizes and colours outside the tokens
