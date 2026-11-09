#!/usr/bin/env python3
"""
Place all SubBurn SVGs into the SubBurn Figma file via File > Place image.

Why "Place image" and not clipboard paste: Figma's web editor only accepts SVG
from the *file chooser* (Place image) — a clipboard paste of image/svg+xml is
silently dropped, and there is no "Import plugin from manifest" in the web
build. Place image produces the same editable result: a frame with real vector
and text layers.

The script never touches any file other than the SubBurn one, and only appends.

    python3 tools/place_svgs.py
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
SVG = ROOT / "renders" / "svg"
CDP = "http://127.0.0.1:9333"
FILE_URL = "https://www.figma.com/design/6jVmqh8BbfJl4cQoLz1WsY/SubBurn"

# left-to-right order with a 48 px gutter, matching the design board
ITEMS = [
    ("frame-1.svg", 0),
    ("frame-2.svg", 441),
    ("frame-3.svg", 882),
    ("frame-4.svg", 1323),
    ("receipt-card.svg", 1764),
]

CLICK_X, CLICK_Y = 620, 180  # empty canvas, top-left of the paste area


def open_menu(page):
    """Open the main menu, tolerating the leftover overlay from a prior open."""
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    page.mouse.click(28, 24)
    page.wait_for_timeout(900)


def place(page, svg_path: pathlib.Path):
    open_menu(page)

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
        raise RuntimeError("File menu item not found")

    page.mouse.move(file_item[0], file_item[1])
    page.wait_for_timeout(900)

    with page.expect_file_chooser(timeout=25000) as fc:
        page.get_by_role("menuitem", name="Place image", exact=False).click()
    fc.value.set_files(str(svg_path))
    page.wait_for_timeout(2500)

    # the placement cursor is armed: click once to drop it
    page.mouse.click(CLICK_X, CLICK_Y)
    page.wait_for_timeout(7000)


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

        for fname, _x in ITEMS:
            path = SVG / fname
            if not path.exists():
                print("missing", fname)
                continue
            place(page, path)
            print("placed", fname)
            page.screenshot(path=str(ROOT / "renders" / f"figma-{fname.replace('.svg','')}.png"))

        page.screenshot(path=str(ROOT / "renders" / "figma-all.png"))
        print("screenshot: renders/figma-all.png")
        browser.close()
        return 0


if __name__ == "__main__":
    sys.exit(main())
