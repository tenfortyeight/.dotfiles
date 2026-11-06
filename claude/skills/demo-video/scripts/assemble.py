"""Frames + voice clips -> final mp4 (H.264, AAC 48 kHz stereo) and optional .srt.

Inputs:  SCENES_JSON, REC_DIR (recorder.py's frames.txt and timeline.json),
         CLIPS_DIR (tts.py's wavs and lengths.json). Needs ffmpeg on the path.
Outputs: OUT_MP4, and OUT_MP4 with .srt if --srt is given.
Each clip is placed at its scene's start and normalised to -16 LUFS. Under it goes the scenes
file's "sound", chosen for the tone, never by habit:
  "none" (the default)   voice only
  "drone"                three low sines in an open chord: quiet tension
  a path to an audio file (relative to the scenes file): a music bed in the tone's mood, looped
usage: assemble.py SCENES_JSON REC_DIR CLIPS_DIR OUT_MP4 [--srt] [--pad-level 0.07]
--pad-level is the bed's volume factor; 0.07 sits the drone about 25 dB under the speech. A music
file's level differs: measure both and set it so the bed sits about 25 dB under.
"""
import argparse, json, re, subprocess
from pathlib import Path


def run(cmd):
    subprocess.run([str(c) for c in cmd], check=True, stdin=subprocess.DEVNULL)


def audio_graph(starts, total, pad_level, bed_inputs, first_input=1):
    """ffmpeg filter graph: delay each clip to its scene, mix, normalise, lay the bed under it.
    Inputs: the clips from `first_input` on, then `bed_inputs` sources for the bed (0 for none)."""
    n = len(starts)
    delayed = "".join(f"[{first_input + i}:a]adelay={int(s * 1000)}|{int(s * 1000)},aformat=sample_rates=48000:channel_layouts=stereo[v{i}];"
                      for i, s in enumerate(starts))
    mix = ("".join(f"[v{i}]" for i in range(n)) + f"amix=inputs={n}:normalize=0:duration=longest,"
           f"loudnorm=I=-16:TP=-1.5:LRA=11,apad=whole_dur={total:.2f}[voice];")  # pad out to the video's length
    if not bed_inputs:
        return delayed + mix + "[voice]anull[out]"
    beds = "".join(f"[{first_input + n + k}:a]" for k in range(bed_inputs))
    pad = (f"{beds}amix=inputs={bed_inputs}:normalize=0,lowpass=f=600,volume={pad_level},"
           "aformat=sample_rates=48000:channel_layouts=stereo[pad];")
    return delayed + mix + pad + "[voice][pad]amix=inputs=2:normalize=0:duration=first[out]"


def bed_inputs(sound, total, base):
    """ffmpeg inputs for the bed under the voice: none, the drone's three sines, or a looped file."""
    if sound in (None, "none"):
        return []
    if sound == "drone":
        return [x for f in (110, 165, 220) for x in ("-f", "lavfi", "-t", f"{total:.2f}", "-i", f"sine=f={f}:r=48000")]
    return ["-stream_loop", "-1", "-t", f"{total:.2f}", "-i", base / sound]


def srt_time(t):
    ms = round(t * 1000)
    return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"


def cues(text, start, length, max_chars=84):
    """Split on sentences (long ones at a comma), timed by share of characters."""
    parts = [p for s in re.split(r"(?<=[.?!])\s+", text) for p in
             (re.split(r"(?<=,)\s+", s) if len(s) > max_chars else [s])]
    total, t = sum(len(p) for p in parts), start
    for p in parts:
        d = length * len(p) / total
        yield t, t + d, p
        t += d


def write_srt(path, scenes, timeline, lengths):
    out = []
    for i, (sc, tl) in enumerate(zip(scenes, timeline)):
        out += list(cues(sc["say"], tl["start"], lengths[f"{i:02d}.wav"]))
    path.write_text("\n".join(f"{n}\n{srt_time(a)} --> {srt_time(b)}\n{txt}\n" for n, (a, b, txt) in enumerate(out, 1)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scenes"), ap.add_argument("rec"), ap.add_argument("clips"), ap.add_argument("out")
    ap.add_argument("--srt", action="store_true")
    ap.add_argument("--pad-level", type=float, default=0.07)
    a = ap.parse_args()
    rec, clips, out = Path(a.rec), Path(a.clips), Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    cfg = json.loads(Path(a.scenes).read_text())
    scenes = cfg["scenes"]
    tl = json.loads((rec / "timeline.json").read_text())
    lengths = json.loads((clips / "lengths.json").read_text())
    starts = [s["start"] for s in tl["scenes"]]
    total = tl["total"]

    inputs = [x for i in range(len(scenes)) for x in ("-i", clips / f"{i:02d}.wav")]
    pad_inputs = bed_inputs(cfg.get("sound"), total, Path(a.scenes).parent)
    video = out.with_suffix(".video.mp4")
    # -fps_mode vfr: without it ffmpeg assumes 25 fps for the concat input and drops frames, shortening the video.
    run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", rec / "frames.txt",
         "-fps_mode", "vfr", "-vf", "fps=30,scale=1920:1080:flags=lanczos,format=yuv420p", "-c:v", "libx264", "-crf", "18", "-preset", "medium", video])
    run(["ffmpeg", "-y", "-v", "error", "-i", video, *inputs, *pad_inputs,
         "-filter_complex", audio_graph(starts, total, a.pad_level, pad_inputs.count("-i")), "-map", "0:v", "-map", "[out]",
         "-c:v", "copy", "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "192k", "-movflags", "+faststart", "-shortest", out])
    video.unlink()
    if a.srt:
        write_srt(out.with_suffix(".srt"), scenes, tl["scenes"], lengths)
    print("wrote", out)


if __name__ == "__main__":
    main()
