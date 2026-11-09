#!/usr/bin/env python3
"""
SubBurn — font build.

Why this exists
---------------
JetBrains Mono has no U+20B9 (₹) glyph. The whole product is denominated in
rupees, so the hero number `₹4,850` would otherwise fall back to a random
system font at 52 px — visible, and ugly.

We therefore build two local, weight-instanced, subset WOFF2 families:

  * Plus Jakarta Sans  (UI)      400 / 500 / 600 / 700 / 800
  * JetBrains Mono     (numbers) 400 / 500 / 600 / 700
    + a single transplanted ₹ glyph (U+20B9) from Noto Sans Mono,
      centered in the 600-unit monospace advance and scaled to 0.94 em
      so its optical size matches the JBM digits.

Outputs -> assets/fonts/build/*.woff2  (a few KB each, deterministic)
Run:      python3 tools/build_fonts.py
"""
import pathlib
import urllib.request

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.woff2 import compress
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "fonts"
SRC_DIR = SRC / "src"
OUT = SRC / "build"
FLUTTER_FONTS = ROOT / "flutter" / "assets" / "fonts"
OUT.mkdir(parents=True, exist_ok=True)

UNICODES = (
    list(range(0x20, 0x7F))          # ASCII
    + [0x00A0, 0x00B7, 0x00D7, 0x2013, 0x2014, 0x2018, 0x2019,
       0x201C, 0x201D, 0x2022, 0x2026, 0x20B9, 0x2192, 0x2212, 0x2191,
       0x2193, 0x2713, 0x2715]
)

PJS_W = [400, 500, 600, 700, 800]
JBM_W = [400, 500, 600, 700]
RUPEE = 0x20B9


def fetch(url: str, dest: pathlib.Path) -> pathlib.Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists() or dest.stat().st_size < 1024:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as r, open(dest, "wb") as f:
            f.write(r.read())
    return dest


def add_rupee(ttf: TTFont, donor: TTFont, scale=0.94) -> bool:
    """Transplant U+20B9 from `donor` into `ttf`, centered in the mono advance."""
    dcmap = donor.getBestCmap()
    if RUPEE not in dcmap:
        return False

    gname = dcmap[RUPEE]
    dgs = donor.getGlyphSet()
    dadv = donor["hmtx"][gname][0]

    target_adv = ttf["hmtx"][ttf.getBestCmap()[ord("0")]][0]
    xoff = (target_adv - dadv * scale) / 2

    pen = TTGlyphPen(None)
    tpen = TransformPen(pen, (scale, 0, 0, scale, xoff, 0))
    dgs[gname].draw(tpen)

    new_name = "rupee.alt"
    ttf["glyf"][new_name] = pen.glyph()
    ttf["hmtx"][new_name] = (target_adv, int(round((target_adv - dadv * scale) / 2)))

    for table in ttf["cmap"].tables:
        if table.isUnicode() and table.format in (4, 12):
            table.cmap[RUPEE] = new_name

    # glyf appends to the glyph order for us; drop the stale reverse cache
    ttf._reverseGlyphOrderDict = {g: i for i, g in enumerate(ttf.getGlyphOrder())}
    return True


def subset(ttf: TTFont, unicodes) -> TTFont:
    from fontTools import subset as st

    opts = st.Options()
    opts.layout_features = ["tnum", "lnum", "kern", "liga", "calt", "ss01"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.recalc_bounds = True
    opts.drop_tables += ["DSIG"]
    subsetter = st.Subsetter(options=opts)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(ttf)
    return ttf


def save(ttf: TTFont, path: pathlib.Path):
    """Emit WOFF2 for the browser and TTF for Flutter from the same instance."""
    ttf.flavor = "woff2"
    ttf.save(str(path))
    ttf.flavor = None
    ttf_path = path.with_suffix(".ttf")
    import io
    ttf.save(str(ttf_path))
    print(f"  {path.name:26s} {path.stat().st_size/1024:6.1f} KB   "
          f"{ttf_path.name:26s} {ttf_path.stat().st_size/1024:6.1f} KB")


def main():
    pjs_src = fetch(
        "https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf",
        SRC_DIR / "PlusJakartaSans[wght].ttf",
    )
    jbm_src = fetch(
        "https://cdn.jsdelivr.net/gh/JetBrains/JetBrainsMono@master/fonts/variable/JetBrainsMono%5Bwght%5D.ttf",
        SRC_DIR / "JetBrainsMono[wght].ttf",
    )
    donor_src = fetch(
        "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansMono/NotoSansMono-Regular.ttf",
        SRC_DIR / "_NotoSansMono-Regular.ttf",
    )
    donor = TTFont(donor_src)

    print("Plus Jakarta Sans")
    for w in PJS_W:
        f = instantiateVariableFont(TTFont(pjs_src), {"wght": w})
        subset(f, UNICODES)
        save(f, OUT / f"pjs-{w}.woff2")

    print("JetBrains Mono (+ ₹)")
    for w in JBM_W:
        f = instantiateVariableFont(TTFont(jbm_src), {"wght": w})
        ok = add_rupee(f, donor)
        subset(f, UNICODES)
        save(f, OUT / f"jbm-{w}.woff2")
        if not ok:
            print("    !! rupee glyph missing")


if __name__ == "__main__":
    main()
    # mirror TTFs into the Flutter package
    FLUTTER_FONTS.mkdir(parents=True, exist_ok=True)
    for f in OUT.glob("*.ttf"):
        (FLUTTER_FONTS / f.name).write_bytes(f.read_bytes())
    print(f"copied {len(list(OUT.glob('*.ttf')))} TTF files -> flutter/assets/fonts")
