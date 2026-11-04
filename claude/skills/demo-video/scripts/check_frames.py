"""One frame from the middle of every scene of the finished mp4, tiled into one sheet to look at.

usage: check_frames.py MP4 TIMELINE_JSON OUT_PNG [--cols 4]
"""
import argparse, json, subprocess, tempfile
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mp4"), ap.add_argument("timeline"), ap.add_argument("out")
    ap.add_argument("--cols", type=int, default=4)
    a = ap.parse_args()
    scenes = json.loads(Path(a.timeline).read_text())["scenes"]
    tmp = Path(tempfile.mkdtemp(prefix="frames-", dir=Path(a.out).parent))
    shots = []
    for i, s in enumerate(scenes):
        shot = tmp / f"{i:02d}.png"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{(s['start'] + s['end']) / 2:.2f}", "-i", a.mp4,
                        "-frames:v", "1", "-vf", "scale=800:-1", str(shot)], check=True)
        shots.append(shot)
    while len(shots) % a.cols:
        shots.append(shots[-1])
    rows = len(shots) // a.cols
    cells = "".join(f"[{i}]pad=iw+6:ih+6:3:3:yellow[c{i}];" for i in range(len(shots)))
    row = "".join("".join(f"[c{r * a.cols + c}]" for c in range(a.cols)) + f"hstack={a.cols}[r{r}];" for r in range(rows))
    graph = cells + row + "".join(f"[r{r}]" for r in range(rows)) + (f"vstack={rows}" if rows > 1 else "null")
    inputs = sum((["-i", str(p)] for p in shots), [])
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex", graph, a.out], check=True)
    print(a.out)


if __name__ == "__main__":
    main()
