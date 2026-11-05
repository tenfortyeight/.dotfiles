"""Record a scripted demo of a live web app in headless Chrome over CDP.

Inputs:  SCENES_JSON (see scenes.example.json), LENGTHS_JSON (tts.py's lengths.json), URL.
Outputs: OUT_DIR/frames/*.jpg, OUT_DIR/frames.txt (ffmpeg concat list) and
         OUT_DIR/timeline.json (each scene's start/end in seconds on the video clock).

usage: recorder.py SCENES_JSON LENGTHS_JSON OUT_DIR URL [--chrome PATH] [--port N]
                   [--width 1600 --height 900] [--accent #hex --bg #hex --font "Name"]
                   [--timeout 600] [--step-timeout 30] [--auth-host HOST ...]
                   [--cookies-from PORT --cookie-domain SUBSTR ...] [--probe]
Run with a python that has `websockets`.

The scenes file may set "inject" (a JS file, beside it, run on every page load: hiding the person's
name, helpers for steps) and "first_load" (seconds to wait after the first navigation, default 2.5).

A scene is {"name", "say", "card"?, "steps"?}.
  - a card may instead be {"html", "css"?}: a whole custom card the tone calls for (a film-reel
    countdown, a trailer title, an infomercial starburst), drawn and timed like the built-in one.
  - "card": {"headline", "tags"?, "subline"?, "code"?} draws a card over the page (no navigation).
    "tags" (up to three words) sit on one centred line under the headline, not in pills.
    "code": true sets the subline in monospace, so a command's "--" is not drawn as a dash.
    Colours and font come from the scenes file's "style" {accent, bg, font}; the flags override it.
  - "steps" run at scene start, one after another. Each is one of:
      {"zoom": selector|null, "pad": px}   camera onto an element (null = whole page)
      {"move": selector}                   glide the pointer there
      {"click": selector}                  glide, then click with a ripple
      {"type": {"text": "..."}}            type into the focused field (insertText: React sees it, å ä ö work)
      {"key": "Escape", "vk": 27}          press a key; "modifiers" 1 Alt 2 Ctrl 4 Meta 8 Shift
      {"go": "/path?q=1", "settle": 1.5}   in-app navigation for a single-page app (pushState + popstate)
      {"until": "js", "settle": s}         hold until a JS condition is true; "timeout" per step
      {"ff": seconds, "to": 1}             wait, played back in `to` s (or "factor": n); keep clear of voice
      {"eval": "js"}                       run JS in the page (a hash change is followed by a short wait)
      {"wait": seconds}
A scene holds for its voice clip + "breath" (cards at least CARD_MIN seconds),
or until its steps finish if that is longer: the picture waits for the voice.

Timeouts: --timeout caps the whole recording, --step-timeout each step (plus its own wait).
Either one stops with a message naming what was running.

Auth: an app behind a login can be recorded with a bearer token. Put the token in the
DEMO_AUTH_TOKEN environment variable and name the hosts it may be sent to with --auth-host
(repeatable). It is added as "Authorization: Bearer ..." to requests to those hosts only,
via CDP Fetch interception. It is never printed or written to disk.

Or, for an app with only a browser login: start a visible Chrome with its own --user-data-dir and
--remote-debugging-port, let the person sign in there, and pass --cookies-from PORT: its cookies for
the --cookie-domain substrings are copied into the headless one. Record headless, never in that
window: Chrome pauses animation frames in a window it thinks is hidden, and layouts that wait on
them (React Flow and the like) never settle.

--probe is a trial run: a failed step is reported and the run goes on, so one pass lists every miss.
Run it with every clip length set to 1 and look at contact.py's sheet before the real take.
"""
import argparse, asyncio, base64, json, os, subprocess, sys, tempfile, time, urllib.request
from urllib.parse import urlparse
from pathlib import Path

import websockets

CARD_MIN = 5.0
ZOOM_SECONDS = 0.9
GLIDE_SECONDS = 0.7
SHORT_WAIT = 0.3
SILENT_HOLD = 6.0  # a few quiet seconds are fine; past this a hold starts to feel uneasy, so warn  # after a hash change, so the new view renders before the next step

