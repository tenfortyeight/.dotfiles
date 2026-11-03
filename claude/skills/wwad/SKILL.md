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

## How much of this to use

| The change | Steps |
|---|---|
| A tweak inside an existing page | 0, then 7 — and the tells list |
| A new page, view or component | 0, 1, 2, 5, 6, 7 |
| A new app, or one with no design system | all of it, starting with 3 |

## 0. Read what is already decided

Before touching UI, find the repo's design doc (`docs/design*.md`, `docs/ui.md`, a design
section in the README or CLAUDE.md), its tokens file, its shared components and its guide
page. Build only from those; the repo's own rules beat this skill wherever they differ. A
piece that is missing is added to the kit and the guide page first, then used.

## 1. Every screen answers three questions

Write these down before any code — one sentence each:

1. **Where am I?** The rail or crumb shows it; the heading names the thing in the user's
   own nouns. The browser tab title comes from the heading.
2. **What is this?** One sentence under the heading. Anything longer goes in a fold
   ("More about this").
3. **What do I do next?** One primary action, or one status line that names the next step
   ("2 to fix, 1 to weigh"). If nothing needs doing, say so: "Nothing needs you."

If you cannot write the three sentences, the screen is not understood yet. Write your best
guess, say it in a line, and carry on; ask only if the answer is a business decision.

## 2. Find the picture

Ask what the user holds in their head when they think about this thing. If the data has a
shape — things that flow, depend, own, call each other, change over time — draw that shape:
a canvas of steps and wires, a star with the main thing at the centre, a map where nearness
means "talks to", a timeline with notches. If it is a list, it is a list; a diagram that
says nothing the list doesn't gets deleted.

Then give each visual channel **one meaning**, and write the key:

| Channel | Spend it on | Example |
|---|---|---|
| Size | the one number that matters most (log scale, capped) | traffic, spend |
| Position / nearness | relationship or flow direction | callers sit close; inputs left, result right |
| Colour | category or owner, never decoration | one hue per kind or team |
| Red | failure only | failing node, error tint |
| Line style | solid = real, dashed = not there yet / optional | a dashed "not joined" card |
| Motion | only what is live right now | dots travelling along a busy wire |

Show the key on screen in plain words ("Size: traffic · Red: failing"). Make the main thing
the one hero: bigger, stronger, centred; everything else steps back. Detail comes with zoom
or hover: overview zoomed out, labels zoomed in, neighbours lit and the rest dimmed on
hover. Compute the layout before the first paint and fit the view to what matters, so it
opens settled.

**Worked example.** A backend has a table of services: `name, owner_team, calls[],
req_per_s, failing, deploying`. The list finds one service; the picture answers "what does
the system look like right now":

- service → a dot; `req_per_s` → dot size, and how many dots travel each wire.
- `calls[]` → curved wires, callers pulled close by a force layout.
- `owner_team` → a faint labelled ring around each team's dots, one colour per team.
- `failing` → red, with the reason in the hover card; `deploying` → a dashed ring.
- Key along the bottom; live totals along the top ("72 services · 158 req/s · 0 errors").
- Hover lights a dot and its neighbours and lists "Called by" and "Calls"; click opens the
  service's own page.

Same data, same backend; the only new work is choosing what each column becomes.

## 3. Choose the look — propose, then ask

A new app's look is taste, so it is the user's call — but never ask an open question.
**Propose two or three themes**, recommended first, and show them as one rendered swatch
page (screenshot it). Each theme gives:

- a name and its mood in a line ("ink and mint: calm, technical");
- background, surface steps, text, accent, and the ok / busy / failure colours, as hex;
- a display face and a body face — a display face with character (Outfit, Bricolage
  Grotesque, Space Grotesk, Fraunces, Instrument Serif), a quiet body face (Manrope,
  system UI), never the same generic sans for both;
- the measured numbers: text-on-background contrast, and whether the colours that must
  stay apart (accent, ok, failure, the category colours) still do under protanopia,
  deuteranopia and tritanopia. Simulate with the Machado (2009) matrices — a few lines of
  code — and report the ΔE between each pair; below about 10, pair the colour with an icon
  or label and say so.

Build the tokens from the chosen theme. Work in OKLCH: neutrals take the accent's hue at
very low chroma (a warm or brand-tinted grey, never plain blue-grey); semantic colours
share one lightness so none shouts; soft tints are the colour at 10–15% alpha.

## 4. A small closed system

One tokens file is the contract: no literal colours, sizes or durations in a component.

