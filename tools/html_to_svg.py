#!/usr/bin/env python3
"""
HTML -> SVG extractor for the SubBurn frames.

Why this exists
---------------
Figma's web editor does not expose "Import plugin from manifest…" (that menu item
only exists in the desktop app, and the desktop build needs a second Google 2FA
round to sign in). Pasting SVG onto the canvas *does* work in the web editor and
produces real, editable Figma layers, so we generate one SVG per frame straight
from the live DOM of index.html — the same source the PNGs are rendered from.

The walker emits a flat display list:
  • every visible element with a background  -> <rect> (with rx)
  • every text node                          -> <text>
  • linear/radial gradients are parsed into real <linearGradient>/<radialGradient>
  • overflow:hidden + radius                 -> <clipPath>

Output: renders/svg/frame-1.svg … frame-4.svg
Run:    python3 tools/html_to_svg.py
"""
import base64
import json
import pathlib
import re

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "renders" / "svg"
OUT.mkdir(parents=True, exist_ok=True)

FONT_DIR = ROOT / "assets" / "fonts" / "build"


def font_face(family: str, weight: int, filename: str) -> str:
    """Inline the WOFF2 so the SVG is self-contained (Figma keeps the family)."""
    path = FONT_DIR / filename
    if not path.exists():
        return ""
    b64 = base64.b64encode(path.read_bytes()).decode()
    return (
        "@font-face{font-family:'" + family + "';font-style:normal;"
        "font-weight:" + str(weight) + ";"
        "src:url(data:font/woff2;base64," + b64 + ") format('woff2');}"
    )


def all_font_faces() -> str:
    out = []
    for w in (400, 500, 600, 700, 800):
        out.append(font_face("Plus Jakarta Sans", w, f"pjs-{w}.woff2"))
    for w in (400, 500, 600, 700):
        out.append(font_face("JetBrains Mono", w, f"jbm-{w}.woff2"))
    return "".join(f for f in out if f)