POINTER_JS = """
(() => {
  if (window.__pointer) return;
  const el = document.createElement('div');
  el.style.cssText = 'position:fixed;left:0;top:0;z-index:2147483000;pointer-events:none;' +
    'transition:transform ' + %(glide)s + 's cubic-bezier(.45,.05,.25,1);transform:translate(800px,450px)';
  el.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24" style="filter:drop-shadow(0 2px 3px rgba(0,0,0,.5))">' +
    '<path d="M3 2l7 19 2.5-8L21 10.5z" fill="#fff" stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  document.documentElement.appendChild(el);
  const style = document.createElement('style');
  style.textContent = '@keyframes __ripple{from{transform:translate(-50%%,-50%%) scale(.2);opacity:.9}' +
    'to{transform:translate(-50%%,-50%%) scale(1.6);opacity:0}}';
  document.documentElement.appendChild(style);
  window.__pointer = {
    to(x, y) { el.style.transform = `translate(${x}px,${y}px)`; },
    ripple(x, y) {
      const r = document.createElement('div');
      r.style.cssText = `position:fixed;left:${x}px;top:${y}px;width:46px;height:46px;border-radius:50%%;` +
        'border:3px solid #fff;box-shadow:0 0 0 2px rgba(0,0,0,.35);pointer-events:none;' +
        'z-index:2147483000;animation:__ripple .5s ease-out forwards';
      document.documentElement.appendChild(r);
      setTimeout(() => r.remove(), 600);
    },
  };
  // The camera: zooming the body keeps the pointer and cards (on <html>) unscaled.
  // No scrolling: a zoomed body would otherwise grow scrollable overflow and the page drifts sideways.
  document.documentElement.style.overflow = 'hidden';
  document.documentElement.style.background = getComputedStyle(document.body).backgroundColor;
  document.body.style.transformOrigin = '0 0';
  document.body.style.transition = 'transform %(zoom)ss cubic-bezier(.45,.05,.25,1)';
})();
""" % {"glide": GLIDE_SECONDS, "zoom": ZOOM_SECONDS}

CARD_CSS = """
.__card{position:fixed;inset:0;z-index:2147483600;display:flex;flex-direction:column;align-items:center;
  justify-content:center;gap:34px;background:%(bg)s;color:#fff;font-family:%(font)s,system-ui,sans-serif;
  animation:__in .5s ease-out both, __out .5s ease-in %(out_at)ss forwards}
@keyframes __in{from{opacity:0}} @keyframes __out{to{opacity:0}}
.__card h1{margin:0;text-align:center;font-weight:700;font-size:112px;letter-spacing:-.03em;line-height:1.05;
  background:linear-gradient(100deg,%(accent)s 0%%,%(accent)s 38%%,#fff 50%%,%(accent)s 62%%,%(accent)s 100%%);
  background-size:300%% 100%%;-webkit-background-clip:text;background-clip:text;color:transparent;
  animation:__sheen 2.6s ease-in-out .5s both}
@keyframes __sheen{from{background-position:100%% 0}to{background-position:0%% 0}}
.__card .line{position:relative;width:640px;height:3px;border-radius:2px;background:%(accent)s;
  box-shadow:0 0 18px %(accent)s;transform-origin:left;animation:__draw 1.2s ease-out .4s both}
@keyframes __draw{from{transform:scaleX(0)}}
.__card .line i{position:absolute;top:-4px;width:11px;height:11px;border-radius:50%%;background:#fff;
  box-shadow:0 0 12px %(accent)s;animation:__pop .4s ease-out both}
@keyframes __pop{from{transform:scale(0)}}
.__card .tags{display:flex;align-items:center;justify-content:center;gap:26px;font-size:24px;
  letter-spacing:.34em;text-transform:uppercase;color:%(accent)s}
.__card .tags span{margin-right:-.34em;animation:__up .6s ease-out both}  /* letter-spacing trails the last letter */
.__card .tags b{width:6px;height:6px;border-radius:50%%;background:currentColor;opacity:.6}
@keyframes __up{from{opacity:0;transform:translateY(14px)}}
.__card .sub{font-size:30px;opacity:.75;animation:__up .6s ease-out 1.3s both}
.__card .sub.code{font-family:'SF Mono',ui-monospace,Menlo,monospace;font-size:26px}
%(css)s
"""