- **Surfaces as steps** — `bg`, `raised`, `overlay`, `hover`, a hairline `line`, and `fg` /
  `muted` / `faint`. Depth from fills, at most a hairline; a shadow only for what floats.
- **One accent, rationed to "act here"** — the primary button, the selection, links, focus.
  Mostly a soft tint; solid only on the one button.
- **Semantic colours for meaning only**, each with a text-safe "ink" for use on its tint.
- **Type**: display face for headings, body face, mono for ids and code. A short named
  scale: caption ~11px tracked caps, body ~14, titles ~15–24, one hero size.
- **Spacing** 4/8/12/16/24/32/48, with one named gap between blocks. **One corner radius**
  for cards, a smaller one for small things, pills for chips. One content width per page
  kind: a reading column ~720px, a work page ~1100–1240.
- **Motion** 120 / 220 / 480 ms, eased out (`cubic-bezier(.2,.8,.2,1)`).
- **Dark and light are a token swap**, with the contrast ratios written next to the tokens.

**The guide page holds it together.** A route in the app (`/design` or similar) shows every
piece in every state — empty, loading, failed, busy, disabled — in dark, light and phone
width. Pages are built only from what it shows. Where the stack allows, a check fails the
build when a page uses a styled class the guide page doesn't show; that check is what keeps
the app one app after many sessions.

## 5. Quiet by default

- **One loud thing per screen.** At most one solid button; most screens have none.
- **Hierarchy over badges.** A row leads with its name; kind and state are quiet text or one
  tag, not a row of equal coloured pills. Rows read: what it is, state, detail, dates,
  actions.
- **The expected state says nothing.** "On" needs no badge; "Off" does.
- **Colour never works alone.** Every coloured mark also has a word, number, icon, shape or
  position. A number nobody has judged gets no colour. Every chart has its table.
- **Hover changes colour, never position.** A ring or glow; nothing lifts or scales.
- **Edit the thing where it is.** Side panels beside the content, not modals over it; the
  app's own dialog for destructive actions, never `confirm()`. Selects, tooltips and focus
  rings are drawn in the system, not left to the browser.
- **Line things up.** A few shared left edges. The same kind of block repeats the same inner
  layout (caption, title, meta line). Labels sit next to their values and hints right under
  their control, never pushed to the far edge.

## 6. Design every state, and write it

- **Loading**: skeleton rows the shape of the real ones, and a plain line saying what is
  happening ("Reading the traffic…").
- **Empty**: what would be here and how to make it appear, in the same box ("No drafts yet.
  Start one and it is kept here."). On first run, teach the object, e.g. a faint dashed
  sketch of a finished one.
- **Failed**: name the source, say nothing is lost if true, offer retry. A placeholder never
  stays up after a failure.
- **Working**: a busy button keeps its words and says what it is doing ("Adding source…").
- **Disabled**: says why, on hover and focus. **Too small**: says so, and where to go
  instead.

**Words**: plain, calm, second person, the user's real nouns, no exclamation marks, never
"No data found" or "Something went wrong". Names, not ids — the name first, its kind and id
small. Links named for what they do ("Create a consumer →"). One formatter for dates and
numbers, tabular figures for counts. Honest placeholders for unnamed things ("Not described
yet"), dimmed so they never pass for typed text.

**Motion** is for what is alive or just changed: a pulse on the running step, one pulse on
what an action changed, a few pixels of rise on arrival. Honour `prefers-reduced-motion`.
Delight — a joke, a game layer — is welcome, but opt-out and never in the way.

## 7. Look at it, then write it down

- **Screenshot the real thing at 2×** (headless Chrome with `deviceScaleFactor` 2, or a
  browser tool) and open the images: the whole page, not only what changed, in dark and
  light and at phone width, beside a sibling page. Does it read as the same app? Is it the
  best-looking screen in the app? If not, it is not done.
- **Run the tells list** below and fix every hit.
- **Record each decision in the design doc**, dated and with its reason — including why,
  when one reverses. That doc is what lets the next session get it right without being
  told. A new surface, type size or width needs a reason stronger than its own page.

## Tells of generated UI — remove on sight

- gradient hero, glowing purple/indigo, gradient text
- default blue/indigo accent; cool blue-grey neutrals; Inter for everything
- icon-in-a-circle feature grids; emoji as icons
- rows of equal coloured pills; coloured card borders; several solid buttons
- cards that lift or scale on hover
- "Welcome to your dashboard!", "Get started", "No data found"
- stat tiles nobody asked for
- placeholder text dark enough to pass for input
- a tooltip as the only explanation; controls that appear only on hover
- modals for everyday edits; `confirm()`
- one-off sizes and colours outside the tokens
