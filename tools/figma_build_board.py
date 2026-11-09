#!/usr/bin/env python3
"""
Rebuild the SubBurn Figma board — final, defensive version.

Hard-won rules (each one is a bug that bit us):
  1. NEVER use Ctrl+A on the canvas. It selects across pages and can spawn
     a Slides/Spec document. Delete frames one at a time by clicking the layer
     row and pressing Delete.
  2. "Place image" drops at the cursor; if the cursor is over an existing
     frame the new frame becomes its CHILD. Drop in a reserved empty gutter.
  3. X/Y inputs re-flow between runs, so locate them via the "Position"
     section, never by hard-coded coordinates.
  4. SVG import reads the *artboard* size, so the frame must be re-positioned
     before the next drop or frames pile up.

    python3 tools/figma_build_board.py
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

# Canvas is [338..1351] x [0..853]. Frames occupy design y=0..852, which maps to
# roughly screen y=62..590 at fit zoom. Dropping low keeps the click outside
# every artboard, so "Place image" parents the new frame to the page.
DROP = (700, 700)

FRAME_RE = r"^(frame-[1-4] 1|receipt-card 1|0[1-4] · .+|03a · .+)$"

JS_LAYER_ROWS = r"""
(re) => {
  const rx = new RegExp(re);
  const out = [];
  document.querySelectorAll('*').forEach(e => {
    if (e.children.length !== 0) return;
    const t = (e.textContent || '').trim();
    if (!rx.test(t)) return;
    const r = e.getBoundingClientRect();
    if (r.x > 90 && r.x < 340 && r.y > 140 && r.y < 830) {
      out.push({ t, x: Math.round(r.x + 14), y: Math.round(r.y + r.height / 2) });
    }
  });
  return out;
}
"""

JS_XY = r"""
() => {
  // In the inspector, X and Y are the first two numeric inputs in the right
  // rail. Rotation is excluded because its value carries a degree sign.
  const ins = [...document.querySelectorAll('input')]
    .map(inp => ({ inp, r: inp.getBoundingClientRect() }))
    .filter(({ inp, r }) =>
      r.x > 1300 && r.width > 25 && r.width < 130 && r.y > 190 && r.y < 340 &&
      !String(inp.value).includes('°') &&
      /^-?[\d.]+$/.test(String(inp.value).trim()))
    .sort((a, b) => a.r.y - b.r.y || a.r.x - b.r.x)
    .slice(0, 2);

  if (ins.length < 2) return null;
  return ins.map(({ r }) => ({
    x: Math.round(r.x + r.width / 2),
    y: Math.round(r.y + r.height / 2),
  }));
}
"""


def rows(pg):
    return pg.evaluate(JS_LAYER_ROWS, FRAME_RE)


def delete_all(pg):
    """Remove existing artboards one at a time (never Ctrl+A)."""
    for _ in range(12):
        r = rows(pg)
        if not r:
            break
        pg.mouse.click(r[0]["x"], r[0]["y"])
        pg.wait_for_timeout(900)
        pg.keyboard.press("Delete")
        pg.wait_for_timeout(1200)
    return rows(pg)


def place(pg, path):
    pg.keyboard.press("Escape")
    pg.wait_for_timeout(300)
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
        raise RuntimeError("File menu missing")
    pg.mouse.move(fi[0], fi[1])
    pg.wait_for_timeout(900)
    with pg.expect_file_chooser(timeout=25000) as fc:
        pg.get_by_role("menuitem", name="Place image", exact=False).click()
    fc.value.set_files(str(path))
    pg.wait_for_timeout(2400)
    pg.mouse.click(*DROP)
    pg.wait_for_timeout(6000)


JS_XY_READ = r"""
() => {
  const ins = [...document.querySelectorAll('input')]
    .map(inp => ({ inp, r: inp.getBoundingClientRect() }))
    .filter(({ inp, r }) =>
      r.x > 1300 && r.width > 25 && r.width < 130 && r.y > 190 && r.y < 340 &&
      !String(inp.value).includes('°') &&
      /^-?[\d.]+$/.test(String(inp.value).trim()))
    .sort((a, b) => a.r.y - b.r.y || a.r.x - b.r.x)
    .slice(0, 2);
  return ins.map(({ inp, r }) => ({
    x: Math.round(r.x + r.width / 2),
    y: Math.round(r.y + r.height / 2),
    v: inp.value,
  }));
}
"""


def _set_field(pg, pt, value):
    pg.mouse.click(pt["x"], pt["y"])
    pg.wait_for_timeout(250)
    pg.keyboard.press("Control+a")
    pg.wait_for_timeout(120)
    pg.keyboard.type(str(value))
    pg.wait_for_timeout(120)
    pg.keyboard.press("Enter")
    pg.wait_for_timeout(700)


def move_to(pg, x, y):
    """Set X/Y and confirm the fields read back what we typed."""
    for attempt in range(4):
        fields = pg.evaluate(JS_XY_READ)
        if len(fields) < 2:
            pg.wait_for_timeout(700)
            continue
        _set_field(pg, fields[0], x)
        fields = pg.evaluate(JS_XY_READ)
        if len(fields) < 2:
            continue
        _set_field(pg, fields[1], y)

        got = pg.evaluate(JS_XY_READ)
        if len(got) == 2 and abs(float(got[0]["v"]) - x) < 1 and abs(float(got[1]["v"]) - y) < 1:
            return True
        pg.wait_for_timeout(500)
    return False


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        pg = browser.contexts[0].pages[0]
        pg.bring_to_front()
        pg.wait_for_timeout(500)

        if "SubBurn" not in pg.title():
            print("not on the SubBurn file — aborting")
            return 1
        print("file:", pg.title())

        pg.keyboard.press("Escape")
        pg.wait_for_timeout(400)
        left = delete_all(pg)
        print("cleared; frames left:", len(left))

        done = 0
        for fname, px, name in FRAMES:
            path = SVG / fname
            if not path.exists():
                print("missing", fname)
                continue
            place(pg, path)
            moved = move_to(pg, px, 0)
            pg.keyboard.press("Control+r")
            pg.wait_for_timeout(800)
            pg.keyboard.press("Control+a")
            pg.wait_for_timeout(100)
            pg.keyboard.type(name, delay=12)
            pg.wait_for_timeout(150)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(900)
            print(f"  {fname:20s} x={px:<5} {'ok' if moved else 'MOVE FAIL'}")
            done += moved

        pg.keyboard.press("Escape")
        pg.wait_for_timeout(500)
        pg.keyboard.press("Shift+1")
        pg.wait_for_timeout(5000)
        pg.screenshot(path=str(ROOT / "renders" / "figma-board-final.png"))

        final = rows(pg)
        print("frames on canvas:", [f["t"] for f in final])
        browser.close()
        return 0 if done == len(FRAMES) else 1


if __name__ == "__main__":
    sys.exit(main())