COLLECT = r"""
(sel) => {
  const screen = document.querySelector(sel);
  if (!screen) return { error: 'no node: ' + sel };
  const sr = screen.getBoundingClientRect();

  const parseColor = (c) => {
    const m = c && c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(',').map(Number);
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  };
  const hex = (c) =>
    '#' + [c.r, c.g, c.b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('');

  const cumScale = (el) => {
    let sx = 1, sy = 1, n = el;
    while (n && n !== document.documentElement) {
      const t = getComputedStyle(n).transform;
      if (t && t !== 'none') {
        try {
          const m = new DOMMatrixReadOnly(t);
          sx *= Math.hypot(m.a, m.b) || 1;
          sy *= Math.hypot(m.c, m.d) || 1;
        } catch (e) {}
      }
      n = n.parentElement;
    }
    return { sx, sy };
  };

  const items = [];
  const texts = [];
  const icons = [];
  let activeClip = null;
  let clipId = 0;
  const clips = [];

  const walk = (el, depth) => {
    if (depth > 22) return;
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || parseFloat(cs.opacity) === 0) return;

    const r = el.getBoundingClientRect();
    const inside = r.width > 0 && r.height > 0 &&
                   r.right > sr.left - 2 && r.left < sr.right + 2 &&
                   r.bottom > sr.top - 2 && r.top < sr.bottom + 2;

    if (inside) {
      const bg = parseColor(cs.backgroundColor);
      const bgi = cs.backgroundImage;
      const radius = parseFloat(cs.borderTopLeftRadius) || 0;
      const bw = parseFloat(cs.borderTopWidth) || 0;
      const bc = parseColor(cs.borderTopColor);

      // background-clip:text means the gradient *is* the glyph fill, not a box
      const clipText = (cs.webkitBackgroundClip || cs.backgroundClip || '').includes('text');
      if (((bg && bg.a > 0.005) || bgi !== 'none') && !clipText) {
        items.push({
          clip: activeClip,
          x: r.left - sr.left, y: r.top - sr.top, w: r.width, h: r.height,
          rx: radius * cumScale(el).sx, fill: bg ? { ...bg, hex: hex(bg) } : null,
          bgImage: bgi !== 'none' ? bgi : null,
          stroke: bw > 0 && bc ? { ...bc, hex: hex(bc), w: bw } : null,
          dashed: cs.borderTopStyle === 'dashed',
          opacity: parseFloat(cs.opacity)
        });
      }

      // Clipping container: any element that hides overflow becomes a clip
      // region, so scaled/positioned children can't spill into the frame.
      if (cs.overflow === 'hidden' || cs.overflow === 'clip') {
        const id = 'clip' + (clipId++);
        clips.push({ id, x: r.left - sr.left, y: r.top - sr.top, w: r.width, h: r.height, rx: radius });
        activeClip = id;
      }
    }

    // inline SVG icons -> real path geometry
    if (el.tagName.toLowerCase() === 'svg' && inside) {
      const vb = (el.getAttribute('viewBox') || '').split(/[\s,]+/).map(Number);
      const iw = r.width || (vb[2] || 24);
      const ih = r.height || (vb[3] || 24);
      const sx = vb[2] ? iw / vb[2] : 1;
      const sy = vb[3] ? ih / vb[3] : 1;
      const paths = [];
      el.querySelectorAll('path, circle, rect, line, polyline').forEach(node => {
        const tag = node.tagName.toLowerCase();
        if (tag === 'path') {
          paths.push({ d: node.getAttribute('d'), fill: node.getAttribute('fill'), stroke: node.getAttribute('stroke'),
                       sw: node.getAttribute('stroke-width'), cap: node.getAttribute('stroke-linecap'),
                       join: node.getAttribute('stroke-linejoin'), op: node.getAttribute('stroke-opacity'),
                       fop: node.getAttribute('fill-opacity') });
        } else if (tag === 'circle') {
          const cx = +node.getAttribute('cx'), cy = +node.getAttribute('cy'), rr = +node.getAttribute('r');
          paths.push({ d: `M ${cx-rr} ${cy} a ${rr} ${rr} 0 1 0 ${rr*2} 0 a ${rr} ${rr} 0 1 0 ${-rr*2} 0`,
                       fill: node.getAttribute('fill'), stroke: node.getAttribute('stroke'),
                       sw: node.getAttribute('stroke-width'), fop: node.getAttribute('fill-opacity'), op: null, cap:null, join:null });
        } else if (tag === 'rect') {
          const x = +node.getAttribute('x'), y = +node.getAttribute('y');
          const w2 = +node.getAttribute('width'), h2 = +node.getAttribute('height');
          const rx2 = +(node.getAttribute('rx') || 0);
          paths.push({ d: `M ${x+rx2} ${y} h ${w2-2*rx2} a ${rx2} ${rx2} 0 0 1 ${rx2} ${rx2} v ${h2-2*rx2} a ${rx2} ${rx2} 0 0 1 ${-rx2} ${rx2} h ${-(w2-2*rx2)} a ${rx2} ${rx2} 0 0 1 ${-rx2} ${-rx2} v ${-(h2-2*rx2)} a ${rx2} ${rx2} 0 0 1 ${rx2} ${-rx2} z`,
                       fill: node.getAttribute('fill'), stroke: node.getAttribute('stroke'),
                       sw: node.getAttribute('stroke-width'), fop: node.getAttribute('fill-opacity'), op: node.getAttribute('stroke-opacity'), cap:null, join:null });
        }
      });
      if (paths.length) {
        icons.push({
          clip: activeClip,
          x: r.left - sr.left, y: r.top - sr.top,
          sx, sy,
          baseStroke: cs.color,
          paths
        });
      }
    }

    // text: measure each contiguous run of text nodes with a Range so that
    // flex/inline layouts put the glyphs exactly where the browser does.
    if (inside && el.tagName.toLowerCase() !== 'svg') {
      const nodes = [...el.childNodes].filter(
        c => c.nodeType === 3 && c.textContent.trim()
      );
      if (nodes.length) {
        const sc = cumScale(el);
        for (const node of nodes) {
          const txt = node.textContent.replace(/\s+/g, ' ').trim();
          if (!txt) continue;

          const range = document.createRange();
          range.selectNodeContents(node);
          // walk past leading whitespace so the box is the visible run
          const b = range.getBoundingClientRect();
          if (!b.width) continue;

          const lh = (parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.2) * sc.sy;
          const fs = parseFloat(cs.fontSize) * sc.sy;
          const ascent = fs * 0.78;
          const baseY = b.top - sr.top + b.height / 2 + ascent * 0.72;

          const clipText = (cs.webkitBackgroundClip || cs.backgroundClip || '').includes('text');
          const fillColor = clipText ? { r: 255, g: 255, b: 255, a: 1, hex: '#ffffff' }
                                     : parseColor(cs.color);

          texts.push({
            clip: activeClip,
            text: txt,
            x: b.left - sr.left,
            y: baseY,
            anchor: 'start',
            size: fs,
            weight: cs.fontWeight,
            family: cs.fontFamily.split(',')[0].replace(/['"]/g, '').trim(),
            spacing: (parseFloat(cs.letterSpacing) || 0),
            fill: fillColor,
            gradientText: clipText && cs.backgroundImage !== 'none' ? cs.backgroundImage : null,
            box: { x: b.left - sr.left, y: b.top - sr.top, w: b.width, h: b.height },
            opacity: parseFloat(cs.opacity),
            upper: cs.textTransform === 'uppercase'
          });
        }
      }
    }

    const parentClip = activeClip;
    if (cs.overflow === 'hidden' || cs.overflow === 'clip') {
      // children inherit this clip; restore the ancestor afterwards
    }
    for (const c of el.children) walk(c, depth + 1);
    activeClip = parentClip;
  };

  walk(screen, 0);
  return { width: sr.width, height: sr.height, items, texts, clips, icons };
}
"""


