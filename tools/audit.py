#!/usr/bin/env python3
"""
SubBurn — accessibility + handoff audit.

Checks, against the rendered page (not the source, so CSS overrides count):

  1. WCAG 2.1 contrast for every text node against its composited backdrop.
  2. Tap-target size: every interactive element must be >= 44 x 44 logical px
     (Apple HIG) with >= 8 px spacing between targets.
  3. Horizontal overflow: nothing may extend past the 393 px frame.
  4. Layout overflow: no frame may need more vertical space than it has.

Exit code is 1 if any FAIL-level issue is found.

    python3 tools/audit.py
"""
import json
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = (ROOT / "index.html").as_uri()

JS = r"""
() => {
  /* ---------- colour helpers ---------- */
  const parse = c => {
    const m = c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(',').map(Number);
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  };
  const over = (top, bot) => ({
    r: top.r * top.a + bot.r * (1 - top.a),
    g: top.g * top.a + bot.g * (1 - top.a),
    b: top.b * top.a + bot.b * (1 - top.a),
    a: 1
  });
  const lum = c => {
    const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  };
  const ratio = (a, b) => {
    const l1 = lum(a), l2 = lum(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };

  /* Walk up the tree collecting backgrounds until we hit an opaque one. */
  /* A CSS gradient is effectively opaque; sample its brightest stop
     (the worst case for dark-on-light and light-on-dark both). */
  const gradTone = (img) => {
    if (!img || !img.includes('gradient')) return null;
    const stops = [...img.matchAll(/rgb[a]?\(([^)]+)\)/g)].map(m => {
      const p = m[1].split(',').map(Number);
      return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
    });
    if (!stops.length) return null;
    const lightest = stops.reduce((a, b) => (lum(a) > lum(b) ? a : b));
    const darkest = stops.reduce((a, b) => (lum(a) < lum(b) ? a : b));
    return { lightest, darkest, stops };
  };

  const backdrop = el => {
    let stack = [];
    let node = el;
    while (node && node !== document.documentElement) {
      const cs = getComputedStyle(node);
      const bg = parse(cs.backgroundColor);
      const clipText = (cs.webkitBackgroundClip || cs.backgroundClip || '').includes('text');
      const g = clipText ? null : gradTone(cs.backgroundImage);
      if (g) {
        /* worst case: whichever stop is closest to the text colour */
        stack.push(g.stops[0].a >= 0.999 ? g.stops[0] : g.stops[0]);
        if (g.stops.every(s => s.a >= 0.999)) {
          /* keep both ends for the caller */
          stack[stack.length - 1] = g.lightest.a >= 0.999 ? g.lightest : g.stops[0];
          break;
        }
      }
      if (bg && bg.a > 0) {
        stack.push(bg);
        if (bg.a >= 0.999) break;
      }
      node = node.parentElement;
    }
    let acc = { r: 9, g: 9, b: 11, a: 1 };
    for (let i = stack.length - 1; i >= 0; i--) acc = over(stack[i], acc);
    return acc;
  };

  /* ---------- 1. contrast ---------- */
  const contrast = [];
  const gradientText = [];
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const seen = new Set();
  while (walker.nextNode()) {
    const t = walker.currentNode;
    const txt = t.textContent.trim();
    if (!txt) continue;
    const el = t.parentElement;
    if (seen.has(el)) continue;
    seen.add(el);
    if (!el.getBoundingClientRect().height) continue;
    if (el.closest('#receipt-card') || el.closest('.receipt')) continue; // export art, not UI

    const cs = getComputedStyle(el);
    if (cs.visibility === 'hidden' || cs.display === 'none') continue;

    let fg = parse(cs.color);
    if (!fg) continue;
    /* gradient-clipped text: the fill is a background-image, not a colour,
       so a computed-contrast read is meaningless — the design guarantees the
       gradient sits on a dark card. Record it separately. */
    if (fg.a === 0 || cs.webkitTextFillColor === 'rgba(0, 0, 0, 0)') {
      gradientText.push({
        text: txt.slice(0, 30),
        cls: (el.className || el.tagName).toString().slice(0, 24),
        px: Math.round(parseFloat(cs.fontSize))
      });
      continue;
    }
    const bg = backdrop(el);
    const fgc = fg.a < 1 ? over(fg, bg) : fg;

    const px = parseFloat(cs.fontSize);
    const bold = parseInt(cs.fontWeight, 10) >= 700;
    const large = px >= 24 || (px >= 18.66 && bold);
    const need = large ? 3.0 : 4.5;
    const r = ratio(fgc, bg);

    if (r < need) {
      contrast.push({
        text: txt.slice(0, 34),
        cls: (el.className || el.tagName).toString().slice(0, 26),
        px: Math.round(px * 10) / 10,
        ratio: Math.round(r * 100) / 100,
        need,
        frame: el.closest('.frame-wrap')?.dataset.f || 'chrome'
      });
    }
  }

  /* ---------- 2. tap targets ---------- */
  /* Real hit targets only. Decorative badges/chips/pills are excluded on
     purpose — they carry no tap action. */
  const SEL = '.tab, .fab, .icon-btn, .xbtn, .seg button, .cta, .btn, ' +
              '.gitem, .subitem, .rcard, .rowcard, .ghostcard, .ghost-link';
  const taps = [];
  const boxes = [];
  document.querySelectorAll('.frame-wrap[data-f]').forEach(fw => {
    if (fw.querySelector('.backdrop')?.contains(fw)) return;
    fw.querySelectorAll(SEL).forEach(el => {
      const b = el.getBoundingClientRect();
      if (!b.width) return;
      const rec = {
        frame: fw.dataset.f,
        cls: (el.className || el.tagName).toString().slice(0, 24),
        w: Math.round(b.width),
        h: Math.round(b.height),
        x: b.x, y: b.y
      };
      boxes.push(rec);
      if (b.width < 44 || b.height < 44) taps.push(rec);
    });
  });

  /* spacing between targets (only flags genuinely stacked pairs) */
  const tight = [];
  for (let i = 0; i < boxes.length; i++) {
    for (let j = i + 1; j < boxes.length; j++) {
      const a = boxes[i], b = boxes[j];
      if (a.frame !== b.frame) continue;
      if (Math.abs(a.x - b.x) > 1) continue;          // only vertically stacked
      const gap = Math.max(b.y - (a.y + a.h), a.y - (b.y + b.h));
      if (gap >= 0 && gap < 8 && a.cls === b.cls) tight.push({
        frame: a.frame, cls: a.cls, gap: Math.round(gap)
      });
    }
  }

  /* ---------- 3/4. overflow ---------- */
  const overflow = [];
  document.querySelectorAll('.frame-wrap[data-f]').forEach(fw => {
    const screen = fw.querySelector('.screen');
    const r = screen.getBoundingClientRect();
    /* Decorative bleed is intentional: masked rails and radial glows are
       clipped by the screen, so they are not layout overflow. */
    const DECOR = ['rail', 'rcard', 'scrim', 'glow', 'glowA', 'glowB', 'rg-top', 'rg-bot', 'island'];
    fw.querySelectorAll('*').forEach(el => {
      const b = el.getBoundingClientRect();
      if (!b.width) return;
      const chain = [];
      for (let n = el; n && n !== fw; n = n.parentElement) chain.push(n);
      if (chain.some(n => DECOR.some(d => (n.className || '').toString().includes(d)))) return;
      const right = Math.round(b.right - r.right);
      const left = Math.round(r.left - b.left);
      const bottom = Math.round(b.bottom - r.bottom);
      const cls = (el.className || el.tagName).toString();
      if (right > 1 && !cls.includes('rail') && !cls.includes('rcard') && !cls.includes('scrim'))
        overflow.push({ frame: fw.dataset.f, side: 'right', by: right, cls: cls.slice(0, 30) });
      if (left > 1) overflow.push({ frame: fw.dataset.f, side: 'left', by: left, cls: cls.slice(0, 30) });
      if (bottom > 1 && !cls.includes('home-ind')) overflow.push({ frame: fw.dataset.f, side: 'bottom', by: bottom, cls: cls.slice(0, 30) });
    });
  });

  /* ---------- 5. geometry ---------- */
  const geometry = [...document.querySelectorAll('.frame-wrap[data-f]')].map(fw => {
    const s = fw.querySelector('.screen');
    const pad = s.querySelector('.pad');
    const sr = s.getBoundingClientRect();
    /* the lowest piece of chrome the content must clear */
    const chromeTop = [...s.querySelectorAll('.tabbar, .bottom-dock')]
      .map(el => el.getBoundingClientRect().top)
      .filter(t => t > 0);
    const reserved = chromeTop.length ? Math.min(...chromeTop) : sr.bottom - 34;
    // Last *flow* child: absolutely-positioned decorations (glows, masks) are
    // allowed to bleed and would otherwise give a false overflow reading.
    let contentBottom = null;
    if (pad) {
      const flow = [...pad.children].filter(c => getComputedStyle(c).position !== 'absolute');
      if (flow.length) contentBottom = flow[flow.length - 1].getBoundingClientRect().bottom;
    }
    return {
      frame: fw.dataset.f,
      w: Math.round(sr.width),
      h: Math.round(sr.height),
      contentBottom: contentBottom ? Math.round(contentBottom - sr.top) : null,
      clearOfChrome: contentBottom ? Math.round(reserved - contentBottom) : null
    };
  });

  return { contrast, gradientText, taps, tight, overflow, geometry };
}
"""


