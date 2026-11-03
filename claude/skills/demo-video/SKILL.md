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
otherwise: a random English voice, 1.5–3 minutes, and a non-production environment when
the user leaves the choice open. If the user wants to pick the voice, give them samples to
listen to (see Voice) rather than a list of names.

Work in the session's scratch folder; everything — frames, clips, the venv — goes there.

**Subtitles** are optional, off unless asked. With them on, write an `.srt` from the
script and the clip timings, and give it alongside the mp4.

**Start from `scripts/` next to this file** — a tested pipeline from an earlier run:
`tts.py` (scenes → one voice clip per scene), `recorder.py` (headless Chrome over CDP,
with pointer, zoom camera, cards and a timeout) and `assemble.py` (frames and clips → the
mp4, optional subtitles); `scenes.example.json` shows the scene format they share. Use
and improve them rather than writing new ones, and put back whatever worked better, so
the next video starts further along.

## Before the script: can we get in?

Check these first, so a dead end shows up before anyone has approved a script:

- **Tools**: `ffmpeg`, `ffprobe`, `espeak-ng`, Python 3.12 and Chrome. Install what is
  missing (`brew install ffmpeg espeak-ng python@3.12`).
- **Sign-in**: get a token (see Picture), open the target URL in headless Chrome with it,
  and confirm a signed-in page loads — not a login form or a redirect to one. If the app
  signs in with a cookie or a browser login instead, say so in a line and find the route
  that works (a session cookie set with `Network.setCookie`, or a test account) before
  writing the script. Ask only if none does.

## 1. Script first, and wait

Write the script scene by scene and **show it to the user before recording anything.**
This is the one stop: recording is cheap to redo, but a script nobody wanted is not.

| # | On screen | Voice-over | ~s |
|---|---|---|---|

- **Scenes:** intro card · the whole thing · each part up close · how it is set up ·
  a real run played back · close · outro card.
- **Words:** about 150 a minute of voice-over, so 225–450 in total. One idea per scene.
  The voice tends to read faster than that, so time the clips before trusting the length;
  if it comes out short, add a scene rather than padding with pauses.
- **Voice:** say what the viewer is looking at and why it matters to them, in plain
  words. Not the UI's labels read aloud, not "Here we can see". British spelling for a
  British voice.
- **Intro** names the thing and the problem it solves in a line. **Outro** is a short
  line that sticks — "Every time." — with a subline under it.

## 2. Picture

- **Record the live app** in headless Chrome driven over CDP (`Page.startScreencast`),
  viewport 1600×900 at `deviceScaleFactor` 2, scaled to 1080p. Record the whole video
  as one continuous take and note each scene's start on the video clock; a scene runs
  for its voice clip plus a breath, or longer if its steps need it.
- **Never navigate to a `file://` page** — it breaks CDP mouse input for the rest of the
  recording. Serve local files over http.
- **Zoom** with a CSS transform on `<body>` and `overflow: hidden` on `<html>`, so the
  pointer and cards (on `<html>`) stay sharp and the page doesn't scroll sideways. After a
  route change, wait briefly before reading positions: the new view may not exist yet.
- **Sign in without a browser login.** Get a short-lived token from the app's own CLI
  or token endpoint and add it to requests per host with Fetch interception. Never
  print it, and revoke or delete it afterwards — also when the run fails. If there is
  no non-interactive way to get one, ask.
- **Frame the camera on where things actually are.** Read element positions from the
  page (`getBoundingClientRect`) and zoom to each part; on a canvas, pan by dragging
  with CDP mouse events. Wait for animations to settle before reading positions.
- **Show the pointer.** Headless Chrome draws no cursor, so clicks would happen
  invisibly. Inject a drawn pointer that follows the CDP mouse moves, glides between
  targets, and shows a small ripple on each click.
- **No personal data on screen.** Use demo data, and hide panels that show names,
  emails or free text from real people.

### Intro and outro cards

Draw the card as a **fixed overlay on top of the loaded app page** and remove it when
done — no navigation, so input keeps working and the app keeps its state. (Replacing the
page with `document.write` also works, but loses the app's state and flashes white on the
way back.) Wait for the card's font to load before showing it.

- Take the look from the app: its darkest surface as the background, its accent for
  the wordmark, its display font. If the app opens in its light theme, pass the dark
  values in explicitly. With no theme to take from, use a near-black background, one
  bright accent and Outfit from Google Fonts.
- A large headline with a sheen sweeping across it, a glowing line that draws across
  with dots popping in along it, and three tag pills naming what the feature does.
- The outro reuses the card with the closing line and subline.

## 3. Voice

- **Kokoro TTS** via `kokoro-onnx` in a Python 3.12 venv. Model files (`kokoro-v1.0.onnx`
  and `voices-v1.0.bin`, ~350 MB together) come from the kokoro-onnx GitHub release
  `model-files-v1.0`.
- **The voice** is `"voice"` in the scenes file, and `"speed"` (default 1.0) sets its
  pace. Unless the user named one, pick an English voice at random when writing the
  script, put it in the scenes file and name it above the script table, so the user can
  swap it and the spelling matches its accent. (With no `"voice"`, `tts.py` picks one at
  random itself and writes it back into the file.) A voice name's first letter is its
  accent or language and the second its gender: `bf_emma` is British female, `am_adam`
  American male. The English ones:
  - British female: `bf_emma`, `bf_alice`, `bf_isabella`, `bf_lily`
  - British male: `bm_george`, `bm_daniel`, `bm_fable`, `bm_lewis`
  - American female: `af_heart`, `af_bella`, `af_nicole`, `af_sarah`, `af_sky`, `af_nova`,
    `af_river`, `af_jessica`, `af_kore`, `af_aoede`, `af_alloy`
  - American male: `am_adam`, `am_michael`, `am_eric`, `am_liam`, `am_onyx`, `am_echo`,
    `am_fenrir`, `am_puck`, `am_santa`

  Spanish, French, Hindi, Italian, Japanese, Portuguese and Mandarin voices are in the
  file too; the script picks the language from the first letter. To choose by ear,
  `tts.py --sample MODEL_DIR OUT_DIR [voices…]` reads one line in each voice (every
  English one if none are named). Use American spelling for an American voice.
- On macOS use Homebrew's `espeak-ng` (`brew install espeak-ng`); the data path in the
  bundled espeakng-loader is broken there.
- **One clip per scene, generated before recording.** Measure each clip's length and
  hold its scene at least that long — the picture waits for the voice, never the other
  way round. Place each clip at its scene's start on the video clock.

## 4. Sound and assembly (ffmpeg)

- **Frames to video:** the screencast sends a frame only when something changes, so
  build an ffmpeg concat list with each frame's duration and read it with
  `-fps_mode vfr`. Without that, ffmpeg assumes 25 fps and the video quietly comes out
  seconds short.
- Normalise the voice to **-16 LUFS** (`loudnorm`). Put a quiet generated pad about
  25 dB under it — measure both, since the right volume factor depends on the pad's
  source level.
- **Pad the audio to the video's length** (`apad`), or the end of the outro is cut.
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