def parse_gradient(css: str):
    """Turn a CSS linear/radial gradient into an SVG gradient definition."""
    if not css or "gradient" not in css:
        return None

    stops = []
    for m in re.finditer(r"rgba?\(([^)]+)\)\s*([\d.]+%)?", css):
        p = [float(v) for v in m.group(1).split(",")]
        col = {"r": p[0], "g": p[1], "b": p[2], "a": p[3] if len(p) > 3 else 1.0}
        col["hex"] = "#" + "".join(f"{int(v):02x}" for v in p[:3])
        stops.append((col, m.group(2)))
    if not stops:
        return None

    n = len(stops)
    out = []
    for i, (col, at) in enumerate(stops):
        pos = float(at.rstrip("%")) / 100 if at else i / max(1, n - 1)
        out.append((pos, col))

    angle_m = re.search(r"linear-gradient\(\s*([\d.]+)deg", css)
    if "radial" in css:
        return {"kind": "radial", "stops": out}

    angle = float(angle_m.group(1)) if angle_m else 180.0
    # CSS angle: 0deg = to top, 90deg = to right. Convert to unit box coords.
    import math

    rad = math.radians(angle)
    dx, dy = math.sin(rad), -math.cos(rad)
    x1, y1 = 0.5 - dx / 2, 0.5 - dy / 2
    x2, y2 = 0.5 + dx / 2, 0.5 + dy / 2
    return {"kind": "linear", "x1": x1, "y1": y1, "x2": x2, "y2": y2, "stops": out}


def esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def build_svg(data) -> str:
    W, H = data["width"], data["height"]
    defs, body = [], []
    gcount = 0

    for c in data["clips"]:
        defs.append(
            f'<clipPath id="{c["id"]}"><rect x="{c["x"]:.2f}" y="{c["y"]:.2f}" '
            f'width="{c["w"]:.2f}" height="{c["h"]:.2f}" rx="{c["rx"]:.2f}"/></clipPath>'
        )

    for it in data["items"]:
        fill = "none"
        g = parse_gradient(it.get("bgImage") or "")
        if g:
            gid = f"g{gcount}"
            gcount += 1
            stops = "".join(
                f'<stop offset="{p:.4f}" stop-color="{col["hex"]}" stop-opacity="{col["a"]}"/>'
                for p, col in g["stops"]
            )
            if g["kind"] == "linear":
                defs.append(
                    f'<linearGradient id="{gid}" x1="{g["x1"]:.3f}" y1="{g["y1"]:.3f}" '
                    f'x2="{g["x2"]:.3f}" y2="{g["y2"]:.3f}">{stops}</linearGradient>'
                )
            else:
                defs.append(f'<radialGradient id="{gid}">{stops}</radialGradient>')
            fill = f"url(#{gid})"
        elif it.get("fill") and it["fill"]["a"] > 0:
            fill = it["fill"]["hex"]
            if it["fill"]["a"] < 1:
                body.append(
                    f'<rect x="{it["x"]:.2f}" y="{it["y"]:.2f}" width="{it["w"]:.2f}" '
                    f'height="{it["h"]:.2f}" rx="{it["rx"]:.2f}" fill="{fill}" '
                    f'opacity="{it["fill"]["a"]:.3f}"/>'
                )
                continue

        if fill == "none" and not it.get("stroke"):
            continue

        stroke = ""
        if it.get("stroke"):
            dash = ' stroke-dasharray="4 3"' if it["dashed"] else ""
            stroke = (
                f' stroke="{it["stroke"]["hex"]}" stroke-width="{it["stroke"]["w"]}"'
                f' stroke-opacity="{it["stroke"]["a"]:.3f}"{dash}'
            )

        clip = f' clip-path="url(#{it["clip"]})"' if it.get("clip") else ""
        body.append(
            f'<rect x="{it["x"]:.2f}" y="{it["y"]:.2f}" width="{it["w"]:.2f}" '
            f'height="{it["h"]:.2f}" rx="{it["rx"]:.2f}" fill="{fill}"{stroke}{clip}/>'
        )

    for t in data["texts"]:
        txt = t["text"]
        if t.get("upper"):
            txt = txt.upper()
        f = t.get("fill")
        fill = f.get("hex", "#ffffff") if f else "#ffffff"
        opacity = f.get("a", 1.0) if f else 1.0

        if t.get("gradientText"):
            g = parse_gradient(t["gradientText"])
            if g:
                gid = f"g{gcount}"
                gcount += 1
                stops = "".join(
                    f'<stop offset="{p:.4f}" stop-color="{col["hex"]}" stop-opacity="1"/>'
                    for p, col in g["stops"]
                )
                bx = t.get("box") or {"x": 0, "y": 0, "w": 100, "h": 30}
                defs.append(
                    f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
                    f'x1="{bx["x"]:.1f}" y1="{bx["y"]:.1f}" '
                    f'x2="{bx["x"]:.1f}" y2="{bx["y"] + bx["h"]:.1f}">{stops}</linearGradient>'
                )
                fill = f"url(#{gid})"

        weight = t["weight"]
        # Text is deliberately NOT clipped: Figma imports clipped text as a
        # vector mask, which makes the layer uneditable. The export containers
        # are sized so text never spills anyway.
        body.append(
            f'<text x="{t["x"]:.2f}" y="{t["y"]:.2f}" font-family="{esc(t["family"])}" '
            f'font-size="{t["size"]:.1f}" font-weight="{weight}" '
            f'letter-spacing="{t["spacing"]:.2f}" fill="{fill}" opacity="{opacity:.3f}" '
            f'text-anchor="{t["anchor"]}">{esc(txt)}</text>'
        )

    for ic in data.get("icons", []):
        inner = []
        for pa in ic["paths"]:
            d = pa.get("d")
            if not d:
                continue
            f = pa.get("fill")
            stk = pa.get("stroke")
            attrs = []
            if f and f not in ("none", ""):
                attrs.append(f'fill="{f}"')
                if pa.get("fop"):
                    attrs.append(f'fill-opacity="{pa["fop"]}"')
            else:
                attrs.append('fill="none"')
            if stk and stk not in ("none", ""):
                col = stk if stk.startswith("#") else ic["baseStroke"]
                attrs.append(f'stroke="{col}" stroke-width="{pa.get("sw") or 1.6}"')
                if pa.get("cap"):
                    attrs.append(f'stroke-linecap="{pa["cap"]}"')
                if pa.get("join"):
                    attrs.append(f'stroke-linejoin="{pa["join"]}"')
                if pa.get("op"):
                    attrs.append(f'stroke-opacity="{pa["op"]}"')
            inner.append(f'<path d="{d}" {" ".join(attrs)}/>')

        if inner:
            body.append(
                f'<g transform="translate({ic["x"]:.2f},{ic["y"]:.2f}) scale({ic["sx"]:.4f},{ic["sy"]:.4f})">'
                + "".join(inner) + "</g>"
            )

    style = "<style>" + all_font_faces() + "</style>"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">'
        f"<defs>{''.join(defs)}{style}</defs>"
        f'<rect width="{W}" height="{H}" fill="#09090B"/>'
        f"{''.join(body)}</svg>"
    )


def main():
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", args=["--no-sandbox"])
        page = b.new_page(viewport={"width": 393, "height": 852}, device_scale_factor=1)
        for n in (1, 2, 3, 4):
            page.goto(f"{(ROOT / 'index.html').as_uri()}?export=frame&n={n}")
            page.wait_for_load_state("networkidle")
            page.evaluate("document.fonts.ready")
            page.wait_for_timeout(400)
            data = page.evaluate(COLLECT,
                                 f'.frame-wrap[data-f="{n}"] .screen')
            if "error" in data:
                print(n, data)
                continue
            svg = build_svg(data)
            f = OUT / f"frame-{n}.svg"
            f.write_text(svg)
            print(f"frame-{n}.svg  {len(svg)/1024:.1f} KB  "
                  f"{len(data['items'])} shapes  {len(data['texts'])} texts")

        # --- the isolated 9:16 receipt, standalone (maps to RepaintBoundary) ---
        page.goto(f"{(ROOT / 'index.html').as_uri()}?export=receipt")
        page.wait_for_load_state("networkidle")
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(400)
        data = page.evaluate(COLLECT, '#receipt-export .receipt')
        svg = build_svg(data)
        f = OUT / "receipt-card.svg"
        f.write_text(svg)
        print(f"receipt-card.svg  {len(svg)/1024:.1f} KB  "
              f"{len(data['items'])} shapes  {len(data['texts'])} texts")
        b.close()


if __name__ == "__main__":
    main()
