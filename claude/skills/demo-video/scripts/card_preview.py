"""Preview the scenes file's cards without recording: each drawn on a blank page, shot at a few moments.

usage: card_preview.py SCENES_JSON OUT_PNG [--at 2 5 9] [--port 9336]
Writes one row per card, one column per moment, so a title that never appears or an
animation that starts too late shows up before the real take. Run with a python that has
`websockets`.
"""
import argparse, asyncio, base64, json, subprocess, sys, tempfile, urllib.request
from pathlib import Path

import websockets

sys.path.insert(0, str(Path(__file__).parent))
from recorder import CARD_MIN, card_js, card_style, load_card, serve  # noqa: E402

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def serve_blank(bg):
    """A blank page over http (a file:// page breaks CDP input), on a free port."""
    root = Path(tempfile.mkdtemp(prefix="card-"))
    (root / "index.html").write_text(f'<!doctype html><body style="margin:0;background:{bg}"></body>')
    return serve(root)


async def shoot(ws_url, url, cards, style, moments, out_dir):
    async with websockets.connect(ws_url, max_size=None) as ws:
        n = 0

        async def send(method, **params):
            nonlocal n
            n += 1
            await ws.send(json.dumps({"id": n, "method": method, "params": params}))
            while (msg := json.loads(await ws.recv())).get("id") != n:
                pass
            return msg.get("result", {})

        await send("Emulation.setDeviceMetricsOverride", width=1600, height=900, deviceScaleFactor=1, mobile=False)
        shots = []
        for name, card in cards:
            await send("Page.navigate", url=url)
            await asyncio.sleep(1)
            hold = max(moments) + 2
            await send("Runtime.evaluate", expression=card_js(card, style, max(hold, CARD_MIN)), awaitPromise=True)
            waited = 0.0
            for t in moments:
                await asyncio.sleep(t - waited)
                waited = t
                shot = out_dir / f"{name}-{t}.png"
                shot.write_bytes(base64.b64decode((await send("Page.captureScreenshot", format="png"))["data"]))
                shots.append(shot)
        return shots


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scenes"), ap.add_argument("out")
    ap.add_argument("--at", type=float, nargs="+", default=[2, 5, 9])
    ap.add_argument("--port", type=int, default=9336)
    a = ap.parse_args()
    cfg = json.loads(Path(a.scenes).read_text())
    base = Path(a.scenes).parent
    style = card_style(cfg, base)
    cards = [(sc["name"], load_card(sc["card"], base)) for sc in cfg["scenes"] if "card" in sc]
    out_dir = Path(tempfile.mkdtemp(prefix="cards-", dir=Path(a.out).parent))
    chrome = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={a.port}",
                               f"--user-data-dir={tempfile.mkdtemp(prefix='card-chrome-')}", "--remote-allow-origins=*",
                               "--hide-scrollbars", "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{a.port}/json/list"))
                break
            except OSError:
                asyncio.run(asyncio.sleep(0.2))
        ws_url = next(t["webSocketDebuggerUrl"] for t in tabs if t["type"] == "page")
        shots = asyncio.run(shoot(ws_url, serve_blank(style["bg"]), cards, style, sorted(a.at), out_dir))
    finally:
        chrome.terminate()
    cols, rows = len(a.at), len(cards)
    cells = "".join(f"[{i}]scale=640:-1,pad=iw+6:ih+6:3:3:yellow[c{i}];" for i in range(len(shots)))
    row = "".join("".join(f"[c{r * cols + c}]" for c in range(cols)) + (f"hstack={cols}" if cols > 1 else "null") + f"[r{r}];"
                  for r in range(rows))
    graph = cells + row + "".join(f"[r{r}]" for r in range(rows)) + (f"vstack={rows}" if rows > 1 else "null")
    inputs = sum((["-i", str(p)] for p in shots), [])
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex", graph, a.out], check=True)
    print(a.out)


if __name__ == "__main__":
    main()
