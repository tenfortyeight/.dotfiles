"""Voice-over: one wav per scene, plus each clip's length.

Inputs:  SCENES_JSON (each scene's "say"; top-level "voice", default bf_emma, and
         "speed", default 1.0) and MODEL_DIR holding kokoro-v1.0.onnx and voices-v1.0.bin.
Outputs: OUT_DIR/00.wav, 01.wav, ... and OUT_DIR/lengths.json ({"00.wav": seconds}).

usage: tts.py SCENES_JSON OUT_DIR MODEL_DIR
       tts.py --sample MODEL_DIR OUT_DIR [VOICE ...]   one line per voice, to choose by ear;
                                                       no voices = every English one
Run with a python that has kokoro-onnx and soundfile. On macOS, Homebrew's espeak-ng
is used if present; set ESPEAK_DATA_PATH to override.
"""
import json, os, sys
from pathlib import Path

import soundfile as sf
from kokoro_onnx import Kokoro

MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
DEFAULT_VOICE = "bf_emma"
BREW_ESPEAK = "/opt/homebrew/opt/espeak-ng/share/espeak-ng-data"
SAMPLE_LINE = "Every job, every run, in one place. Here is what failed overnight, and what to do about it."

# A voice name's first letter is its language: af_heart is American, bm_george British.
LANG_BY_PREFIX = {"a": "en-us", "b": "en-gb", "e": "es", "f": "fr-fr", "h": "hi",
                  "i": "it", "j": "ja", "p": "pt-br", "z": "cmn"}


def lang_for(voice):
    lang = LANG_BY_PREFIX.get(voice[:1])
    if not lang:
        sys.exit(f"unknown voice {voice!r}: the first letter names its language ({', '.join(LANG_BY_PREFIX)})")
    return lang


def load(model_dir):
    model, voices = model_dir / "kokoro-v1.0.onnx", model_dir / "voices-v1.0.bin"
    for f in (model, voices):
        if not f.exists():
            sys.exit(f"missing {f}\nDownload it: {MODEL_URL}{f.name}")
    # The espeak data bundled with espeakng-loader is broken on macOS; use Homebrew's.
    if Path(BREW_ESPEAK).exists():
        os.environ.setdefault("ESPEAK_DATA_PATH", BREW_ESPEAK)
    return Kokoro(str(model), str(voices))


def say(kokoro, text, voice, speed, path):
    if voice not in kokoro.get_voices():
        sys.exit(f"no voice {voice!r}; run with --sample to hear the choices")
    samples, rate = kokoro.create(text, voice=voice, speed=speed, lang=lang_for(voice))
    sf.write(path, samples, rate)
    return len(samples) / rate


def scenes(scenes_file, out_dir, model_dir):
    cfg = json.loads(scenes_file.read_text())
    voice, speed = cfg.get("voice", DEFAULT_VOICE), cfg.get("speed", 1.0)
    out_dir.mkdir(parents=True, exist_ok=True)
    kokoro = load(model_dir)
    lengths = {}
    for i, scene in enumerate(cfg["scenes"]):
        path = out_dir / f"{i:02d}.wav"
        lengths[path.name] = say(kokoro, scene["say"], voice, speed, path)
        print(path.name, f"{lengths[path.name]:.2f}s", scene["name"])
    (out_dir / "lengths.json").write_text(json.dumps(lengths, indent=1))


def sample(model_dir, out_dir, voices):
    out_dir.mkdir(parents=True, exist_ok=True)
    kokoro = load(model_dir)
    for voice in voices or [v for v in kokoro.get_voices() if v[0] in "ab"]:
        say(kokoro, SAMPLE_LINE, voice, 1.0, out_dir / f"{voice}.wav")
        print(out_dir / f"{voice}.wav")


def main():
    args = sys.argv[1:]
    if args[:1] == ["--sample"] and len(args) >= 3:
        sample(Path(args[1]), Path(args[2]), args[3:])
    elif len(args) == 3:
        scenes(*map(Path, args))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