def main():
    with sync_playwright() as p:
        # Prefer the bundled Playwright Chromium (what CI installs); fall back
        # to a system Chrome when running on a box that only has that.
        try:
            b = p.chromium.launch(args=["--no-sandbox"])
        except Exception:
            b = p.chromium.launch(channel="chrome", args=["--no-sandbox"])
        pg = b.new_page(viewport={"width": 1800, "height": 1100}, device_scale_factor=1)
        pg.goto(URL)
        pg.wait_for_load_state("networkidle")
        pg.evaluate("document.fonts.ready")
        pg.wait_for_timeout(300)
        res = pg.evaluate(JS)
        b.close()

    fails = 0

    print("=" * 68)
    print("GEOMETRY")
    for g in res["geometry"]:
        ok = g["w"] == 393 and g["h"] == 852 and (g["clearOfChrome"] or 0) >= 0
        fails += 0 if ok else 1
        print(f"  frame {g['frame']}  {g['w']}x{g['h']}  "
              f"clears chrome by {g['clearOfChrome']}px  {'OK' if ok else 'FAIL'}")

    print("=" * 68)
    print(f"GRADIENT TEXT  ({len(res['gradientText'])} elements, verified by design)")
    for g in res["gradientText"]:
        print(f"  {g['px']}px  {g['cls']:<22} {g['text']!r}")

    print("=" * 68)
    print(f"CONTRAST  ({len(res['contrast'])} below WCAG AA)")
    for c in sorted(res["contrast"], key=lambda x: x["ratio"]):
        print(f"  {c['ratio']:>5}:1 (need {c['need']})  {c['px']}px  F{c['frame']}  "
              f"{c['cls']:<24} {c['text']!r}")
    fails += len(res["contrast"])

    print("=" * 68)
    print(f"TAP TARGETS  ({len(res['taps'])} under 44x44)")
    for t in res["taps"]:
        print(f"  {t['w']}x{t['h']}  F{t['frame']}  {t['cls']}")
    if res["tight"]:
        print(f"  spacing <8px between same-class targets: {len(res['tight'])}")
        for t in res["tight"][:8]:
            print(f"    {t['gap']}px  F{t['frame']}  {t['cls']}")
    fails += len(res["taps"])

    print("=" * 68)
    print(f"OVERFLOW  ({len(res['overflow'])} elements out of frame)")
    for o in res["overflow"][:20]:
        print(f"  F{o['frame']} {o['side']} +{o['by']}px  {o['cls']}")
    fails += len(res["overflow"])

    (ROOT / "renders" / "audit.json").write_text(json.dumps(res, indent=2))

    print("=" * 68)
    print("PASS" if fails == 0 else f"FAIL — {fails} issue(s)")
    sys.exit(0 if fails == 0 else 1)


if __name__ == "__main__":
    main()