def card_js(card, style, hold):
    """JS that draws the card as an overlay on the loaded app page."""
    dots = "".join(f'<i style="left:{p}%;animation-delay:{0.5 + p / 100 * 1.1:.2f}s"></i>' for p in (0, 33, 66, 100))
    tags = "<b></b>".join(f'<span style="animation-delay:{0.9 + n * 0.15:.2f}s">{t}</span>' for n, t in enumerate(card.get("tags", [])))
    sub = (f'<div class="sub{" code" if card.get("code") else ""}">{card["subline"]}</div>'
           if card.get("subline") else "")  # "code": true sets the subline in monospace, e.g. a command
    css = CARD_CSS % {**style, "css": style.get("css", ""), "out_at": max(hold - 0.5, 1)} + card.get("css", "")
    tag_line = f'<div class="tags">{tags}</div>' if tags else ""
    html = card.get("html") or f'<h1>{card["headline"]}</h1><div class="line">{dots}</div>{tag_line}{sub}'
    return f"""(async () => {{
      const link = document.createElement('link'); link.rel = 'stylesheet';
      link.href = 'https://fonts.googleapis.com/css2?family={style["font"].replace(" ", "+")}:wght@700&display=swap';
      document.head.appendChild(link);
      try {{ await document.fonts.load('700 112px "{style["font"]}"'); }} catch (e) {{}}
      const s = document.createElement('style'); s.className = '__cardstyle'; s.textContent = {json.dumps(css)};
      const c = document.createElement('div'); c.className = '__card'; c.innerHTML = {json.dumps(html)};
      document.documentElement.append(s, c);
      setTimeout(() => {{ c.remove(); s.remove(); }}, {int(hold * 1000) + 200});
    }})()"""


class Cdp:
    def __init__(self, ws):
        self.ws, self.n, self.pending, self.on_event = ws, 0, {}, None

    async def reader(self):
        async for raw in self.ws:
            msg = json.loads(raw)
            if "id" in msg:
                self.pending.pop(msg["id"]).set_result(msg)
            elif self.on_event:
                self.on_event(msg)

    async def send(self, method, **params):
        self.n += 1
        fut = asyncio.get_running_loop().create_future()
        self.pending[self.n] = fut
        await self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        msg = await fut
        if "error" in msg:
            raise RuntimeError(f"{method}: {msg['error']}")
        return msg["result"]

    async def js(self, expr):
        r = await self.send("Runtime.evaluate", expression=expr, awaitPromise=True, returnByValue=True)
        if "exceptionDetails" in r:
            raise RuntimeError(f"JS failed: {expr[:80]} -> {r['exceptionDetails']}")
        return r["result"].get("value")


