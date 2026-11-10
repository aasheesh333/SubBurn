#!/usr/bin/env python3
"""Generate the SubBurn launcher icon set.

Source of truth is the same flame path used in the app (`SbHeader` logo), drawn
here as SVG and rasterised with Playwright, so the launcher, the splash and the
in-app mark can never drift apart.

Outputs (Android):
  mipmap-*/ic_launcher.png             legacy square (48..192 px)
  mipmap-*/ic_launcher_round.png       legacy round
  mipmap-anydpi-v26/ic_launcher.xml    adaptive icon (API 26+)
  mipmap-anydpi-v26/ic_launcher_round.xml
  drawable-*/ic_launcher_foreground.png  adaptive foreground (108 dp grid)
  values/ic_launcher_background.xml    background colour
  drawable-*/ic_launcher_monochrome.png  Android 13 themed icon

Also writes the Play Store asset:
  renders/store/icon-512.png           512 x 512, no transparency

Run:  python3 tools/gen_app_icon.py
"""
from __future__ import annotations

import pathlib

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
RES = ROOT / "flutter" / "android" / "app" / "src" / "main" / "res"
STORE = ROOT / "renders" / "store"

# The flame path from the app logo (24 x 24 viewBox).
FLAME = (
    "M12.6 2.2c1 3.5-.6 5.2-2.3 6.9-1.8 1.8-3.2 3.4-3.2 5.9"
    "a5.9 5.9 0 0 0 11.8 0c0-2.3-1-3.7-2.2-5-.3 1-.9 2-1.9 2.6"
    ".6-3-.7-6.5-2.2-10.4Z"
)

DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def svg(size: int, *, round_icon: bool = False, with_bg: bool = True,
        mark_only: bool = False, monochrome: bool = False) -> str:
    """One icon, parameterised. Radius is 22.5 % of the size, matching the
    Squircle look in the design (device radius 46 on a 393 wide frame)."""
    r = size / 2 if round_icon else size * 0.225
    bg = "" if (monochrome or mark_only) else f"""
      <defs>
        <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#FF4500"/>
          <stop offset="1" stop-color="#FF8C00"/>
        </linearGradient>
      </defs>
      <rect width="{size}" height="{size}" rx="{r}" fill="url(#g)"/>"""
    if not with_bg and not monochrome:
        bg = ""

    # Mark occupies 52 % of the canvas; on an adaptive foreground the safe zone
    # is the centre 66 dp of a 108 dp grid.
    scale = size * (0.52 if not mark_only else 0.62)
    offset = (size - 24 * (scale / 24)) / 2
    fill = "#FFFFFF" if monochrome else "#1A0800"
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}"
     viewBox="0 0 {size} {size}">{bg}
  <g transform="translate({offset}, {offset}) scale({scale/24})">
    <path d="{FLAME}" fill="{fill}"/>
  </g>
</svg>"""


def render(page, svg_text: str, out: pathlib.Path, size: int,
           transparent: bool = False) -> None:
    page.set_viewport_size({"width": size, "height": size})
    page.set_content(
        f"<html><body style='margin:0;background:{'transparent' if transparent else 'none'}'>"
        f"{svg_text}</body></html>"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(out), omit_background=transparent)


def main() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", args=["--no-sandbox"])
        page = browser.new_page(device_scale_factor=1)

        for density, px in DENSITIES.items():
            folder = RES / f"mipmap-{density}"
            render(page, svg(px), folder / "ic_launcher.png", px)
            render(
                page,
                svg(px, round_icon=True),
                folder / "ic_launcher_round.png",
                px,
            )

            # Adaptive foreground: 108 dp grid, mark inside the 66 dp safe zone.
            fg_px = int(px * 108 / 48)
            render(
                page,
                svg(fg_px, with_bg=False, mark_only=True),
                RES / f"drawable-{density}" / "ic_launcher_foreground.png",
                fg_px,
                transparent=True,
            )
            render(
                page,
                svg(fg_px, monochrome=True, mark_only=True),
                RES / f"drawable-{density}" / "ic_launcher_monochrome.png",
                fg_px,
                transparent=True,
            )

        # Play Store icon: 512, opaque, no rounding baked in.
        render(page, svg(512), STORE / "icon-512.png", 512)
        # In-app / website mark.
        render(page, svg(256), STORE / "mark-256.png", 256)

        browser.close()

    # Adaptive icon XML (API 26+), monochrome layer for Android 13 themed icons.
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for name, ref in (
        ("ic_launcher", "@mipmap/ic_launcher"),
        ("ic_launcher_round", "@mipmap/ic_launcher_round"),
    ):
        (anydpi / f"{name}.xml").write_text(
            f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""
        )

    (RES / "values" / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FF4500</color>
</resources>
"""
    )
    print("wrote launcher icons, adaptive XML and store assets")


if __name__ == "__main__":
    main()
