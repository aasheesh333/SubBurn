#!/usr/bin/env python3
"""
SubBurn — render pipeline.

Outputs
  renders/board.png            all 4 frames, 48px gap          (@2x)
  renders/frame-1..4.png       single frame 393x852             (@3x)
  renders/receipt-card.png     isolated 9:16 card 1080x1920     (@3x)


Run:  python3 tools/render.py
"""
import json
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = (ROOT / "index.html").as_uri()
OUT = ROOT / "renders"
OUT.mkdir(parents=True, exist_ok=True)


def settle(page):
    page.wait_for_load_state("networkidle")
    page.evaluate("document.fonts.ready")
    page.wait_for_timeout(250)


def main():
    failures = []
    with sync_playwright() as p:
        # system Chrome (no bundled chromium on this box)
        browser = p.chromium.launch(channel="chrome", args=["--no-sandbox"])

        # ---------- board ----------
        page = browser.new_page(viewport={"width": 1800, "height": 1100},
                                device_scale_factor=2)
        page.goto(URL)
        settle(page)

        audit = page.evaluate("window.__audit()")
        print(json.dumps(audit, indent=2))
        for row in audit:
            if row["overflow"] > 0:
                failures.append(f"{row['id']} overflows by {row['overflow']}px")

        page.screenshot(path=str(OUT / "board.png"), full_page=True)

        # ---------- single frames @3x ----------
        for n in (1, 2, 3, 4):
            f = browser.new_page(viewport={"width": 393, "height": 852},
                                 device_scale_factor=3)
            f.goto(URL + f"?export=frame&n={n}")
            settle(f)
            f.screenshot(path=str(OUT / f"frame-{n}.png"))
            f.close()

        # ---------- receipt card, exact 1080x1920 ----------
        r = browser.new_page(viewport={"width": 360, "height": 640},
                             device_scale_factor=3)
        r.goto(URL + "?export=receipt")
        settle(r)
        card = r.locator("#receipt-export .receipt")
        box = card.bounding_box()
        print("receipt box:", box)
        card.screenshot(path=str(OUT / "receipt-card.png"))
        r.close()

        browser.close()

    from PIL import Image
    for name in ("board.png", "receipt-card.png"):
        im = Image.open(OUT / name)
        print(f"{name}: {im.size}")

    if failures:
        print("\nLAYOUT FAILURES:")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("\nlayout audit: clean")


if __name__ == "__main__":
    main()
