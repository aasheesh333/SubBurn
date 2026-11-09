#!/usr/bin/env python3
"""
Rebuild the SubBurn board in Figma — robust version.

Lessons baked in:
  • Fixed screen coordinates for the X/Y inputs break when the inspector
    re-flows. Find them by their sibling label ("Position" → X / Y) instead.
  • "Place image" nests the new frame if the drop point is inside an existing
    frame, so we always drop in a zone we know is empty, then set X/Y.
  • The page must be emptied first, otherwise frames stack invisibly.

Only the SubBurn file is touched.

    python3 tools/figma_rebuild.py
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

# drop zone: far right of the viewport, below any existing artboard
DROP = (1480, 820)

JS_XY_FIELDS = r"""
() => {
  // The Position block has two inputs labelled X and Y. Walk up from the
  // "Position" text until we find a container holding exactly two inputs.
  const nodes = [...document.querySelectorAll('*')];
  const label = nodes.find(e =>
    e.children.length === 0 && (e.textContent || '').trim() === 'Position');
  if (!label) return null;

  let box = label.parentElement;
  for (let i = 0; i < 5 && box; i++) {
    const inputs = [...box.querySelectorAll('input')].filter(inp => {
      const r = inp.getBoundingClientRect();
      return r.width > 30 && r.width < 120 && r.height > 10;
    });
    if (inputs.length >= 2) {
      return inputs.slice(0, 2).map(inp => {
        const r = inp.getBoundingClientRect();
        return { x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2) };
      });
    }
    box = box.parentElement;
  }
  return null;
}
"""


def open_file_menu(pg):
    pg.keyboard.press("Escape")
    pg.wait_for_timeout(350)
    pg.mouse.click(28, 24)
    pg.wait_for_timeout(900)
    return pg.evaluate(
        """() => {
      const e = [...document.querySelectorAll('[role=menuitem]')]
        .find(x => (x.textContent || '').trim() === 'File');
      if (!e) return null;
      const r = e.getBoundingClientRect();
      return [Math.round(r.x + r.width / 2), Math.round(r.y + r.height / 2)];
    }"""
    )


def place(pg, svg_path: pathlib.Path):
    fi = open_file_menu(pg)
    if not fi:
        raise RuntimeError("File menu item not found")
    pg.mouse.move(fi[0], fi[1])
    pg.wait_for_timeout(900)
    with pg.expect_file_chooser(timeout=25000) as fc:
        pg.get_by_role("menuitem", name="Place image", exact=False).click()
    fc.value.set_files(str(svg_path))
    pg.wait_for_timeout(2400)
    pg.mouse.click(*DROP)
    pg.wait_for_timeout(6500)


def set_xy(pg, x, y):
    for _ in range(3):
        fields = pg.evaluate(JS_XY_FIELDS)
        if fields and len(fields) == 2:
            for f, v in zip(fields, (x, y)):
                pg.mouse.click(f["x"], f["y"])
                pg.wait_for_timeout(200)
                pg.keyboard.press("Control+a")
                pg.wait_for_timeout(70)
                pg.keyboard.type(str(v))
                pg.wait_for_timeout(70)
                pg.keyboard.press("Enter")
                pg.wait_for_timeout(600)
            return True
        pg.wait_for_timeout(800)
    return False


def rename_selected(pg, name):
    pg.keyboard.press("Control+r")
    pg.wait_for_timeout(800)
    pg.keyboard.press("Control+a")
    pg.wait_for_timeout(100)
    pg.keyboard.type(name, delay=15)
    pg.wait_for_timeout(150)
    pg.keyboard.press("Enter")
    pg.wait_for_timeout(900)


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        page = browser.contexts[0].pages[0]
        page.bring_to_front()
        page.wait_for_timeout(500)

        if "SubBurn" not in page.title():
            print("Not on the SubBurn file — aborting.")
            return 1
        print("file:", page.title())

        # empty the page
        page.keyboard.press("Escape")
        page.wait_for_timeout(400)
        page.mouse.click(*DROP)
        page.wait_for_timeout(400)
        page.keyboard.press("Control+a")
        page.wait_for_timeout(1500)
        page.keyboard.press("Delete")
        page.wait_for_timeout(3500)

        left = page.evaluate(
            """() => [...document.querySelectorAll('*')]
                 .filter(e => e.children.length === 0)
                 .map(e => (e.textContent || '').trim())
                 .filter(t => /^frame-[1-4] 1$|^receipt-card 1$/.test(t)).length"""
        )
        print("frames remaining:", left)

        ok = 0
        for fname, px, name in FRAMES:
            path = SVG / fname
            if not path.exists():
                print("missing", fname)
                continue

            place(page, path)
            positioned = set_xy(page, px, 0)
            rename_selected(page, name)
            print(f"  {fname:20s} x={px:<5} pos={'ok' if positioned else 'FAIL'}  name={name}")
            if positioned:
                ok += 1

        page.keyboard.press("Escape")
        page.wait_for_timeout(500)
        page.keyboard.press("Shift+1")
        page.wait_for_timeout(5000)
        page.screenshot(path=str(ROOT / "renders" / "figma-rebuilt.png"))
        print(f"\n{ok}/{len(FRAMES)} positioned")
        browser.close()
        return 0 if ok == len(FRAMES) else 1


if __name__ == "__main__":
    sys.exit(main())
