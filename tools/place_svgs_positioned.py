#!/usr/bin/env python3
"""
Rebuild the SubBurn board in Figma with exact positions.

Problem this solves: Figma's "Place image" drops the new frame at the click
point, and if that point is inside an existing frame the new one becomes a
*child* (nested, clipped). So we place each SVG, then immediately type exact
X/Y into the Position fields — which also gives the brief's 48 px gutter.

    python3 tools/place_svgs_positioned.py
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
SVG = ROOT / "renders" / "svg"
CDP = "http://127.0.0.1:9333"
FILE_URL = "https://www.figma.com/design/9S9W6uNjFxuP2CIj47uy39/SubBurn"

# x offsets: 393 wide frames + 48 gutter
ITEMS = [
    ("frame-1.svg", 0, 0, "01 · Burn Dashboard"),
    ("frame-2.svg", 441, 0, "02 · Quick Add"),
    ("frame-3.svg", 882, 0, "03 · Card Studio"),
    ("frame-4.svg", 1323, 0, "04 · Renewal & Kill-Switch"),
    ("receipt-card.svg", 1764, 0, "03a · Receipt 360x640"),
]

CLICK = (700, 120)


def undo_all(page, times=40):
    page.keyboard.press("Escape")
    page.wait_for_timeout(400)
    for _ in range(times):
        page.keyboard.press("Control+z")
    page.wait_for_timeout(4000)


def position_fields(page):
    """Locate the X / Y inputs in the Position block of the right sidebar."""
    return page.evaluate(
        """() => {
      const inputs = [...document.querySelectorAll('input')].filter(i => {
        const r = i.getBoundingClientRect();
        return r.width > 20 && r.width < 90 && r.x > 1300 && r.y > 200 && r.y < 340;
      });
      return inputs.map(i => {
        const r = i.getBoundingClientRect();
        return { x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2), v: i.value };
      });
    }"""
    )


def set_position(page, px, py):
    fields = position_fields(page)
    if len(fields) < 2:
        print("   ! position fields not found:", fields)
        return False
    for field, val in zip(fields[:2], (px, py)):
        page.mouse.click(field["x"], field["y"])
        page.wait_for_timeout(250)
        page.keyboard.press("Control+a")
        page.keyboard.type(str(val))
        page.keyboard.press("Enter")
        page.wait_for_timeout(700)
    return True


def place_one(page, svg_path: pathlib.Path):
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    page.mouse.click(28, 24)  # main menu
    page.wait_for_timeout(900)

    file_item = page.evaluate(
        """() => {
      const e = [...document.querySelectorAll('[role=menuitem]')]
        .find(x => (x.textContent||'').trim() === 'File');
      if (!e) return null;
      const r = e.getBoundingClientRect();
      return [Math.round(r.x + r.width/2), Math.round(r.y + r.height/2)];
    }"""
    )
    if not file_item:
        raise RuntimeError("File menu missing")

    page.mouse.move(file_item[0], file_item[1])
    page.wait_for_timeout(900)

    with page.expect_file_chooser(timeout=25000) as fc:
        page.get_by_role("menuitem", name="Place image", exact=False).click()
    fc.value.set_files(str(svg_path))
    page.wait_for_timeout(2500)

    # drop at a harmless spot far from existing frames
    page.mouse.click(*CLICK)
    page.wait_for_timeout(6000)


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        page = browser.contexts[0].pages[0]
        page.bring_to_front()
        page.wait_for_timeout(500)

        if "SubBurn" not in page.title():
            page.goto(FILE_URL, wait_until="domcontentloaded", timeout=120000)
            page.wait_for_selector("canvas", timeout=120000)
            page.wait_for_timeout(6000)

        print("file:", page.title())
        print("clearing previous attempts…")
        undo_all(page)

        for fname, px, py, label in ITEMS:
            path = SVG / fname
            if not path.exists():
                print("missing", fname)
                continue
            place_one(page, path)
            ok = set_position(page, px, py)
            print(f"placed {fname:22s} -> x={px:<5} y={py}  {'ok' if ok else 'POSITION FAILED'}")
            page.screenshot(path=str(ROOT / "renders" / f"pos-{fname.replace('.svg','')}.png"))

        # zoom to fit so the whole board is visible
        page.keyboard.press("Escape")
        page.wait_for_timeout(300)
        page.keyboard.press("Shift+1")
        page.wait_for_timeout(4000)
        page.screenshot(path=str(ROOT / "renders" / "figma-board.png"))
        print("screenshot: renders/figma-board.png")
        browser.close()
        return 0


if __name__ == "__main__":
    sys.exit(main())
