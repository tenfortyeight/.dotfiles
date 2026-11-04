"""Contact sheet of a recording: one frame per scene, at `at` (0..1) through it, tiled left to right.

usage: contact.py REC_DIR OUT_PNG [--at 0.9] [--cols 4]
"""
import argparse, json, re, subprocess
from pathlib import Path


def frame_times(rec):
    """(start time, frame file) for every frame, from the concat list's durations."""
    t, out = 0.0, []
    for name, dur in re.findall(r"file '([^']+)'\nduration ([\d.]+)", (rec / "frames.txt").read_text()):
        out.append((t, name))
        t += float(dur)
    return out


def frame_at(frames, t):
    return [name for start, name in frames if start <= t][-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rec"), ap.add_argument("out")
    ap.add_argument("--at", type=float, default=0.9), ap.add_argument("--cols", type=int, default=4)
    a = ap.parse_args()
    rec = Path(a.rec)
    frames = frame_times(rec)
    scenes = json.loads((rec / "timeline.json").read_text())["scenes"]
    picks = [rec / frame_at(frames, s["start"] + a.at * (s["end"] - s["start"])) for s in scenes]
    while len(picks) % a.cols:
        picks.append(picks[-1])
    inputs = sum((["-i", str(p)] for p in picks), [])
    rows = len(picks) // a.cols
    cells = "".join(f"[{i}]scale=800:-1,pad=iw+8:ih+8:4:4:yellow[c{i}];"
                    for i in range(len(picks)))
    row = "".join(f"{''.join(f'[c{r * a.cols + c}]' for c in range(a.cols))}hstack={a.cols}[r{r}];" for r in range(rows))
    graph = cells + row + "".join(f"[r{r}]" for r in range(rows)) + (f"vstack={rows}" if rows > 1 else "null")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex", graph, a.out], check=True)
    print(a.out)


if __name__ == "__main__":
    main()
