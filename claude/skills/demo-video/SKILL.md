---
name: demo-video
description: >
  Use when the user asks for a demo video, walkthrough or screencast of a feature
  or flow in a web app, or types /demo-video. Records the real app live in
  headless Chrome, adds an animated intro and outro and a voice-over, and hands
  back an mp4. The script is written first and approved before anything is
  recorded.
user-invocable: true
---

<!-- Adapted from a prompt by Mikael Ahlinder (https://github.com/mikaelahlinder). -->

# /demo-video — a short narrated demo of the real app

A 1.5–3 minute video that shows one feature or flow working in the real app, with an
animated intro and outro and a calm voice-over. A good demo comes down to three things:
an intro that says what this is, a voice that explains what you are looking at, and an
outro that leaves one line behind. Everything else serves those.

## Inputs

You need the **feature or flow**, the **app**, the **environment** and its **URL**. Ask
for whatever is missing in one question, then carry on. Defaults unless the user says
otherwise: British female voice, 1.5–3 minutes, and a non-production environment when the
user leaves the choice open.

Work in the session's scratch folder; everything — frames, clips, the venv — goes there.

## 1. Script first, and wait

Write the script scene by scene and **show it to the user before recording anything.**
This is the one stop: recording is cheap to redo, but a script nobody wanted is not.

| # | On screen | Voice-over | ~s |
|---|---|---|---|

- **Scenes:** intro card · the whole thing · each part up close · how it is set up ·
  a real run played back · close · outro card.
- **Words:** about 150 a minute of voice-over, so 225–450 in total. One idea per scene.
- **Voice:** say what the viewer is looking at and why it matters to them, in plain
  words. Not the UI's labels read aloud, not "Here we can see". British spelling for a
  British voice.
- **Intro** names the thing and the problem it solves in a line. **Outro** is a short
  line that sticks — "Every time." — with a subline under it.

## 2. Picture

- **Record the live app** in headless Chrome driven over CDP (`Page.startScreencast`),
  viewport 1600×900 at `deviceScaleFactor` 2, scaled to 1080p.
- **Sign in without a browser login.** Get a short-lived token from the app's own CLI
  or token endpoint and add it to requests per host with Fetch interception. Never
  print it, and revoke or delete it afterwards — also when the run fails. If there is
  no non-interactive way to get one, ask.
- **Frame the camera on where things actually are.** Read element positions from the
  page (`getBoundingClientRect`) and zoom to each part; on a canvas, pan by dragging
  with CDP mouse events. Wait for animations to settle before reading positions.
- **No personal data on screen.** Use demo data, and hide panels that show names,
  emails or free text from real people.

### Intro and outro cards

Load the app's page first, then draw the card **inside it with `document.write`** —
navigating to a `file://` page breaks CDP mouse input for the rest of the recording.

- Take the look from the app: its darkest surface as the background, its accent for
  the wordmark, its display font. With no theme to take from, use a near-black
  background, one bright accent and Outfit from Google Fonts.
- A large headline with a sheen sweeping across it, a glowing line that draws across
  with dots popping in along it, and three tag pills naming what the feature does.
- The outro reuses the card with the closing line and subline.

## 3. Voice

- **Kokoro TTS** via `kokoro-onnx` in a Python 3.12 venv; voice `bf_emma` for British
  female. Model files come from the kokoro-onnx GitHub release.
- On macOS use Homebrew's `espeak-ng` (`brew install espeak-ng`); the data path in the
  bundled espeakng-loader is broken there.
- **One clip per scene, and time each scene to its clip.** Generate the voice before
  recording, measure each clip's length, and hold each scene that long plus a short
  breath — the picture waits for the voice, never the other way round.

## 4. Sound and assembly (ffmpeg)

- Normalise the voice to **-16 LUFS** (`loudnorm`). Put a quiet generated pad about
  25 dB under it (volume ~0.12).
- Output **H.264 + AAC, 48 kHz stereo**. A 24 kHz mono track once played silent in
  QuickTime.

## 5. Check before handing over

- `ffprobe` the file: an audio stream is there, AAC, 48 kHz, 2 channels.
- It is audible: measure the mean volume (`volumedetect`). Around -91 dB is silence;
  a normalised voice track should be far above that.
- Pull a frame from the middle of every scene and look at it: framed on the right
  thing, no personal data, no stray dialogs or cursors.

Then give the user the path to the final mp4, its length, and one line on anything
that came out differently from the script.