class Recorder:
    def __init__(self, cdp, out, width, height):
        self.cdp, self.out, self.w, self.h = cdp, out, width, height
        self.frames, self.t0 = [], None
        self.ff = []  # (start, end, factor) on the video clock: spans played back faster
        self.pos = (width / 2, height / 2)
        self.cam = (1.0, 0.0, 0.0)  # scale, tx, ty of the body transform
        (out / "frames").mkdir(parents=True, exist_ok=True)

    # ---- frames
    def on_event(self, msg):
        if msg.get("method") != "Page.screencastFrame":
            return
        p = msg["params"]
        ts = p["metadata"]["timestamp"]
        self.t0 = self.t0 or ts
        name = f"frames/{len(self.frames):06d}.jpg"
        (self.out / name).write_bytes(base64.b64decode(p["data"]))
        self.frames.append((ts, name))
        asyncio.get_running_loop().create_task(self.cdp.send("Page.screencastFrameAck", sessionId=p["sessionId"]))

    def now(self):
        return time.time() - self.t0

    # ---- camera
    async def rect(self, sel):
        r = await self.cdp.js(f"(() => {{ const e = document.querySelector({json.dumps(sel)});"
                              "if (!e) throw new Error('no element: ' + " + json.dumps(sel) + ");"
                              "const r = e.getBoundingClientRect(); return {x:r.x,y:r.y,w:r.width,h:r.height}; })()")
        return r

    async def zoom(self, sel, pad=40):
        if sel is None:
            s, tx, ty = 1.0, 0.0, 0.0
        else:
            r = await self.rect(sel)
            s0, tx0, ty0 = self.cam
            nx, ny, nw, nh = (r["x"] - tx0) / s0, (r["y"] - ty0) / s0, r["w"] / s0, r["h"] / s0
            s = max(1.0, min(2.4, self.w / (nw + 2 * pad), self.h / (nh + 2 * pad)))
            body_h = await self.cdp.js("document.body.offsetHeight")
            tx = min(0, max(self.w - s * self.w, self.w / 2 - s * (nx + nw / 2)))
            ty = min(0, max(self.h - s * max(body_h, self.h), self.h / 2 - s * (ny + nh / 2)))
        self.cam = (s, tx, ty)
        await self.cdp.js(f"document.body.style.transform = 'translate({tx}px,{ty}px) scale({s})'")
        await asyncio.sleep(ZOOM_SECONDS + 0.15)

    # ---- pointer
    async def move(self, sel):
        r = await self.rect(sel)
        x, y = r["x"] + r["w"] / 2, r["y"] + min(r["h"] / 2, 40)
        await self.cdp.js(f"window.__pointer.to({x}, {y})")
        x0, y0 = self.pos
        steps = 12
        for i in range(1, steps + 1):
            f = i / steps
            f = f * f * (3 - 2 * f)
            await self.cdp.send("Input.dispatchMouseEvent", type="mouseMoved", x=x0 + (x - x0) * f, y=y0 + (y - y0) * f)
            await asyncio.sleep(GLIDE_SECONDS / steps)
        self.pos = (x, y)

    async def click(self, sel):
        await self.move(sel)
        x, y = self.pos
        await self.cdp.js(f"window.__pointer.ripple({x}, {y})")
        for kind in ("mousePressed", "mouseReleased"):
            await self.cdp.send("Input.dispatchMouseEvent", type=kind, x=x, y=y, button="left", clickCount=1)
            await asyncio.sleep(0.08)
        await asyncio.sleep(0.4)

    async def type_text(self, text):
        # insertText, not key events: React-controlled inputs miss synthetic key text, and it takes å, ä, ö.
        for ch in text:
            await self.cdp.send("Input.insertText", text=ch)
            await asyncio.sleep(0.07)

    async def run_step(self, step, timeout, keep_going=False):
        try:
            await asyncio.wait_for(self.do_step(step), step.get("timeout", timeout) + step.get("wait", 0) + step.get("ff", 0))
        except (asyncio.TimeoutError, RuntimeError) as e:
            what = f"step failed ({type(e).__name__}: {str(e)[:160]}): {json.dumps(step, ensure_ascii=False)[:160]}"
            if not keep_going:
                sys.exit(what)
            print("  " + what)  # a trial run (--probe) lists every miss in one pass

    async def do_step(self, step):
        if "zoom" in step:
            await self.zoom(step["zoom"], step.get("pad", 40))
        elif "move" in step:
            await self.move(step["move"])
        elif "click" in step:
            await self.click(step["click"])
        elif "type" in step:
            await self.type_text(step["type"]["text"])
        elif "eval" in step:
            await self.cdp.js(step["eval"])
            if "location.hash" in step["eval"]:
                await asyncio.sleep(SHORT_WAIT)
        elif "go" in step:
            # In-app navigation for a single-page app: a new history entry and a popstate, no reload.
            await self.cdp.js(f"history.pushState(null, '', {json.dumps(step['go'])});"
                              "dispatchEvent(new PopStateEvent('popstate'))")
            await asyncio.sleep(step.get("settle", 1.5))
        elif "key" in step:
            key = step["key"]
            mods = step.get("modifiers", 0)  # 1 Alt, 2 Ctrl, 4 Meta, 8 Shift
            for kind in ("keyDown", "keyUp"):
                await self.cdp.send("Input.dispatchKeyEvent", type=kind, key=key, code=step.get("code", key),
                                    windowsVirtualKeyCode=step.get("vk", 0), modifiers=mods)
            await asyncio.sleep(0.3)
        elif "until" in step:
            # Hold until a JS condition is true (an answer has arrived), polling; the step timeout caps it.
            while not await self.cdp.js(f"!!({step['until']})"):
                await asyncio.sleep(0.5)
            await asyncio.sleep(step.get("settle", 0))
        elif "ff" in step:
            # Fast-forward a wait the viewer needn't sit through (an answer being written): recorded in
            # real time, played back in `to` seconds (default 1) or `factor` times faster. Keep it clear
            # of a voice clip, which isn't sped up, and follow it with 2-3 s on the result, no more.
            start = self.now()
            await asyncio.sleep(step["ff"])
            factor = step.get("factor") or step["ff"] / step.get("to", 1.0)
            self.ff.append((start, self.now(), max(factor, 1.0)))
        elif "wait" in step:
            await asyncio.sleep(step["wait"])
        else:
            raise ValueError(f"unknown step {step}")


