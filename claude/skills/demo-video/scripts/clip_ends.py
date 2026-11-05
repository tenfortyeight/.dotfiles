"""How each voice clip ends: does the pitch fall, as a closing line should, or stay flat or rise?

usage: clip_ends.py CLIP.wav [CLIP.wav ...]
Prints the pitch of the last voiced half second, in semitones, against the voice's median across
all the clips given (a short closing line can sit high as a whole), and a verdict. A closing line that doesn't fall by a couple of semitones sounds like it is
asking a question or has more to come. Run with a python that has numpy and soundfile.
"""
import sys

import numpy as np
import soundfile as sf

FRAME, HOP = 0.04, 0.01
LOW, HIGH = 60.0, 400.0  # speech F0 range in Hz


def pitch_track(audio, rate):
    """F0 per frame by autocorrelation; NaN where the frame is unvoiced or quiet."""
    n, hop = int(FRAME * rate), int(HOP * rate)
    loud = np.sqrt(np.mean(audio ** 2)) * 0.3
    lags = np.arange(int(rate / HIGH), int(rate / LOW))
    out = []
    for start in range(0, len(audio) - n, hop):
        f = audio[start:start + n] - np.mean(audio[start:start + n])
        if np.sqrt(np.mean(f ** 2)) < loud:
            out.append(np.nan)
            continue
        ac = np.correlate(f, f, "full")[n - 1:]
        best = lags[np.argmax(ac[lags])]
        out.append(rate / best if ac[best] > 0.45 * ac[0] else np.nan)
    return np.array(out)


def track(path):
    audio, rate = sf.read(path)
    return pitch_track(audio.mean(axis=1) if audio.ndim > 1 else audio, rate)


def tail_pitch(f0):
    """Median F0 of the last voiced half second, or None when there is too little voice."""
    voiced = np.where(~np.isnan(f0))[0]
    if len(voiced) < 20:
        return None
    return np.nanmedian(f0[voiced[voiced >= voiced[-1] - int(0.5 / HOP)]])


def main():
    tracks = {path: track(path) for path in sys.argv[1:]}
    median = np.nanmedian(np.concatenate(list(tracks.values())))
    for path, f0 in tracks.items():
        end = tail_pitch(f0)
        st = None if end is None else 12 * np.log2(end / median)
        if st is None:
            print(f"{path}: too little voice to tell")
            continue
        verdict = "falls" if st <= -2 else "flat" if st < 1 else "rises"
        print(f"{path}: ends {st:+.1f} semitones against the voice, {verdict}")


if __name__ == "__main__":
    main()
