#!/usr/bin/env python3
"""
SubBurn → Figma, via clipboard COPY/PASTE.

Why copy/paste instead of File > Place image:
  Place image treats an SVG as a *document*, so each call spawns a "Spec" pane
  that covers the canvas in Figma's web build. Copy/paste inserts the SVG as
  ordinary vector layers on the current page — which is what we actually want.

Pipeline:
  1. create a brand-new file (never touch an existing one)
  2. open it, confirm Design mode
  3. for each SVG: load it in a throwaway tab, select-all + copy, then paste
     on the Figma canvas
  4. position via the inspector, rename, screenshot

    python3 tools/figma_copy_paste.py
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
SVG = ROOT / "renders" / "svg"
CDP = "http://127.0.0.1:9333"

FRAMES = [
    ("frame-1.svg", 0, "01 · Burn Dashboard"),
    ("frame-2.svg", 441, "02 · Quick Add"),
    ("frame-3.svg", 882, "03 · Card Studio"),
    ("frame-4.svg", 1323, "04 · Renewal & Kill-Switch"),
    ("receipt-card.svg", 1764, "03a · Receipt 360x640"),
]

# inside the canvas, low enough to clear any artboard
DROP = (700, 700)

JS_XY = r"""
() => {
  const ins = [...document.querySelectorAll('input')]
    .map(i => ({ i, r: i.getBoundingClientRect() }))
    .filter(({ i, r }) =>
      r.x > 1300 && r.width > 25 && r.width < 130 && r.y > 190 && r.y < 340 &&
      !String(i.value).includes('°') &&
      /^-?[\d.]+$/.test(String(i.value).trim()))
    .sort((a, b) => a.r.y - b.r.y || a.r.x - b.r.x)
    .slice(0, 2);
  return ins.map(({ i, r }) => ({
    x: Math.round(r.x + r.width / 2),
    y: Math.round(r.y + r.height / 2),
    v: i.value,
  }));
}
"""


def xy(pg):
    return pg.evaluate(JS_XY)


def set_xy(pg, x, y):
    for _ in range(4):
        f = xy(pg)
        if len(f) < 2:
            pg.wait_for_timeout(600)
            continue
        for pt, v in zip(f, (x, y)):
            pg.mouse.click(pt["x"], pt["y"])
            pg.wait_for_timeout(200)
            pg.keyboard.press("Control+a")
            pg.wait_for_timeout(100)
            pg.keyboard.type(str(v))
            pg.wait_for_timeout(100)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(600)
            f = xy(pg)
            if len(f) < 2:
                break
        g = xy(pg)
        if len(g) == 2 and abs(float(g[0]["v"]) - x) < 1 and abs(float(g[1]["v"]) - y) < 1:
            return True
        pg.wait_for_timeout(400)
    return False


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        ctx = browser.contexts[0]
        figma = ctx.pages[0]
        figma.bring_to_front()
        figma.wait_for_timeout(500)

        # ── 1. brand-new file ────────────────────────────────────────────
        created = figma.evaluate(
            """async () => {
          const r = await fetch('/api/files', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            credentials: 'include',
            body: JSON.stringify({ name: '01 SubBurn' })
          });
          const j = await r.json();
          return { key: j?.meta?.key, name: j?.meta?.name, status: r.status };
        }"""
        )
        key = created.get("key")
        print("new file:", created)
        if not key:
            return 1

        url = f"https://www.figma.com/design/{key}/SubBurn"
        figma.goto(url, wait_until="domcontentloaded", timeout=120000)
        figma.wait_for_selector("canvas", timeout=120000)
        figma.wait_for_timeout(8000)
        print("opened:", figma.title())

        # ── 2. one throwaway tab for copying ─────────────────────────────
        src = ctx.new_page()

        ok = 0
        for fname, px, name in FRAMES:
            path = SVG / fname
            if not path.exists():
                print("missing", fname)
                continue

            # copy the SVG itself (no TARGETS juggling, no xclip)
            src.goto(path.as_uri(), wait_until="load", timeout=60000)
            src.wait_for_timeout(700)
            src.keyboard.press("Control+a")
            src.wait_for_timeout(300)
            src.keyboard.press("Control+c")
            src.wait_for_timeout(800)

            # paste onto the Figma canvas
            figma.bring_to_front()
            figma.keyboard.press("Escape")
            figma.wait_for_timeout(400)
            figma.mouse.click(*DROP)
            figma.wait_for_timeout(500)
            figma.keyboard.press("Control+v")
            figma.wait_for_timeout(7000)

            moved = set_xy(figma, px, 0)

            figma.keyboard.press("Control+r")
            figma.wait_for_timeout(800)
            figma.keyboard.press("Control+a")
            figma.wait_for_timeout(100)
            figma.keyboard.type(name, delay=12)
            figma.wait_for_timeout(150)
            figma.keyboard.press("Enter")
            figma.wait_for_timeout(900)

            print(f"  {fname:20s} x={px:<5} {'ok' if moved else 'MOVE FAIL'}")
            ok += moved

        src.close()
        figma.bring_to_front()
        figma.keyboard.press("Escape")
        figma.wait_for_timeout(500)
        figma.keyboard.press("Shift+1")
        figma.wait_for_timeout(5000)
        figma.screenshot(path=str(ROOT / "renders" / "figma-copy-paste.png"))

        layers = figma.evaluate(
            """() => [...document.querySelectorAll('*')]
                 .filter(e => e.children.length === 0)
                 .map(e => (e.textContent || '').trim())
                 .filter(t => /^(0[1-4] · |03a · )/.test(t))"""
        )
        print(f"\n{ok}/{len(FRAMES)} positioned")
        print("frames:", layers)
        print("url:", figma.url.split("?")[0])
        browser.close()
        return 0 if ok == len(FRAMES) else 1


if __name__ == "__main__":
    sys.exit(main())
