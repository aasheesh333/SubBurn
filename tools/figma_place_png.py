#!/usr/bin/env python3
"""
SubBurn → Figma via PNG placement.

What we learned the hard way:
  • "Place image" with an SVG spawns a "Spec" document pane in the web build
    (Figma treats SVG as a document, not a picture).
  • Clipboard-copying an SVG into Figma only carries the text runs, losing
    every vector.
  • "Place image" with a PNG inserts an ordinary image-filled frame — no Spec
    pane, no nesting surprises.

So we rasterise the SVGs at @3x (identical to the design renders) and place
those. The frames land as real Figma frames at exactly 393x852, so they can
still be repositioned, renamed, masked and exported at 3x = 1179x2556.

Trade-off, stated plainly: the artwork is an image fill, not editable vectors.
That is the only way to get it onto the web canvas reliably. tools/figma-plugin/
still holds the full editable build for the desktop app.

    python3 tools/figma_place_png.py
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
PNG = ROOT / "renders" / "figma-png"
CDP = "http://127.0.0.1:9333"

FRAMES = [
    ("frame-1.png", 0, "01 · Burn Dashboard"),
    ("frame-2.png", 441, "02 · Quick Add"),
    ("frame-3.png", 882, "03 · Card Studio"),
    ("frame-4.png", 1323, "04 · Renewal & Kill-Switch"),
    ("receipt-card.png", 1764, "03a · Receipt 360x640"),
]

DROP = (700, 700)

JS_WH = r"""
() => {
  // Dimensions block sits just under Position: two numeric inputs, W then H.
  const ins = [...document.querySelectorAll('input')]
    .map(i => ({ i, r: i.getBoundingClientRect() }))
    .filter(({ i, r }) =>
      r.x > 1300 && r.width > 40 && r.width < 130 && r.y > 350 && r.y < 430 &&
      !String(i.value).includes('°') &&
      /^-?[\d.]+$/.test(String(i.value).trim()))
    .sort((a, b) => a.r.x - b.r.x)
    .slice(0, 2);
  return ins.map(({ i, r }) => ({
    x: Math.round(r.x + r.width / 2),
    y: Math.round(r.y + r.height / 2),
  }));
}
"""


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


def set_size(pg, w, h):
    """The placed PNG arrives at its pixel size (1179x2556); scale to design."""
    for _ in range(3):
        f = pg.evaluate(JS_WH)
        if len(f) < 2:
            pg.wait_for_timeout(500)
            continue
        for pt, v in zip(f, (w, h)):
            pg.mouse.click(pt["x"], pt["y"])
            pg.wait_for_timeout(200)
            pg.keyboard.press("Control+a")
            pg.wait_for_timeout(100)
            pg.keyboard.type(str(v))
            pg.wait_for_timeout(100)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(600)
        return True
    return False


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
        pg = ctx.pages[0]
        pg.bring_to_front()
        pg.wait_for_timeout(500)

        # fresh file
        created = pg.evaluate(
            """async () => {
          const r = await fetch('/api/files', {
            method: 'POST', credentials: 'include',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ name: '01 SubBurn' })
          });
          const j = await r.json();
          return j?.meta?.key || null;
        }"""
        )
        print("new file:", created)
        if not created:
            return 1

        pg.goto(f"https://www.figma.com/design/{created}/SubBurn",
                wait_until="domcontentloaded", timeout=120000)
        pg.wait_for_selector("canvas", timeout=120000)
        pg.wait_for_timeout(8000)
        print("opened:", pg.title())

        ok = 0
        for fname, px, name in FRAMES:
            path = PNG / fname
            if not path.exists():
                print("missing", fname)
                continue

            pg.keyboard.press("Escape")
            pg.wait_for_timeout(400)
            pg.mouse.click(28, 24)
            pg.wait_for_timeout(900)
            fi = pg.evaluate(
                """() => {
              const e = [...document.querySelectorAll('[role=menuitem]')]
                .find(x => (x.textContent || '').trim() === 'File');
              if (!e) return null;
              const r = e.getBoundingClientRect();
              return [Math.round(r.x + r.width / 2), Math.round(r.y + r.height / 2)];
            }"""
            )
            if not fi:
                print("File menu missing")
                break
            pg.mouse.move(fi[0], fi[1])
            pg.wait_for_timeout(900)
            with pg.expect_file_chooser(timeout=25000) as fc:
                pg.get_by_role("menuitem", name="Place image", exact=False).click()
            fc.value.set_files(str(path))
            pg.wait_for_timeout(2500)
            pg.mouse.click(*DROP)
            pg.wait_for_timeout(6500)

            w, h = (360, 640) if fname.startswith("receipt") else (393, 852)
            set_size(pg, w, h)
            moved = set_xy(pg, px, 0)

            pg.keyboard.press("Control+r")
            pg.wait_for_timeout(800)
            pg.keyboard.press("Control+a")
            pg.wait_for_timeout(100)
            pg.keyboard.type(name, delay=12)
            pg.wait_for_timeout(150)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(900)

            print(f"  {fname:18s} x={px:<5} {'ok' if moved else 'MOVE FAIL'}")
            ok += moved

        pg.keyboard.press("Escape")
        pg.wait_for_timeout(500)
        pg.keyboard.press("Shift+1")
        pg.wait_for_timeout(5000)
        pg.screenshot(path=str(ROOT / "renders" / "figma-final.png"))

        specs = pg.evaluate(
            """() => [...document.querySelectorAll('*')]
                 .filter(e => e.children.length === 0)
                 .map(e => (e.textContent || '').trim())
                 .filter(t => /^Spec \\d/.test(t))"""
        )
        print(f"\n{ok}/{len(FRAMES)} placed · spec panes: {len(specs)}")
        print("url:", pg.url.split("?")[0])
        browser.close()
        return 0 if ok == len(FRAMES) else 1


if __name__ == "__main__":
    sys.exit(main())
