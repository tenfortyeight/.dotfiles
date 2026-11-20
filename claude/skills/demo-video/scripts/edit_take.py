"""Edit a recording without re-recording it: frames.txt and timeline.json from recorder.py, rewritten.

usage: edit_take.py SRC_REC OUT_REC OPS_JSON
OPS_JSON is a list, all times on SRC's played clock:
  {"replace": [t0, t1], "with": t}   frames starting in [t0, t1) show the frame at t instead (no timing change)
  {"hold": t, "extra": s}            the frame showing at t stays s seconds longer; what follows moves later
  {"cut": [t0, t1]}                  drop [t0, t1); what follows moves earlier
  {"truncate": t}                    end the recording at t; scenes after it are dropped
Scene starts and ends move with the picture, so assemble.py places each voice clip where its scene now is.
"""
import json, re, sys
from pathlib import Path


def load(rec):
    lines = (rec / "frames.txt").read_text().split("\n")
    frames, t = [], 0.0
    for i in range(0, len(lines) - 1, 2):
        m, d = re.match(r"file '(.*)'", lines[i]), re.match(r"duration (.*)", lines[i + 1])
        if not (m and d):
            break
        frames.append([t, float(d.group(1)), m.group(1)])
        t += frames[-1][1]
    return frames, json.loads((rec / "timeline.json").read_text())


def at(frames, t):
    return next((f for f in frames if f[0] <= t < f[0] + f[1]), frames[-1])


def shift(timeline, t, by):
    for s in timeline["scenes"]:
        for k in ("start", "end"):
            if s[k] >= t:
                s[k] = max(t + min(by, 0), s[k] + by)  # a cut pulls what starts at its end back to its start
    timeline["total"] += by


def apply(frames, timeline, op):
    if "replace" in op:
        t0, t1 = op["replace"]
        src = at(frames, op["with"])[2]
        for f in frames:
            if t0 <= f[0] < t1:
                f[2] = src
    elif "hold" in op:
        # The extra time goes in at the hold point: a still frame can outlast the scene it starts in.
        at(frames, op["hold"])[1] += op["extra"]
        shift(timeline, op["hold"], op["extra"])
    elif "cut" in op:
        t0, t1 = op["cut"]
        for f in frames:  # trim each frame's overlap with the cut
            a, b = max(f[0], t0), min(f[0] + f[1], t1)
            if b > a:
                f[1] -= b - a
        shift(timeline, t1, -(t1 - t0))
    elif "truncate" in op:
        t = op["truncate"]
        for f in frames:
            if f[0] + f[1] > t:
                f[1] = max(0.0, t - f[0])
        timeline["scenes"] = [s for s in timeline["scenes"] if s["start"] < t]
        for s in timeline["scenes"]:
            s["end"] = min(s["end"], t)
        timeline["total"] = t


def main(src, out, ops):
    frames, timeline = load(src)
    # Later edits first, so every op's times still refer to SRC's clock.
    for op in sorted(ops, key=lambda o: -(o.get("hold") or (o.get("replace") or o.get("cut") or [o.get("truncate", 0)])[0])):
        apply(frames, timeline, op)
    out.mkdir(parents=True, exist_ok=True)
    if not (out / "frames").exists():
        (out / "frames").symlink_to((src / "frames").resolve())
    kept = [f for f in frames if f[1] > 0.0005]
    body = "".join(f"file '{f[2]}'\nduration {f[1]:.4f}\n" for f in kept) + f"file '{kept[-1][2]}'\n"
    (out / "frames.txt").write_text(body)
    (out / "timeline.json").write_text(json.dumps(timeline, indent=1))
    print(f"{len(kept)} frames, {timeline['total']:.1f}s;", ", ".join(f"{s['name']} {s['start']:.1f}" for s in timeline["scenes"]))


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))
