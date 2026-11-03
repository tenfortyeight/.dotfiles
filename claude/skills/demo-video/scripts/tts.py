"""Voice-over: one wav per scene, plus each clip's length.

Inputs:  SCENES_JSON (each scene's "say", top-level "voice", default bf_emma) and
         MODEL_DIR holding kokoro-v1.0.onnx and voices-v1.0.bin.
Outputs: OUT_DIR/00.wav, 01.wav, ... and OUT_DIR/lengths.json ({"00.wav": seconds}).

usage: tts.py SCENES_JSON OUT_DIR MODEL_DIR
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


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    scenes_file, out_dir, model_dir = map(Path, sys.argv[1:4])
    model, voices = model_dir / "kokoro-v1.0.onnx", model_dir / "voices-v1.0.bin"
    for f in (model, voices):
        if not f.exists():
            sys.exit(f"missing {f}\nDownload it: {MODEL_URL}{f.name}")

    cfg = json.loads(scenes_file.read_text())
    out_dir.mkdir(parents=True, exist_ok=True)

    # The espeak data bundled with espeakng-loader is broken on macOS; use Homebrew's.
    if Path(BREW_ESPEAK).exists():
        os.environ.setdefault("ESPEAK_DATA_PATH", BREW_ESPEAK)

    kokoro = Kokoro(str(model), str(voices))
    lengths = {}
    for i, scene in enumerate(cfg["scenes"]):
        samples, rate = kokoro.create(scene["say"], voice=cfg.get("voice", DEFAULT_VOICE), speed=1.0, lang="en-gb")
        path = out_dir / f"{i:02d}.wav"
        sf.write(path, samples, rate)
        lengths[path.name] = len(samples) / rate
        print(path.name, f"{lengths[path.name]:.2f}s", scene["name"])
    (out_dir / "lengths.json").write_text(json.dumps(lengths, indent=1))


if __name__ == "__main__":
    main()
