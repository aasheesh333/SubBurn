#!/usr/bin/env python3
"""
Paste the generated SVGs into the SubBurn Figma file.

Figma's web editor has no "Import plugin from manifest…" item, but it *does*
accept SVG on the clipboard: paste creates real, editable vector + text layers.
This script:

  1. connects to the isolated Chrome (port 9333) that is signed in as the user
  2. opens ONLY the SubBurn file (no other project is touched)
  3. writes the SVG to the X11 clipboard
  4. focuses the canvas and pastes
  5. positions the pasted frame and labels it

    python3 tools/paste_to_figma.py
"""
import os
import pathlib
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
SVG_DIR = ROOT / "renders" / "svg"
FILE_URL = "https://www.figma.com/design/6jVmqh8BbfJl4cQoLz1WsY/SubBurn"
CDP = "http://127.0.0.1:9333"

FRAMES = [
    ("frame-1.svg", "01 · Burn Dashboard"),
    ("frame-2.svg", "02 · Quick Add"),
    ("frame-3.svg", "03 · Card Studio"),
    ("frame-4.svg", "04 · Renewal & Kill-Switch"),
    ("receipt-card.svg", "03a · Receipt (360x640 export)"),
]


DISPLAY = ":1"  # the X display Chrome runs on (VNC :1)


def copy_svg(path: pathlib.Path):
    """Put the SVG markup on the clipboard as image/svg+xml.

    Figma's paste handler keys off the clipboard target type; text/plain would
    be pasted as an inert text layer, so we insist on the SVG flavour.
    """
    markup = path.read_text()
    env = {**os.environ, "DISPLAY": DISPLAY}
    proc = subprocess.run(
        ["xclip", "-selection", "clipboard", "-t", "image/svg+xml", "-i", "-"],
        input=markup.encode(),
        capture_output=True,
        env=env,
    )
    return proc.returncode


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        ctx = browser.contexts[0]
        page = ctx.pages[0] if ctx.pages else ctx.new_page()

        page.goto(FILE_URL, wait_until="domcontentloaded", timeout=120000)
        page.wait_for_selector('canvas', timeout=120000)
        page.wait_for_timeout(5000)
        print("open:", page.title())

        # Deselect everything so a paste lands on the page, not inside a group.
        page.keyboard.press("Escape")
        page.wait_for_timeout(400)

        x = 60
        for fname, label in FRAMES:
            path = SVG_DIR / fname
            if not path.exists():
                print("missing", fname)
                continue

            rc = copy_svg(path)
            print(f"clipboard <- {fname} (rc={rc})")
            time.sleep(0.6)

            # click empty canvas area, then paste
            page.mouse.click(700, 260)
            page.wait_for_timeout(500)
            page.keyboard.press("Control+v")
            page.wait_for_timeout(6000)

            page.screenshot(path=str(ROOT / "renders" / f"paste-{fname}.png"))
            print("  pasted", fname)

        page.wait_for_timeout(3000)
        page.screenshot(path=str(ROOT / "renders" / "figma-final.png"))
        print("final screenshot: renders/figma-final.png")
        browser.close()
        return 0


if __name__ == "__main__":
    sys.exit(main())