async def borrow_cookies(cdp, port, domains):
    """Copy the cookies for `domains` from a Chrome someone signed in to by hand (on `port`) into this one.

    For apps that sign in with a browser login and a session cookie, where no token can be minted:
    the person signs in once in a visible Chrome, and the headless one records with its cookies.
    Values are never printed or written to disk."""
    version = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version"))
    async with websockets.connect(version["webSocketDebuggerUrl"], max_size=None) as ws:
        await ws.send(json.dumps({"id": 1, "method": "Storage.getCookies"}))
        while (msg := json.loads(await ws.recv())).get("id") != 1:
            pass
    keep = [c for c in msg["result"]["cookies"] if any(d in c["domain"] for d in domains)]
    allowed = {"name", "value", "domain", "path", "secure", "httpOnly", "sameSite", "expires", "priority",
               "sameParty", "sourceScheme", "partitionKey"}
    cookies = [{k: v for k, v in c.items() if k in allowed and not (k == "expires" and c.get("session"))} for c in keep]
    await cdp.send("Network.enable")
    await cdp.send("Network.setCookies", cookies=cookies)
    print(f"borrowed {len(cookies)} cookies for {', '.join(domains)}")


def auth_handler(cdp, token, hosts):
    """Event handler adding the bearer token to requests for `hosts`; everything else passes through."""
    async def answer(p):
        headers = p["request"]["headers"]
        if urlparse(p["request"]["url"]).hostname in hosts:
            headers = {**headers, "Authorization": f"Bearer {token}"}
        await cdp.send("Fetch.continueRequest", requestId=p["requestId"],
                       headers=[{"name": k, "value": v} for k, v in headers.items()])

    def on_event(msg):
        if msg.get("method") == "Fetch.requestPaused":
            asyncio.get_running_loop().create_task(answer(msg["params"]))
    return on_event


async def record(args):
    scenes_cfg = json.loads(Path(args.scenes).read_text())
    lengths = json.loads(Path(args.lengths).read_text())
    out = Path(args.out)
    profile = tempfile.mkdtemp(prefix="demo-chrome-")
    chrome = subprocess.Popen([args.chrome, "--headless=new", f"--remote-debugging-port={args.port}",
                               f"--user-data-dir={profile}", "--hide-scrollbars", "--mute-audio", "--no-first-run",
                               "--remote-allow-origins=*", f"--window-size={args.width},{args.height}", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{args.port}/json/list"))
                break
            except OSError:
                await asyncio.sleep(0.2)
        else:
            sys.exit(f"Chrome did not start on port {args.port}; check --chrome")
        ws_url = next(t["webSocketDebuggerUrl"] for t in tabs if t["type"] == "page")
        async with websockets.connect(ws_url, max_size=None) as ws:
            cdp = Cdp(ws)
            reader = asyncio.create_task(cdp.reader())
            rec = Recorder(cdp, out, args.width, args.height)
            on_auth = auth_handler(cdp, os.environ["DEMO_AUTH_TOKEN"], args.auth_host) if args.auth_host else None
            cdp.on_event = lambda msg: (rec.on_event(msg), on_auth and on_auth(msg))
            await run_scenes(cdp, rec, scenes_cfg, lengths, args)
            reader.cancel()
    finally:
        chrome.terminate()


async def run_scenes(cdp, rec, cfg, lengths, args):
    await cdp.send("Page.enable")
    await cdp.send("Emulation.setDeviceMetricsOverride", width=args.width, height=args.height, deviceScaleFactor=2, mobile=False)
    if args.auth_host:
        await cdp.send("Fetch.enable", patterns=[{"urlPattern": "*"}])
    # The app's Content-Security-Policy would block the cards' web fonts (and any card asset); a recording
    # isn't the app's real traffic, so bypass it. Without this a card silently falls back to a system font.
    await cdp.send("Page.setBypassCSP", enabled=True)
    await cdp.send("Page.addScriptToEvaluateOnNewDocument", source=POINTER_JS)
    # "inject": a JS file (relative to the scenes file) run on every page load, e.g. hiding the person's name.
    if cfg.get("inject"):
        inject = (Path(args.scenes).parent / cfg["inject"]).read_text()
        await cdp.send("Page.addScriptToEvaluateOnNewDocument", source=inject)
    if args.cookies_from:
        await borrow_cookies(cdp, args.cookies_from, args.cookie_domain or [urlparse(args.url).hostname])
    await cdp.send("Page.navigate", url=args.url)
    await asyncio.sleep(cfg.get("first_load", 2.5))
    # The "can we get in" check: print what loaded, so a login form is obvious.
    print("loaded:", await cdp.js("document.title"), "|", (await cdp.js("document.body.innerText"))[:80].replace("\n", " / "))
    await cdp.js(POINTER_JS)
    cfg_style = cfg.get("style", {})
    style = {"bg": args.bg or cfg_style.get("bg") or await cdp.js("getComputedStyle(document.body).backgroundColor"),
             "accent": args.accent or cfg_style.get("accent", "#e8a94a"), "font": args.font or cfg_style.get("font", "Outfit"),
             "css": cfg_style.get("css", "")}  # the tone's extra card CSS: grain, letterbox, a neon glow
    await cdp.send("Page.startScreencast", format="jpeg", quality=88, maxWidth=1920, maxHeight=1080, everyNthFrame=1)
    while not rec.t0:
        await cdp.js("document.body.style.outline = '0'")  # nudge Chrome into sending the first frame
        await asyncio.sleep(0.1)

    timeline = []
    for i, scene in enumerate(cfg["scenes"]):
        clip = lengths[f"{i:02d}.wav"]
        hold = clip + cfg.get("breath", 0.8)
        if "card" in scene:
            hold = max(hold, CARD_MIN)
            await cdp.js(card_js(scene["card"], style, hold))
        start = rec.now()
        print(f"scene {i} {scene['name']} @ {start:.1f}s hold {hold:.1f}s")
        for step in scene.get("steps", []):
            await rec.run_step(step, args.step_timeout, args.probe)
        await asyncio.sleep(max(0, start + hold - rec.now()))
        timeline.append({"name": scene["name"], "start": start, "end": rec.now(), "voiced": hold})

    end = rec.now() + 0.3
    await asyncio.sleep(0.3)
    await cdp.send("Page.stopScreencast")
    write_outputs(rec, timeline, end)


def squeezer(ff):
    """Maps a time on the recording clock to the played-back clock, with fast-forwarded spans shortened."""
    return lambda t: t - sum(max(0.0, min(t, e) - s) * (1 - 1 / f) for s, e, f in ff)


def write_outputs(rec, timeline, end):
    at = squeezer(rec.ff)
    lines = []
    for (ts, name), nxt in zip(rec.frames, rec.frames[1:] + [(rec.t0 + end, None)]):
        lines.append(f"file '{name}'\nduration {max(at(nxt[0] - rec.t0) - at(ts - rec.t0), 0.001):.4f}")
    lines.append(f"file '{rec.frames[-1][1]}'")  # concat demuxer ignores the last duration
    (rec.out / "frames.txt").write_text("\n".join(lines) + "\n")
    scenes = [{**s, "start": at(s["start"]), "end": at(s["end"])} for s in timeline]
    (rec.out / "timeline.json").write_text(json.dumps({"total": at(end), "scenes": scenes}, indent=1))
    print(f"{len(rec.frames)} frames, {at(end):.1f}s played back ({end:.1f}s recorded)")
    for s in scenes:
        silent = s["end"] - s["start"] - s["voiced"]
        if silent > SILENT_HOLD:
            print(f"  scene {s['name']} holds {silent:.1f}s with no voice: fast-forward it (ff) or give it a line")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("scenes"), ap.add_argument("lengths"), ap.add_argument("out"), ap.add_argument("url")
    ap.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    ap.add_argument("--port", type=int, default=9333)
    ap.add_argument("--width", type=int, default=1600), ap.add_argument("--height", type=int, default=900)
    ap.add_argument("--accent"), ap.add_argument("--bg"), ap.add_argument("--font")
    ap.add_argument("--timeout", type=float, default=600, help="seconds for the whole recording")
    ap.add_argument("--step-timeout", type=float, default=30, help="seconds for one step")
    ap.add_argument("--auth-host", action="append", help="send $DEMO_AUTH_TOKEN as a bearer token to this host")
    ap.add_argument("--probe", action="store_true", help="trial run: report a failed step and carry on")
    ap.add_argument("--cookies-from", type=int, help="debug port of a Chrome signed in by hand; copy its cookies")
    ap.add_argument("--cookie-domain", action="append", help="with --cookies-from: domains to copy (default: the URL's host)")
    args = ap.parse_args()
    if args.auth_host and not os.environ.get("DEMO_AUTH_TOKEN"):
        sys.exit("--auth-host needs the token in the DEMO_AUTH_TOKEN environment variable")
    try:
        asyncio.run(asyncio.wait_for(record(args), args.timeout))
    except asyncio.TimeoutError:
        sys.exit(f"recording timed out after {args.timeout}s")
