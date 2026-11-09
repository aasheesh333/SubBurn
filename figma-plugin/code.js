/* =============================================================================
   SubBurn Builder — Figma plugin
   -----------------------------------------------------------------------------
   Builds the complete 4-screen SubBurn design as real, editable Figma layers:

     • 393 x 852 frames, 48 px apart
     • strict auto-layout on every list and card
     • local color styles + text styles (a real design system, not flat art)
     • Frame 3's receipt isolated in its own 360 x 640 frame for
       RepaintBoundary-parity export

   Run: Plugins -> Development -> Import plugin from manifest... -> code.js
   ========================================================================== */

// ---------------------------------------------------------------------------
// 1. Tokens
// ---------------------------------------------------------------------------

const C = {
  bg: '#09090B',
  surface: '#121216',
  surfaceHi: '#17171C',
  border: '#27272A',
  borderHi: '#3F3F46',
  accent: '#FF4500',
  accentAlt: '#FF8C00',
  accentWarm: '#FFB27A',
  accentDeep: '#180900',
  safe: '#10B981',
  safeSoft: '#34D399',
  warn: '#F59E0B',
  warnSoft: '#FBBF24',
  danger: '#EF4444',
  dangerSoft: '#F87171',
  text: '#FAFAFA',
  text2: '#A1A1AA',
  muted: '#9A9AA4',
  dim: '#55555F',
  cardTop: '#1B1214',
  cardMid: '#131316',
};

const FAM = {
  ui: 'Plus Jakarta Sans',
  mono: 'JetBrains Mono',
  sym: 'Inter', // Inter carries U+20B9; JetBrains Mono does not.
};

// ---------------------------------------------------------------------------
// 2. Colour helpers
// ---------------------------------------------------------------------------

function rgb01(hex) {
  const h = hex.replace('#', '');
  return {
    r: parseInt(h.slice(0, 2), 16) / 255,
    g: parseInt(h.slice(2, 4), 16) / 255,
    b: parseInt(h.slice(4, 6), 16) / 255,
  };
}

function solid(hex, opacity = 1) {
  return { type: 'SOLID', color: rgb01(hex), opacity };
}

/** Figma gradientTransform for a CSS-style angle (deg, 0 = left→right). */
function gTransform(angle) {
  const rad = (angle * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);
  return [
    [cos, sin, 0.5 - 0.5 * cos - 0.5 * sin],
    [-sin, cos, 0.5 + 0.5 * sin - 0.5 * cos],
  ];
}

function stops(list) {
  return list.map((s, i) => ({
    position: s.at != null ? s.at : i / Math.max(1, list.length - 1),
    color: Object.assign(rgb01(s.hex), { a: s.a == null ? 1 : s.a }),
  }));
}

/** Linear gradient paint. `list` = [{hex, at, a}] */
function lin(list, angle = 135, opacity = 1) {
  return {
    type: 'GRADIENT_LINEAR',
    gradientTransform: gTransform(angle),
    gradientStops: stops(list),
    opacity,
  };
}

/** Radial gradient paint. */
function rad(list, opacity = 1) {
  return {
    type: 'GRADIENT_RADIAL',
    gradientTransform: [
      [1, 0, 0],
      [0, 1, 0],
    ],
    gradientStops: stops(list),
    opacity,
  };
}

const BURN = () => lin([{ hex: C.accent, at: 0 }, { hex: C.accentAlt, at: 1 }], 135);
const BURN_V = () => lin([{ hex: C.accentAlt, at: 0 }, { hex: C.accent, at: 1 }], 90);

// ---------------------------------------------------------------------------
// 3. Geometry helpers
// ---------------------------------------------------------------------------

/** Vertical auto-layout frame. */
function V(name, o) {
  return auto(name, 'VERTICAL', o);
}

/** Horizontal auto-layout frame. */
function H(name, o) {
  return auto(name, 'HORIZONTAL', o);
}

function auto(name, dir, o) {
  o = o || {};
  const f = figma.createFrame();
  f.name = name;

  const fills = [];
  if (o.fill) fills.push(solid(o.fill));
  if (o.grad) fills.push(o.grad);
  f.fills = fills;
  f.clipsContent = o.clip !== false;

  f.layoutMode = dir;
  f.itemSpacing = o.gap || 0;

  const p = o.pad;
  if (Array.isArray(p)) {
    f.paddingTop = p[0];
    f.paddingRight = p[1];
    f.paddingBottom = p[2];
    f.paddingLeft = p[3];
  } else if (typeof p === 'number') {
    f.paddingTop = f.paddingRight = f.paddingBottom = f.paddingLeft = p;
  }

  f.primaryAxisAlignItems = o.main || 'MIN';
  f.counterAxisAlignItems = o.cross || 'MIN';
  f.primaryAxisSizingMode = 'AUTO';
  f.counterAxisSizingMode = 'AUTO';

  if (o.radius != null) f.cornerRadius = o.radius;

  if (o.stroke) {
    f.strokes = [solid(o.stroke, o.strokeOpacity == null ? 1 : o.strokeOpacity)];
    f.strokeWeight = o.strokeWeight == null ? 1 : o.strokeWeight;
    f.strokeAlign = 'INSIDE';
  }
  if (o.dash) f.dashPattern = o.dash;
  if (o.effects) f.effects = o.effects;

  if (o.w != null) f.resize(o.w, Math.max(1, f.height));
  if (o.h != null) {
    f.primaryAxisSizingMode = 'FIXED';
    f.resize(o.w != null ? o.w : Math.max(1, f.width), o.h);
  }
  if (o.w != null) f.counterAxisSizingMode = 'FIXED';

  return f;
}

/** Horizontal layout with a fixed width and auto height. */
function stackV(name, width, o) {
  o = o || {};
  o.w = width;
  return V(name, o);
}

function fillH(n) {
  try {
    n.layoutSizingHorizontal = 'FILL';
  } catch (e) {}
  return n;
}
function fillV(n) {
  try {
    n.layoutSizingVertical = 'FILL';
  } catch (e) {}
  return n;
}
function grow(n) {
  try {
    n.layoutGrow = 1;
  } catch (e) {}
  return n;
}
function fixedW(n, w) {
  try {
    n.layoutSizingHorizontal = 'FIXED';
    n.resize(w, n.height);
  } catch (e) {}
  return n;
}

function rect(name, w, h, o) {
  o = o || {};
  const r = figma.createRectangle();
  r.name = name;
  r.resize(w, h);
  if (o.radius != null) r.cornerRadius = o.radius;
  if (o.fill) r.fills = [solid(o.fill, o.opacity == null ? 1 : o.opacity)];
  else if (o.grad) r.fills = [o.grad];
  else r.fills = [];
  if (o.stroke) {
    r.strokes = [solid(o.stroke)];
    r.strokeWeight = 1;
    r.strokeAlign = 'INSIDE';
  }
  return r;
}

function circle(name, d, o) {
  o = o || {};
  const e = figma.createEllipse();
  e.name = name;
  e.resize(d, d);
  if (o.fill) e.fills = [solid(o.fill, o.opacity == null ? 1 : o.opacity)];
  else if (o.grad) e.fills = [o.grad];
  else e.fills = [];
  return e;
}

function spacer(h) {
  const f = figma.createFrame();
  f.name = 'spacer';
  f.fills = [];
  f.resize(1, h || 1);
  return f;
}

function growSpacer(name) {
  const f = figma.createFrame();
  f.name = name || 'spacer';
  f.fills = [];
  f.resize(1, 1);
  grow(f);
  return f;
}

function push(parent, kids) {
  for (const k of kids) if (k) parent.appendChild(k);
  return parent;
}

/** Absolute child inside an auto-layout frame. */
function abs(node, x, y, w, h) {
  node.layoutPositioning = 'ABSOLUTE';
  node.x = x;
  node.y = y;
  if (w != null) node.resize(w, h != null ? h : node.height);
  return node;
}

// ---------------------------------------------------------------------------
// 4. Fonts
// ---------------------------------------------------------------------------

let AVAIL = [];
const LOADED = {};

async function loadFonts() {
  try {
    AVAIL = await figma.listAvailableFontsAsync();
  } catch (e) {
    AVAIL = [];
  }

  const want = [
    [FAM.ui, 'Regular'],
    [FAM.ui, 'Medium'],
    [FAM.ui, 'SemiBold'],
    [FAM.ui, 'Bold'],
    [FAM.ui, 'ExtraBold'],
    [FAM.mono, 'Regular'],
    [FAM.mono, 'Medium'],
    [FAM.mono, 'SemiBold'],
    [FAM.mono, 'Bold'],
    [FAM.sym, 'Regular'],
    [FAM.sym, 'SemiBold'],
    [FAM.sym, 'Bold'],
  ];

  for (const [family, style] of want) {
    let f = { family, style };
    if (!fontExists(f)) {
      // fall back within the family, then to Inter
      f = snapFont(family, style) || { family: FAM.sym, style: snapStyle(FAM.sym, style) };
    }
    try {
      await figma.loadFontAsync(f);
      LOADED[family + '|' + style] = f;
    } catch (e) {
      const fb = { family: FAM.sym, style: 'Regular' };
      try {
        await figma.loadFontAsync(fb);
        LOADED[family + '|' + style] = fb;
      } catch (e2) {
        LOADED[family + '|' + style] = { family: 'Inter', style: 'Regular' };
      }
    }
  }
}

function fontExists(f) {
  return AVAIL.some((a) => a.fontName.family === f.family && a.fontName.style === f.style);
}

function snapFont(family, style) {
  const inFam = AVAIL.filter((a) => a.fontName.family === family);
  if (!inFam.length) return null;
  const s = snapStyleIn(inFam, style);
  return s ? { family, style: s } : null;
}

function snapStyleIn(list, style) {
  const order = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black', 'Light'];
  const want = order.indexOf(style);
  let best = null;
  let bestD = 99;
  for (const a of list) {
    const i = order.indexOf(a.fontName.style);
    const d = i < 0 ? 50 : Math.abs(i - (want < 0 ? 0 : want));
    if (d < bestD) {
      bestD = d;
      best = a.fontName.style;
    }
  }
  return best;
}

function snapStyle(family, style) {
  const inFam = AVAIL.filter((a) => a.fontName.family === family);
  return snapStyleIn(inFam, style) || 'Regular';
}

function font(kind, weight) {
  const key = (kind === 'mono' ? FAM.mono : FAM.ui) + '|' + weight;
  return LOADED[key] || LOADED[FAM.ui + '|Regular'] || { family: 'Inter', style: 'Regular' };
}

const SYM_FONT = () => LOADED[FAM.sym + '|Regular'] || { family: 'Inter', style: 'Regular' };

// ---------------------------------------------------------------------------
// 5. Text styles
// ---------------------------------------------------------------------------

/** name: {kind, size, lh, weight, ls (percent), color} */
const TYPE = {
  display: { kind: 'mono', size: 58, lh: 58, weight: 'SemiBold', ls: -5.5 },
  h1: { kind: 'ui', size: 25, lh: 26, weight: 'ExtraBold', ls: -3.5 },
  h2: { kind: 'ui', size: 22, lh: 24, weight: 'ExtraBold', ls: -3.5 },
  h3: { kind: 'ui', size: 16, lh: 20, weight: 'ExtraBold', ls: -3 },
  section: { kind: 'ui', size: 13, lh: 16, weight: 'Bold', ls: -1.5 },
  body: { kind: 'ui', size: 12, lh: 16, weight: 'Medium', ls: 0 },
  caption: { kind: 'ui', size: 10, lh: 14, weight: 'Medium', ls: 0 },
  label: { kind: 'ui', size: 10, lh: 12, weight: 'Bold', ls: 11.5 },
  micro: { kind: 'mono', size: 8, lh: 10, weight: 'SemiBold', ls: 6 },
  moneyLg: { kind: 'mono', size: 34, lh: 36, weight: 'SemiBold', ls: -5.5 },
  moneyMd: { kind: 'mono', size: 16, lh: 18, weight: 'SemiBold', ls: -4 },
  moneySm: { kind: 'mono', size: 12, lh: 14, weight: 'SemiBold', ls: -3 },
};

function T(chars, styleName, o) {
  o = o || {};
  const s = TYPE[styleName];
  const t = figma.createText();
  t.name = o.name || String(chars).slice(0, 22);
  t.fontName = font(s.kind, s.weight);
  t.fontSize = o.size || s.size;
  t.lineHeight = { unit: 'PIXELS', value: o.lh || s.lh };
  t.letterSpacing = { unit: 'PERCENT', value: o.ls == null ? s.ls : o.ls };
  t.textAutoResize = o.grow ? 'HEIGHT' : 'WIDTH_AND_HEIGHT';
  t.characters = String(chars);
  t.fills = o.grad ? [o.grad] : [solid(o.color || C.text, o.opacity == null ? 1 : o.opacity)];

  if (o.align) t.textAlignHorizontal = o.align;
  if (o.uppercase) t.textCase = 'UPPER';

  // Guarantee the rupee renders: Inter carries U+20B9, JetBrains Mono does not.
  const lead = String(chars).charAt(0);
  if (lead === '₹') {
    try {
      t.setRangeFontName(0, 1, SYM_FONT());
    } catch (e) {}
  }
  if (o.grow) fillH(t);
  return t;
}

// ---------------------------------------------------------------------------
// 6. Styles (design system)
// ---------------------------------------------------------------------------

const PAINT = {};
const TEXTSTYLE = {};

function makePaintStyles() {
  const defs = [
    ['Color/BG', C.bg],
    ['Color/Surface', C.surface],
    ['Color/Surface Hi', C.surfaceHi],
    ['Color/Border', C.border],
    ['Color/Border Hi', C.borderHi],
    ['Color/Accent', C.accent],
    ['Color/Accent Alt', C.accentAlt],
    ['Color/Accent Warm', C.accentWarm],
    ['Color/Safe', C.safe],
    ['Color/Warn', C.warn],
    ['Color/Danger', C.danger],
    ['Color/Text', C.text],
    ['Color/Text Secondary', C.text2],
    ['Color/Text Muted', C.muted],
  ];
  for (const [name, hex] of defs) {
    const s = figma.createPaintStyle();
    s.name = name;
    s.paints = [solid(hex)];
    PAINT[name] = s;
  }
  const burn = figma.createPaintStyle();
  burn.name = 'Gradient/Burn';
  burn.paints = [BURN()];
  PAINT['Gradient/Burn'] = burn;
}

function makeTextStyles() {
  for (const key of Object.keys(TYPE)) {
    const s = TYPE[key];
    const ts = figma.createTextStyle();
    ts.name = 'Type/' + key;
    ts.fontName = font(s.kind, s.weight);
    ts.fontSize = s.size;
    ts.lineHeight = { unit: 'PIXELS', value: s.lh };
    ts.letterSpacing = { unit: 'PERCENT', value: s.ls };
    TEXTSTYLE[key] = ts;
  }
}

// ---------------------------------------------------------------------------
// 7. Small components
// ---------------------------------------------------------------------------

function badge(label, tone) {
  const map = {
    warn: { fg: C.warnSoft, bg: C.warn, bgA: 0.11, br: C.warn, brA: 0.3 },
    safe: { fg: C.safeSoft, bg: C.safe, bgA: 0.1, br: C.safe, brA: 0.28 },
    danger: { fg: C.dangerSoft, bg: C.danger, bgA: 0.1, br: C.danger, brA: 0.26 },
    neutral: { fg: C.text2, bg: '#0C0C0F', bgA: 1, br: C.border, brA: 1 },
  };
  const p = map[tone || 'neutral'];
  const b = H('Badge / ' + label, {
    h: 19,
    pad: [0, 7, 0, 7],
    gap: 5,
    radius: 6,
    fill: p.bg,
    stroke: p.br,
    strokeOpacity: p.brA,
    main: 'CENTER',
    cross: 'CENTER',
  });
  if (tone === 'warn' || tone === 'safe') {
    const dot = circle('dot', 4, { fill: p.fg });
    b.appendChild(dot);
  }
  b.appendChild(T(label, 'micro', { color: p.fg, size: 8.5 }));
  return b;
}

function tile(mark, hex, size) {
  const s = size || 30;
  const radius = s >= 44 ? 12 : 10;
  const f = H('Tile / ' + mark, {
    w: s,
    h: s,
    radius,
    main: 'CENTER',
    cross: 'CENTER',
    fill: '#000000',
  });
  f.fills = [
    lin([{ hex, at: 0, a: 0.24 }, { hex, at: 1, a: 0.08 }], 135),
  ];
  f.strokes = [solid(hex, 0.18)];
  f.strokeWeight = 1;
  f.strokeAlign = 'INSIDE';
  f.appendChild(
    T(mark, 'micro', { color: lighten(hex, 0.52), size: Math.round(s * 0.32), ls: -3 })
  );
  return f;
}

function lighten(hex, amt) {
  const c = rgb01(hex);
  const m = (v) => Math.round((v + (1 - v) * amt) * 255);
  return (
    '#' +
    [m(c.r), m(c.g), m(c.b)]
      .map((v) => v.toString(16).padStart(2, '0'))
      .join('')
  );
}

function money(val, yearly) {
  const s = yearly ? inr(val * 12) : inr(val);
  return s;
}

/** Indian digit grouping: 4,850 → 4,850 · 124000 → 1,24,000 */
function inr(n) {
  let s = Math.round(n).toString();
  if (s.length > 3) {
    const last3 = s.slice(-3);
    let head = s.slice(0, -3);
    const parts = [];
    while (head.length > 2) {
      parts.unshift(head.slice(-2));
      head = head.slice(0, -2);
    }
    if (head) parts.unshift(head);
    s = parts.join(',') + ',' + last3;
  }
  return '₹' + s;
}

function subRow(tool) {
  const ghost = tool.guilt === 'barely';
  const row = H('SubRow / ' + tool.name, {
    h: 44,
    w: 361,
    pad: [0, 12, 0, 12],
    gap: 10,
    radius: 12,
    fill: ghost ? '#101014' : C.surface,
    stroke: ghost ? '#33333A' : C.border,
    cross: 'CENTER',
  });
  if (ghost) row.dashPattern = [4, 3];

  row.appendChild(tile(tool.mark, tool.color, 30));

  const meta = V('meta', { gap: 2, cross: 'CENTER' });
  meta.appendChild(T(tool.name, 'body', { color: ghost ? C.text2 : C.text, size: 11.5, weightOverride: 600 }));
  meta.appendChild(T(tool.plan, 'micro', { color: C.muted, size: 7.5, ls: 6 }));
  fillH(meta);
  row.appendChild(meta);

  const right = V('right', { gap: 2 });
  right.appendChild(T(inr(tool.inr), 'moneySm', { color: ghost ? C.text2 : C.text })
  );
  right.appendChild(
    T(ghost ? 'GHOST · 41D' : 'DAILY USE', 'micro', {
      color: ghost ? '#D9A24F' : '#4FBF9A',
      size: 7.5,
      ls: 7,
    })
  );
  right.counterAxisAlignItems = 'MAX';
  row.appendChild(right);

  return row;
}

function renewalCard(r) {
  const card = V('RenewalCard / ' + r.tool.name, {
    w: 148,
    h: 104,
    pad: [11, 12, 10, 12],
    radius: 12,
    grad: lin([{ hex: C.surfaceHi, at: 0 }, { hex: C.surface, at: 1 }], 90),
    stroke: C.border,
    gap: 0,
    main: 'SPACE_BETWEEN',
  });

  const top = H('top', { gap: 8, cross: 'CENTER', w: 124 });
  top.appendChild(tile(r.tool.mark, r.tool.color, 30));
  const nm = V('names', { gap: 2 });
  nm.appendChild(T(r.tool.name, 'body', { size: 10.5 }));
  nm.appendChild(T('Renews ' + r.when, 'micro', { size: 7.5, color: C.muted, ls: 1 }));
  fillH(nm);
  top.appendChild(nm);
  card.appendChild(top);

  const price = H('price', { gap: 3, cross: 'CENTER' });
  price.appendChild(T(inr(r.tool.inr), 'moneyMd'));
  price.appendChild(T('/mo', 'micro', { size: 8, color: C.muted, ls: 0 }));
  card.appendChild(price);

  card.appendChild(badge(r.eta, r.hot ? 'warn' : 'neutral'));
  return card;
}

function ctaButton(label, trailing, variant) {
  const v = variant || 'primary';
  const b = H('Button / ' + label, {
    h: v === 'primary' ? 52 : v === 'danger' ? 50 : 46,
    radius: 14,
    main: 'CENTER',
    cross: 'CENTER',
    gap: 9,
    grad: v === 'primary' ? BURN() : null,
    fill: v === 'primary' ? null : v === 'danger' ? '#1A0F11' : C.surface,
    stroke: v === 'primary' ? null : v === 'danger' ? C.danger : C.border,
    strokeOpacity: v === 'primary' ? 1 : v === 'danger' ? 0.34 : 1,
  });
  if (v === 'primary') {
    b.effects = [
      {
        type: 'DROP_SHADOW',
        color: Object.assign(rgb01(C.accent), { a: 0.5 }),
        offset: { x: 0, y: 16 },
        radius: 34,
        spread: -12,
        visible: true,
        blendMode: 'NORMAL',
      },
    ];
  }

  const textColor =
    v === 'primary' ? C.accentDeep : v === 'danger' ? C.dangerSoft : C.text;
  b.appendChild(T(label, 'section', { color: textColor, size: 13 }));

  if (trailing) {
    const div = rect('divider', 1, 16, { fill: C.accentDeep, opacity: 0.2 });
    b.appendChild(div);
    b.appendChild(T(trailing, 'micro', { size: 10.5, color: C.accentDeep, opacity: 0.72 }));
  }
  return b;
}

// ---------------------------------------------------------------------------
// 8. Shared chrome
// ---------------------------------------------------------------------------

function statusBar() {
  const s = H('StatusBar', { w: 393, h: 54, pad: [0, 25, 0, 25], cross: 'CENTER' });
  s.appendChild(T('9:41', 'section', { size: 13.5, color: C.text }));
  const right = H('indicators', { gap: 5, cross: 'CENTER' });
  right.appendChild(T('▮▮▮', 'micro', { size: 9, color: C.text, ls: 0 }));
  right.appendChild(T('◗', 'micro', { size: 10, color: C.text, ls: 0 }));
  right.appendChild(T('▭', 'micro', { size: 11, color: C.text2, ls: 0 }));
  growSpacer('spacer');
  s.appendChild(right);
  return s;
}

function homeIndicator() {
  return rect('HomeIndicator', 132, 5, { fill: C.borderHi, radius: 3 });
}

function tabBar() {
  const bar = H('TabBar', {
    w: 393,
    h: 80,
    pad: [10, 14, 0, 14],
    gap: 0,
    main: 'SPACE_BETWEEN',
    cross: 'MIN',
    grad: lin([{ hex: C.bg, at: 0, a: 0 }, { hex: C.bg, at: 0.35, a: 0.88 }, { hex: C.bg, at: 1 }], 90),
  });

  function tab(label, active, icon) {
    const t = V('Tab / ' + label, { w: 52, h: 48, gap: 5, pad: [5, 0, 0, 0], cross: 'CENTER' });
    t.appendChild(T(icon, 'micro', { size: 15, color: active ? C.accent : C.muted, ls: 0 }));
    t.appendChild(T(label, 'micro', { size: 7.5, color: active ? C.accent : C.muted, ls: 5 }));
    return t;
  }

  bar.appendChild(tab('BURN', true, '🔥'));
  bar.appendChild(tab('STUDIO', false, '▤'));

  const fab = H('FAB', {
    w: 46,
    h: 46,
    radius: 15,
    main: 'CENTER',
    cross: 'CENTER',
    grad: BURN(),
  });
  fab.effects = [
    {
      type: 'DROP_SHADOW',
      color: Object.assign(rgb01(C.accent), { a: 0.7 }),
      offset: { x: 0, y: 12 },
      radius: 26,
      spread: -8,
      visible: true,
      blendMode: 'NORMAL',
    },
  ];
  fab.appendChild(T('+', 'h3', { size: 22, color: C.accentDeep }));
  bar.appendChild(fab);

  bar.appendChild(tab('ALERTS', false, '🔔'));
  bar.appendChild(tab('ME', false, '👤'));
  return bar;
}

function sectionHead(title, trailing) {
  const h = H('SectionHeader / ' + title, { w: 361, h: 20, main: 'SPACE_BETWEEN', cross: 'CENTER' });
  h.appendChild(T(title, 'section'));
  if (trailing) h.appendChild(trailing);
  return h;
}

// ---------------------------------------------------------------------------
// 9. Screen 1 — Burn dashboard
// ---------------------------------------------------------------------------

const TOOLS = [
  { name: 'ChatGPT Plus', mark: 'AI', plan: 'OPENAI · PLUS', color: '#10A37F', inr: 1660, guilt: 'daily' },
  { name: 'Claude Pro', mark: 'CL', plan: 'ANTHROPIC · PRO', color: '#D97757', inr: 1660, guilt: 'daily' },
  { name: 'Cursor Pro', mark: 'CU', plan: 'ANYSPHERE · PRO', color: '#9C9CA6', inr: 830, guilt: 'barely' },
  { name: 'GitHub Copilot', mark: 'GH', plan: 'GITHUB · INDIVIDUAL', color: '#A78BFA', inr: 415, guilt: 'barely' },
  { name: 'Midjourney', mark: 'MJ', plan: 'MIDJOURNEY · LITE', color: '#7C8797', inr: 285, guilt: 'daily' },
];

function heroCard() {
  const hero = V('HeroCard', {
    w: 361,
    h: 164,
    pad: 16,
    radius: 24,
    grad: lin(
      [{ hex: C.cardTop, at: 0 }, { hex: C.cardMid, at: 0.52 }, { hex: '#111114', at: 1 }],
      135
    ),
    stroke: '#33271F',
    clip: true,
  });

  // radial bloom, clipped by the card
  const glow = circle('Glow', 300, {
    grad: rad(
      [
        { hex: C.accent, at: 0, a: 0.36 },
        { hex: C.accentAlt, at: 0.45, a: 0.1 },
        { hex: C.accentAlt, at: 0.72, a: 0 },
      ],
      1
    ),
  });
  hero.appendChild(glow);
  abs(glow, 170, -150, 300, 300);

  const row = H('Row / Labels', { w: 329, main: 'SPACE_BETWEEN', cross: 'CENTER' });
  row.appendChild(T('MONTHLY BURN', 'label', { color: C.muted }));
  const delta = H('delta', { gap: 3, cross: 'CENTER' });
  delta.appendChild(T('▲', 'micro', { size: 6, color: C.accentWarm, ls: 0 }));
  delta.appendChild(T('₹620 vs Oct', 'micro', { size: 8, color: C.accentWarm, ls: 2 }));
  row.appendChild(delta);
  hero.appendChild(row);

  const amt = H('Amount', { gap: 6, cross: 'CENTER' });
  amt.appendChild(
    T('₹4,850', 'display', {
      grad: lin(
        [{ hex: '#FFFFFF', at: 0.04 }, { hex: '#FFC9A0', at: 0.46 }, { hex: '#FF6A1A', at: 1 }],
        90
      ),
    })
  );
  amt.appendChild(T('/ mo', 'micro', { size: 11.5, color: C.muted, ls: 1 }));
  hero.appendChild(amt);

  const sub = H('Subline', { gap: 4, cross: 'CENTER' });
  sub.appendChild(T('5 tools tracked · ', 'caption', { color: C.text2 }));
  sub.appendChild(T('₹1,245', 'micro', { size: 9.5, color: C.accentWarm, ls: -1 }));
  sub.appendChild(T(' of it is dead weight', 'caption', { color: C.text2 }));
  hero.appendChild(sub);

  const bar = H('SplitBar', { w: 329, h: 7, gap: 2, radius: 4, clip: true, fill: '#1D1D23' });
  bar.appendChild(rect('active', 245, 7, { grad: BURN() }));
  bar.appendChild(rect('ghost', 82, 7, { fill: '#6B6B75' }));
  hero.appendChild(bar);

  const legend = H('Legend', { w: 329, main: 'SPACE_BETWEEN', cross: 'CENTER' });
  const l1 = H('active', { gap: 5, cross: 'CENTER' });
  l1.appendChild(rect('key', 5, 5, { grad: BURN(), radius: 2 }));
  l1.appendChild(T('Active use', 'caption', { size: 9.5, color: C.text2 }));
  l1.appendChild(T('74%', 'micro', { size: 9, color: C.muted, ls: 0 }));
  legend.appendChild(l1);

  const l2 = H('ghost', { gap: 5, cross: 'CENTER' });
  l2.appendChild(rect('key', 5, 5, { fill: '#6B6B75', radius: 2 }));
  l2.appendChild(T('Ghost subs', 'caption', { size: 9.5, color: C.text2 }));
  l2.appendChild(T('26%', 'micro', { size: 9, color: C.muted, ls: 0 }));
  legend.appendChild(l2);
  hero.appendChild(legend);

  // keep the vertical rhythm honest: fixed slots, no drift
  try {
    hero.primaryAxisSizingMode = 'FIXED';
    hero.layoutSizingVertical = 'FIXED';
  } catch (e) {}
  return hero;
}

function screenDashboard(x) {
  const screen = V('01 · Burn Dashboard', {
    w: 393,
    h: 852,
    fill: C.bg,
    clip: true,
    pad: [0, 16, 96, 16],
    gap: 0,
  });
  screen.x = x;
  screen.y = 0;
  screen.primaryAxisSizingMode = 'FIXED';

  screen.appendChild(statusBar());

  const top = H('TopBar', { w: 361, h: 48, gap: 8, cross: 'CENTER' });
  const logo = H('Logo', { w: 30, h: 30, radius: 10, main: 'CENTER', cross: 'CENTER', grad: BURN() });
  logo.appendChild(T('🔥', 'micro', { size: 14, color: C.accentDeep, ls: 0 }));
  top.appendChild(logo);
  top.appendChild(T('SUBBURN', 'section', { size: 13.5, ls: 15 }));
  growSpacer();
  const chip = H('Chip / Frequency', {
    h: 22,
    pad: [0, 8, 0, 8],
    gap: 5,
    radius: 999,
    fill: '#0C0C0F',
    stroke: C.border,
    cross: 'CENTER',
  });
  chip.appendChild(circle('dot', 4, { fill: C.accent }));
  chip.appendChild(T('Monthly AI & SaaS burn', 'micro', { size: 8, color: C.text2, ls: 7 }));
  top.appendChild(chip);
  screen.appendChild(top);

  screen.appendChild(heroCard());
  screen.appendChild(spacer(14));

  screen.appendChild(sectionHead('Renewing soon', badge('48H WINDOW', 'warn')));
  screen.appendChild(spacer(8));

  const rail = H('Rail / Renewing', { w: 377, h: 104, gap: 10, clip: true });
  rail.appendChild(
    renewalCard({ tool: TOOLS[0], eta: '14h 22m left', when: 'today', hot: true })
  );
  rail.appendChild(
    renewalCard({ tool: TOOLS[1], eta: '23h 05m left', when: 'today', hot: true })
  );
  rail.appendChild(
    renewalCard({ tool: TOOLS[2], eta: '1d 11h left', when: 'tomorrow', hot: false })
  );
  screen.appendChild(rail);

  screen.appendChild(spacer(12));
  screen.appendChild(sectionHead('Active subscriptions', badge('5 TOOLS', 'neutral')));
  screen.appendChild(spacer(8));

  const list = V('List / Subscriptions', { w: 361, gap: 8 });
  for (const t of TOOLS) list.appendChild(subRow(t));
  screen.appendChild(list);

  screen.appendChild(spacer(12));

  // ghost callout
  const callout = H('Callout / Ghost', {
    w: 361,
    h: 56,
    pad: [0, 12, 0, 12],
    gap: 10,
    radius: 12,
    grad: lin([{ hex: C.warn, at: 0, a: 0.1 }, { hex: C.surface, at: 1, a: 0.6 }], 100),
    stroke: C.warn,
    strokeOpacity: 0.24,
    cross: 'CENTER',
  });
  const ico = H('icon', { w: 26, h: 26, radius: 8, main: 'CENTER', cross: 'CENTER' });
  ico.fills = [solid(C.warn, 0.14)];
  ico.appendChild(T('!', 'section', { size: 12, color: C.warnSoft }));
  callout.appendChild(ico);

  const txt = V('text', { gap: 2 });
  txt.appendChild(T('26% of your burn buys nothing', 'body', { size: 10.5 }));
  txt.appendChild(T('2 tools untouched for 40+ days', 'micro', { size: 8.5, color: C.muted, ls: 1 }));
  fillH(txt);
  callout.appendChild(txt);
  callout.appendChild(T('REVIEW ›', 'micro', { size: 8.5, color: C.warnSoft, ls: 5 }));
  screen.appendChild(callout);

  const bar = tabBar();
  screen.appendChild(abs(bar, 0, 772, 393, 80));

  const home = homeIndicator();
  screen.appendChild(abs(home, 130, 839, 132, 5));

  return screen;
}

// ---------------------------------------------------------------------------
// 10. Screen 2 — Quick add
// ---------------------------------------------------------------------------

const POPULAR = [
  { mark: 'AI', label: 'ChatGPT', color: '#10A37F' },
  { mark: 'MJ', label: 'Midjourney', color: '#7C8797' },
  { mark: 'CU', label: 'Cursor', color: '#9C9CA6' },
  { mark: 'NF', label: 'Netflix', color: '#E50914' },
  { mark: 'SP', label: 'Spotify', color: '#1DB954' },
  { mark: 'GH', label: 'Copilot', color: '#A78BFA' },
  { mark: 'NO', label: 'Notion', color: '#D4D4D8' },
  { mark: 'FG', label: 'Figma', color: '#F24E1E' },
  { mark: 'AD', label: 'Adobe CC', color: '#FA0F00' },
  { mark: 'CV', label: 'Canva', color: '#00C4CC' },
  { mark: 'PX', label: 'Perplexity', color: '#1FB8CD' },
  { mark: 'GR', label: 'Grammarly', color: '#15C39A' },
];

function field(label, control) {
  const f = V('Field / ' + label, { gap: 6, w: 361 });
  f.appendChild(T(label, 'label', { color: C.muted }));
  f.appendChild(control);
  return f;
}

function seg(items, activeIndex) {
  const s = H('Segmented', {
    w: 361,
    h: 46,
    pad: 4,
    gap: 4,
    radius: 12,
    fill: '#0B0B0E',
    stroke: C.border,
  });
  items.forEach((it, i) => {
    const on = i === activeIndex;
    const b = H('Segment / ' + it.label, {
      h: 44,
      radius: 9,
      main: 'CENTER',
      cross: 'CENTER',
      gap: 5,
      fill: on ? null : '#000000',
      grad: on ? lin([{ hex: '#231A16', at: 0 }, { hex: '#1B1512', at: 1 }], 90) : null,
      stroke: on ? C.accentAlt : '#000000',
      strokeOpacity: on ? 0.36 : 0,
    });
    if (!on) b.fills = [];
    if (it.dot) b.appendChild(circle('dot', 5, { fill: it.dot }));
    b.appendChild(T(it.label, 'section', { size: 11, color: on ? C.text : C.muted, ls: -1 }));
    if (it.trailing)
      b.appendChild(T(it.trailing, 'micro', { size: 8, color: on ? C.accentWarm : C.muted, ls: 2 }));
    fillH(b);
    s.appendChild(b);
  });
  return s;
}

function screenQuickAdd(x) {
  const screen = V('02 · Quick Add', {
    w: 393,
    h: 852,
    fill: C.bg,
    clip: true,
    gap: 0,
  });
  screen.x = x;
  screen.y = 0;
  screen.primaryAxisSizingMode = 'FIXED';

  screen.appendChild(statusBar());

  // dimmed dashboard behind the sheet
  const ghostScreen = V('Backdrop / Dashboard (dimmed)', {
    w: 393,
    h: 440,
    fill: C.bg,
    pad: [0, 16, 0, 16],
    opacity: 1,
  });
  const dimHero = V('dim hero', {
    w: 361,
    h: 164,
    radius: 24,
    grad: lin([{ hex: C.cardTop, at: 0 }, { hex: C.cardMid, at: 1 }], 135),
    pad: 16,
  });
  dimHero.appendChild(T('MONTHLY BURN', 'label', { color: C.muted }));
  dimHero.appendChild(T('₹4,850', 'display', { color: '#2A2A31' }));
  ghostScreen.appendChild(dimHero);
  abs(ghostScreen, 0, 0, 393, 440);
  ghostScreen.opacity = 0.55;

  // scrim
  const scrim = rect('Scrim', 393, 852, {
    grad: lin([{ hex: C.bg, at: 0, a: 0.86 }, { hex: C.bg, at: 0.42, a: 0.96 }, { hex: C.bg, at: 1, a: 1 }], 90),
  });
  abs(scrim, 0, 0, 393, 852);

  // sheet
  const sheet = V('Sheet / Quick Add', {
    w: 393,
    h: 660,
    pad: [10, 16, 34, 16],
    radius: 26,
    grad: lin([{ hex: '#16161B', at: 0 }, { hex: '#101014', at: 0.42 }, { hex: '#0D0D10', at: 1 }], 90),
    stroke: '#2E2E35',
    gap: 0,
  });
  abs(sheet, 0, 192, 393, 660);

  const handle = rect('handle', 36, 4, { fill: C.borderHi, radius: 2 });
  const handleWrap = H('handleWrap', { w: 361, h: 4, main: 'CENTER' });
  handleWrap.appendChild(handle);
  sheet.appendChild(handleWrap);
  sheet.appendChild(spacer(12));

  const head = H('SheetHead', { w: 361, main: 'SPACE_BETWEEN', cross: 'MIN' });
  const ht = V('titles', { gap: 4 });
  ht.appendChild(T('Add subscription', 'h2'));
  ht.appendChild(T('Pick a tool, set the burn, log the guilt.', 'caption', { color: C.text2, size: 11 }));
  head.appendChild(ht);
  const xBtn = H('Close', {
    w: 44,
    h: 44,
    radius: 13,
    fill: '#1B1B21',
    stroke: C.border,
    main: 'CENTER',
    cross: 'CENTER',
  });
  xBtn.appendChild(T('✕', 'section', { size: 13, color: C.text2 }));
  head.appendChild(xBtn);
  sheet.appendChild(head);
  sheet.appendChild(spacer(13));

  // 4 x 3 grid
  const grid = V('Grid / Tools', { w: 361, gap: 10 });
  for (let row = 0; row < 3; row++) {
    const r = H('grid row ' + (row + 1), { w: 361, gap: 6 });
    for (let col = 0; col < 4; col++) {
      const p = POPULAR[row * 4 + col];
      const cell = V('Tool / ' + p.label, { w: 85, gap: 6, cross: 'CENTER' });
      const selected = row === 0 && col === 0;
      const t = tile(p.mark, p.color, 44);
      if (selected) {
        t.strokes = [solid(C.accent)];
        t.strokeWeight = 1.5;
        t.effects = [
          {
            type: 'DROP_SHADOW',
            color: Object.assign(rgb01(C.accent), { a: 0.5 }),
            offset: { x: 0, y: 8 },
            radius: 20,
            spread: -8,
            visible: true,
            blendMode: 'NORMAL',
          },
        ];
      }
      cell.appendChild(t);
      cell.appendChild(
        T(p.label, 'micro', {
          size: 8,
          color: selected ? C.text : C.text2,
          ls: 0,
        })
      );
      r.appendChild(cell);
    }
    grid.appendChild(r);
  }
  sheet.appendChild(grid);
  sheet.appendChild(spacer(14));

  sheet.appendChild(
    field(
      'Billing cycle',
      seg([{ label: 'Monthly' }, { label: 'Yearly', trailing: '-17%' }], 0)
    )
  );
  sheet.appendChild(spacer(12));
  sheet.appendChild(field('Currency', seg([{ label: '₹ INR' }, { label: '$ USD' }], 0)));
  sheet.appendChild(spacer(12));
  sheet.appendChild(
    field(
      'Usage guilt level',
      seg(
        [
          { label: 'Daily driver', dot: C.safe },
          { label: 'Barely touch it', dot: C.warn },
        ],
        0
      )
    )
  );
  sheet.appendChild(spacer(6));
  sheet.appendChild(
    T('ⓘ Ghost score recalculates from how often you open the app.', 'micro', {
      size: 8.5,
      color: C.muted,
      ls: 1,
    })
  );
  sheet.appendChild(spacer(14));

  const cta = ctaButton('Add to burn tracker', '₹1,660 /mo', 'primary');
  fillH(cta);
  sheet.appendChild(cta);
  sheet.appendChild(spacer(6));
  const scan = H('Scan', { w: 361, h: 44, main: 'CENTER', cross: 'CENTER', gap: 6 });
  scan.appendChild(T('⧉  Scan a receipt instead', 'caption', { size: 10.5, color: C.text2 }));
  sheet.appendChild(scan);

  const home = homeIndicator();
  screen.appendChild(abs(home, 130, 839, 132, 5));

  return screen;
}

// ---------------------------------------------------------------------------
// 11. Screen 3 — Card studio (the exportable receipt)
// ---------------------------------------------------------------------------

const YEARLY_TOTAL = TOOLS.reduce((a, t) => a + t.inr, 0) * 12; // ₹58,200
const GHOST_TOTAL = TOOLS.filter((t) => t.guilt === 'barely').reduce((a, t) => a + t.inr, 0) * 12;

function receiptFrame() {
  // 360 x 640, exactly 9:16. One clean node = one RepaintBoundary.
  const card = V('ExportFrame / Receipt 360x640', {
    w: 360,
    h: 640,
    pad: [24, 22, 20, 22],
    fill: '#0B0B0E',
    stroke: '#2C2318',
    radius: 18,
    clip: true,
    gap: 0,
  });

  const g1 = circle('Glow / top', 420, {
    grad: rad(
      [
        { hex: C.accent, at: 0, a: 0.3 },
        { hex: C.accentAlt, at: 0.46, a: 0.08 },
        { hex: C.accentAlt, at: 0.68, a: 0 },
      ],
      1
    ),
  });
  card.appendChild(g1);
  abs(g1, -90, -230, 420, 360);

  const g2 = circle('Glow / bottom', 520, {
    grad: rad(
      [{ hex: C.accent, at: 0, a: 0.24 }, { hex: C.accent, at: 0.64, a: 0 }],
      1
    ),
  });
  card.appendChild(g2);
  abs(g2, -80, 535, 520, 340);

  // brand row
  const brand = H('Brand', { w: 316, cross: 'CENTER', gap: 6 });
  brand.appendChild(rect('sq', 9, 9, { grad: BURN(), radius: 2.5 }));
  brand.appendChild(T('SUBBURN · WRAPPED 2026', 'micro', { size: 8, color: C.accentAlt, ls: 17 }));
  growSpacer();
  brand.appendChild(T('No. 00412', 'micro', { size: 8, color: '#6E6E78', ls: 10 }));
  card.appendChild(brand);

  card.appendChild(spacer(12));

  // title
  const title = V('Title', { gap: 0, w: 316 });
  title.appendChild(T('MY 2026 AI', 'h1', { color: C.text }));
  title.appendChild(T('TAX RECEIPT', 'h1', { color: '#FF7A1F' }));
  title.appendChild(spacer(6));
  title.appendChild(T('AUDIT OF RECKLESS OPTIMISM', 'micro', { size: 8, color: '#6E6E78', ls: 15 }));
  card.appendChild(title);

  card.appendChild(spacer(12));

  // dashed rule
  const rule = H('dashed rule', { w: 316, gap: 3, h: 1 });
  for (let i = 0; i < 58; i++) rule.appendChild(rect('d' + i, 3, 1, { fill: '#3A3A42' }));
  card.appendChild(rule);

  card.appendChild(spacer(9));

  const cols = H('ColumnHeads', { w: 316, main: 'SPACE_BETWEEN' });
  cols.appendChild(T('LINE ITEM', 'micro', { size: 6.5, color: C.dim, ls: 14 }));
  cols.appendChild(T('ANNUAL', 'micro', { size: 6.5, color: C.dim, ls: 14 }));
  card.appendChild(cols);
  card.appendChild(spacer(7));

  const rows = V('LineItems', { w: 316, gap: 9 });
  for (const t of TOOLS) {
    const r = H('Line / ' + t.name, { w: 316, main: 'SPACE_BETWEEN', cross: 'MIN' });
    const left = V('left', { gap: 2 });
    left.appendChild(T(t.name, 'body', { size: 11, color: '#E9E9EC' }));
    left.appendChild(T(inr(t.inr) + ' × 12', 'micro', { size: 7.5, color: '#6E6E78', ls: 0 }));
    r.appendChild(left);
    r.appendChild(T(inr(t.inr * 12), 'micro', { size: 10.5, color: C.text }));
    card.appendChild(r);
  }
  card.appendChild(spacer(11));

  // ghost strip
  const ghost = V('GhostSpend', {
    w: 316,
    pad: [8, 9, 8, 9],
    gap: 6,
    radius: 9,
    fill: C.warn,
    stroke: C.warn,
    strokeOpacity: 0.2,
  });
  ghost.fills = [solid(C.warn, 0.07)];
  const grow1 = H('row', { w: 298, main: 'SPACE_BETWEEN' });
  grow1.appendChild(T('GHOST SPEND', 'micro', { size: 7, color: '#C79447', ls: 12 }));
  grow1.appendChild(
    T('26% · ' + inr(GHOST_TOTAL) + '/YR', 'micro', { size: 7, color: C.warnSoft, ls: 4 })
  );
  ghost.appendChild(grow1);
  const meter = H('meter', { w: 298, h: 3, gap: 0, radius: 2, clip: true, fill: '#242329' });
  meter.appendChild(rect('spent', 78, 3, { grad: lin([{ hex: C.warn, at: 0 }, { hex: C.accent, at: 1 }], 0) }));
  meter.appendChild(rect('rest', 220, 3, { fill: '#242329' }));
  ghost.appendChild(meter);
  card.appendChild(ghost);

  card.appendChild(spacer(11));

  // stats strip
  const stats = H('Stats', { w: 316, h: 44 });
  stats.strokes = [solid('#26262D')];
  stats.strokeWeight = 1;
  stats.strokeAlign = 'INSIDE';
  stats.strokeTopWeight = 1;
  stats.strokeBottomWeight = 1;

  function stat(k, v, note, first) {
    const s = V('Stat / ' + k, { w: 105, pad: [7, 4, 8, first ? 0 : 10], gap: 3 });
    if (!first) {
      s.strokes = [solid('#26262D')];
      s.strokeWeight = 1;
      s.strokeAlign = 'INSIDE';
      s.strokeLeftWeight = 1;
      s.strokeTopWeight = 0;
      s.strokeRightWeight = 0;
      s.strokeBottomWeight = 0;
    }
    s.appendChild(T(k, 'micro', { size: 6, color: '#5E5E68', ls: 15 }));
    const line = H('v', { gap: 2, cross: 'CENTER' });
    line.appendChild(T(v, 'micro', { size: 12, color: '#E4E4E8', ls: -3 }));
    if (note) line.appendChild(T(note, 'micro', { size: 7, color: '#6E6E78', ls: 0 }));
    s.appendChild(line);
    return s;
  }

  stats.appendChild(stat('TOOLS', '5', null, true));
  stats.appendChild(stat('AVG / MO', inr(4850), null, false));
  stats.appendChild(stat('PER WORKDAY', inr(220), '/22', false));
  card.appendChild(stats);

  card.appendChild(spacer(11));

  // total
  const total = V('Total', { w: 316, gap: 1, pad: [9, 0, 0, 0] });
  total.strokes = [solid('#26262D')];
  total.strokeWeight = 1;
  total.strokeAlign = 'INSIDE';
  total.strokeTopWeight = 1;
  total.strokeBottomWeight = 0;
  total.strokeLeftWeight = 0;
  total.strokeRightWeight = 0;
  total.appendChild(T('TOTAL YEARLY BURN', 'micro', { size: 7, color: '#7B7B85', ls: 17 }));
  const totalAmt = H('amount', { gap: 5, cross: 'CENTER' });
  totalAmt.appendChild(
    T('₹58,200', 'display', {
      size: 40,
      lh: 44,
      grad: lin([{ hex: '#FFA03A', at: 0 }, { hex: C.accent, at: 0.78 }], 125),
    })
  );
  totalAmt.appendChild(T('/yr', 'micro', { size: 9.5, color: '#6E6E78', ls: 0 }));
  total.appendChild(totalAmt);
  card.appendChild(total);

  card.appendChild(spacer(8));

  // roast badge
  const roast = V('RoastBadge', {
    w: 316,
    pad: [9, 10, 9, 10],
    gap: 5,
    radius: 11,
    grad: lin([{ hex: C.accent, at: 0, a: 0.14 }, { hex: C.accentAlt, at: 1, a: 0.03 }], 158),
    stroke: C.accent,
    strokeOpacity: 0.38,
  });
  const tier = H('tier', { w: 296, gap: 5, cross: 'CENTER' });
  tier.appendChild(T('TIER: ', 'micro', { size: 7.5, color: C.accentWarm, ls: 10 }));
  tier.appendChild(T('SILICON VALLEY PAYPIG', 'micro', { size: 7.5, color: C.accent, ls: 10 }));
  growSpacer();
  const meter5 = H('meter', { gap: 2, cross: 'CENTER' });
  for (let i = 0; i < 5; i++)
    meter5.appendChild(rect('m' + i, 10, 3, { grad: i < 4 ? BURN() : null, fill: i < 4 ? null : '#3A2A22', radius: 1 }));
  tier.appendChild(meter5);
  roast.appendChild(tier);
  roast.appendChild(
    T('Paying ₹58,200/yr to generate memes and fix center divs.', 'caption', {
      size: 9,
      color: '#DCDCE0',
    })
  );
  card.appendChild(roast);

  card.appendChild(spacer(8));

  // verdict
  const verdict = H('Verdict', {
    w: 316,
    pad: [8, 10, 8, 10],
    gap: 8,
    radius: 9,
    fill: '#0F0F13',
    stroke: '#212127',
    cross: 'CENTER',
  });
  verdict.appendChild(T('VERDICT', 'micro', { size: 6.5, color: '#5C5C66', ls: 16 }));
  verdict.appendChild(
    T('You could have bought a MacBook Air instead.', 'caption', { size: 8.5, color: '#B9B9C0' })
  );
  card.appendChild(verdict);

  card.appendChild(growSpacer('push footer down'));

  // barcode
  const bc = H('Barcode', { w: 316, h: 15, gap: 1.6, cross: 'MAX' });
  const widths = [1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 2, 3];
  for (let i = 0; i < 46; i++)
    bc.appendChild(rect('b' + i, widths[i % widths.length], 15, { fill: '#9C9CA6', opacity: 0.42 }));
  card.appendChild(bc);

  card.appendChild(spacer(8));

  const foot = H('Footer', { w: 316, main: 'SPACE_BETWEEN', cross: 'CENTER', pad: [8, 0, 0, 0] });
  foot.strokes = [solid('#2A2A31')];
  foot.strokeWeight = 1;
  foot.strokeAlign = 'INSIDE';
  foot.strokeTopWeight = 1;
  foot.strokeBottomWeight = 0;
  foot.strokeLeftWeight = 0;
  foot.strokeRightWeight = 0;
  foot.appendChild(T('SUBBURN.APP', 'micro', { size: 6.5, color: C.dim, ls: 13 }));
  foot.appendChild(T('▦', 'micro', { size: 12, color: '#6E6E78', ls: 0 }));
  card.appendChild(foot);

  return card;
}

function screenCardStudio(x) {
  const screen = V('03 · Card Studio', {
    w: 393,
    h: 852,
    fill: C.bg,
    clip: true,
    pad: [0, 16, 28, 16],
    gap: 0,
  });
  screen.x = x;
  screen.y = 0;
  screen.primaryAxisSizingMode = 'FIXED';

  screen.appendChild(statusBar());

  const head = H('TopBar', { w: 361, h: 44, gap: 10, cross: 'CENTER' });
  const back = H('Back', {
    w: 44,
    h: 44,
    radius: 14,
    fill: '#131318',
    stroke: C.border,
    main: 'CENTER',
    cross: 'CENTER',
  });
  back.appendChild(T('‹', 'h3', { size: 18, color: C.text2 }));
  head.appendChild(back);
  head.appendChild(T('Card studio', 'h3'));
  growSpacer();
  head.appendChild(badge('9:16', 'neutral'));
  screen.appendChild(head);

  const stage = V('Stage', { w: 377, h: 620, main: 'CENTER', cross: 'CENTER', gap: 0 });
  const glow = circle('Stage glow', 400, {
    grad: rad(
      [
        { hex: C.accent, at: 0, a: 0.24 },
        { hex: C.accentAlt, at: 0.46, a: 0.07 },
        { hex: C.accentAlt, at: 0.68, a: 0 },
      ],
      1
    ),
  });
  stage.appendChild(glow);
  abs(glow, -11, 100, 400, 400);

  const card = receiptFrame();
  stage.appendChild(card);
  screen.appendChild(stage);

  const cap = H('Caption', { w: 361, h: 24, main: 'CENTER', cross: 'CENTER', gap: 5 });
  cap.appendChild(T('✓ 1080 × 1920 · exported from one isolated frame', 'caption', {
    size: 9,
    color: C.muted,
  }));
  screen.appendChild(cap);

  screen.appendChild(growSpacer());

  const share = ctaButton('Share receipt to X / Story', null, 'primary');
  fillH(share);
  screen.appendChild(share);
  screen.appendChild(spacer(8));
  const save = ctaButton('Save to photos', null, 'outline');
  fillH(save);
  screen.appendChild(save);

  const home = homeIndicator();
  screen.appendChild(abs(home, 130, 839, 132, 5));

  return screen;
}

// ---------------------------------------------------------------------------
// 12. Screen 4 — Renewal & kill-switch
// ---------------------------------------------------------------------------

function screenDetail(x) {
  const screen = V('04 · Renewal & Kill-Switch', {
    w: 393,
    h: 852,
    fill: C.bg,
    clip: true,
    pad: [0, 16, 126, 16],
    gap: 0,
  });
  screen.x = x;
  screen.y = 0;
  screen.primaryAxisSizingMode = 'FIXED';

  screen.appendChild(statusBar());

  const head = H('TopBar', { w: 361, h: 48, gap: 10, cross: 'CENTER' });
  const back = H('Back', {
    w: 44,
    h: 44,
    radius: 14,
    fill: '#131318',
    stroke: C.border,
    main: 'CENTER',
    cross: 'CENTER',
  });
  back.appendChild(T('‹', 'h3', { size: 18, color: C.text2 }));
  head.appendChild(back);
  head.appendChild(T('Subscription', 'h3', { size: 15 }));
  growSpacer();
  const more = H('More', {
    w: 44,
    h: 44,
    radius: 14,
    fill: '#131318',
    stroke: C.border,
    main: 'CENTER',
    cross: 'CENTER',
  });
  more.appendChild(T('•••', 'micro', { size: 9, color: C.text2, ls: 0 }));
  head.appendChild(more);
  screen.appendChild(head);

  screen.appendChild(spacer(8));

  // identity card
  const id = H('Card / Identity', {
    w: 361,
    pad: 13,
    gap: 11,
    radius: 16,
    grad: lin([{ hex: '#17141A', at: 0 }, { hex: C.surface, at: 1 }], 150),
    stroke: C.border,
    cross: 'CENTER',
  });
  id.appendChild(tile('AI', '#10A37F', 44));
  const idt = V('names', { gap: 3 });
  idt.appendChild(T('ChatGPT Plus', 'h3', { size: 14.5 }));
  idt.appendChild(T('[OI] · monthly · since Oct ’25', 'micro', { size: 9, color: C.muted, ls: 1 }));
  fillH(idt);
  id.appendChild(idt);
  id.appendChild(badge('ACTIVE', 'safe'));
  screen.appendChild(id);

  screen.appendChild(spacer(8));

  // renewal alert
  const alert = H('Card / RenewalAlert', {
    w: 361,
    pad: 13,
    gap: 12,
    radius: 16,
    grad: lin([{ hex: C.warn, at: 0, a: 0.11 }, { hex: C.surface, at: 1, a: 0.92 }], 148),
    stroke: C.warn,
    strokeOpacity: 0.3,
    cross: 'CENTER',
  });
  const at = V('text', { gap: 0 });
  at.appendChild(T('RENEWS IN', 'label', { color: '#C79A4B', size: 8, ls: 12 }));
  at.appendChild(T('14h 22m', 'moneyLg', { size: 25, lh: 27, color: C.warnSoft }));
  at.appendChild(spacer(6));
  const sub = H('sub', { gap: 4, cross: 'CENTER' });
  sub.appendChild(T('₹1,660 on Mon 9 Nov · ', 'caption', { size: 9, color: C.text2 }));
  sub.appendChild(T('•• 4242', 'micro', { size: 8.5, color: C.text }));
  at.appendChild(sub);
  fillH(at);
  alert.appendChild(at);

  const ringWrap = H('ring', { w: 50, h: 50, main: 'CENTER', cross: 'CENTER' });
  const ring = figma.createEllipse();
  ring.name = 'progress ring';
  ring.resize(50, 50);
  ring.fills = [];
  ring.strokes = [solid(C.warnSoft, 0.9)];
  ring.strokeWeight = 3.5;
  ring.strokeAlign = 'INSIDE';
  ring.arcData = { startingAngle: -Math.PI / 2, endingAngle: Math.PI * 0.7, innerRadius: 0.84 };
  ringWrap.appendChild(ring);
  ringWrap.appendChild(T('60%', 'micro', { size: 8.5, color: C.warnSoft, ls: -2 }));
  alert.appendChild(ringWrap);
  screen.appendChild(alert);

  screen.appendChild(spacer(8));

  // spend card
  const spend = V('Card / TotalSpent', {
    w: 361,
    pad: 15,
    gap: 3,
    radius: 18,
    grad: lin([{ hex: '#141419', at: 0 }, { hex: '#101014', at: 1 }], 165),
    stroke: C.border,
  });
  spend.appendChild(T('TOTAL SPENT SINCE SIGNUP', 'label', { color: C.muted }));
  const big = H('big', { gap: 5, cross: 'CENTER' });
  big.appendChild(T('₹12,480', 'moneyLg', { color: C.text }));
  big.appendChild(T('13 mo', 'micro', { size: 10, color: '#6E6E78', ls: 0 }));
  spend.appendChild(big);
  spend.appendChild(
    T('avg ₹960/mo · price rose to ₹1,660 in Jun ’26', 'micro', { size: 9, color: C.muted, ls: 0 })
  );
  spend.appendChild(spacer(12));

  const bars = H('bars', { w: 331, h: 34, gap: 3, cross: 'MAX' });
  const heights = [14, 14, 14, 14, 14, 14, 14, 20, 20, 20, 29, 29, 29];
  heights.forEach((h, i) => {
    const hi = i >= 10;
    bars.appendChild(
      rect('bar ' + (i + 1), 22, h, {
        grad: hi ? BURN_V() : null,
        fill: hi ? null : i >= 7 ? '#33333B' : '#25252C',
        radius: 2,
      })
    );
  });
  spend.appendChild(bars);

  const axis = H('axis', { w: 331, main: 'SPACE_BETWEEN' });
  axis.appendChild(T('OCT ’25', 'micro', { size: 7, color: C.muted, ls: 6 }));
  axis.appendChild(T('JUN ’26', 'micro', { size: 7, color: C.muted, ls: 6 }));
  axis.appendChild(T('NOV ’26', 'micro', { size: 7, color: C.muted, ls: 6 }));
  spend.appendChild(axis);
  screen.appendChild(spend);

  screen.appendChild(spacer(8));

  // guilt row
  const guilt = H('Card / UsageGuilt', {
    w: 361,
    h: 56,
    pad: [12, 13, 12, 13],
    gap: 10,
    radius: 12,
    fill: C.surface,
    stroke: C.border,
    cross: 'CENTER',
  });
  const gt = V('text', { gap: 2 });
  gt.appendChild(T('Usage guilt', 'body', { size: 11 }));
  gt.appendChild(T('Opened 2h ago · 22 sessions this month', 'micro', { size: 8.5, color: C.muted, ls: 0 }));
  fillH(gt);
  guilt.appendChild(gt);
  guilt.appendChild(badge('DAILY DRIVER', 'safe'));
  screen.appendChild(guilt);

  screen.appendChild(spacer(10));

  // reminder row
  const rem = H('Card / Reminder', {
    w: 361,
    h: 56,
    pad: [12, 13, 12, 13],
    gap: 10,
    radius: 12,
    fill: C.surface,
    stroke: C.border,
    cross: 'CENTER',
  });
  const rt = V('text', { gap: 2 });
  rt.appendChild(T('Renewal reminder', 'body', { size: 11 }));
  rt.appendChild(T('Local push · 24h before charge', 'micro', { size: 8.5, color: C.muted, ls: 0 }));
  fillH(rt);
  rem.appendChild(rt);
  const sw = H('Switch', { w: 48, h: 28, radius: 14, grad: BURN(), pad: [3, 3, 3, 3], main: 'MAX', cross: 'CENTER' });
  sw.appendChild(circle('knob', 22, { fill: '#FFFFFF' }));
  rem.appendChild(sw);
  screen.appendChild(rem);

  screen.appendChild(spacer(10));

  // cancel timeline
  const tl = V('Card / CancelTimeline', {
    w: 361,
    pad: [12, 13, 13, 13],
    gap: 0,
    radius: 12,
    grad: lin([{ hex: C.safe, at: 0, a: 0.055 }, { hex: '#0D0D11', at: 0.46, a: 1 }], 150),
    stroke: '#23262A',
  });
  const tlh = H('head', { w: 335, main: 'SPACE_BETWEEN', cross: 'MIN' });
  const tlt = V('left', { gap: 4 });
  tlt.appendChild(T('IF YOU CANCEL TODAY', 'label', { color: '#5FC9A3', size: 10 }));
  const save = H('save', { gap: 4, cross: 'CENTER' });
  save.appendChild(T('Keep ', 'caption', { size: 10, color: '#8FA8A0' }));
  save.appendChild(T('₹19,920', 'moneySm', { color: '#EAFBF4' }));
  save.appendChild(T(' / yr', 'micro', { size: 9, color: '#8FA8A0', ls: 0 }));
  tlt.appendChild(save);
  tlh.appendChild(tlt);
  tlh.appendChild(badge('13 MO CLEAN', 'safe'));
  tl.appendChild(tlh);
  tl.appendChild(spacer(11));

  const steps = [
    ['NOW', 'Reminder cancelled, card untouched', true],
    ['9 NOV', 'No ₹1,660 charge. Nothing renews.', false],
    ['8 DEC', 'First month you keep the money', false],
  ];
  steps.forEach(([h, d, on], i) => {
    const row = H('step ' + h, { w: 335, gap: 9, cross: 'MIN', pad: [0, 0, i === 2 ? 0 : 9, 0] });
    row.appendChild(circle('dot', 7, { fill: on ? C.safe : '#2C2C34', stroke: '#3A3A43' }));
    const txt = V('text', { gap: 2 });
    txt.appendChild(T(h, 'micro', { size: 8, color: '#B9B9C0', ls: 7 }));
    txt.appendChild(T(d, 'micro', { size: 8.5, color: C.muted, ls: 0 }));
    row.appendChild(txt);
    tl.appendChild(row);
  });
  screen.appendChild(tl);

  // dock
  const dock = V('Dock', { w: 393, pad: [12, 16, 22, 16], gap: 7, fill: C.bg });
  const cancel = ctaButton('Cancel subscription URL', null, 'danger');
  fillH(cancel);
  dock.appendChild(cancel);
  const note = H('note', { w: 361, gap: 5, cross: 'MIN' });
  note.appendChild(T('ⓘ', 'micro', { size: 8, color: C.muted, ls: 0 }));
  note.appendChild(
    T("Opens the vendor's official cancellation page. SubBurn never touches your credentials.", 'caption', {
      size: 9,
      color: C.muted,
    })
  );
  dock.appendChild(note);
  screen.appendChild(abs(dock, 0, 736, 393, 116));

  const home = homeIndicator();
  screen.appendChild(abs(home, 130, 839, 132, 5));

  return screen;
}

// ---------------------------------------------------------------------------
// 13. Design-system page
// ---------------------------------------------------------------------------

function buildDesignSystem(page) {
  const root = V('Design System / SubBurn', { pad: 40, gap: 32, fill: '#060608' });
  page.appendChild(root);

  root.appendChild(T('SUBBURN — DESIGN SYSTEM', 'h2'));
  root.appendChild(
    T('393 × 852 · 16 px padding · 8 px grid · dark only', 'micro', {
      size: 9,
      color: C.muted,
      ls: 8,
    })
  );

  // colours
  const swatchRow = H('swatches', { gap: 8 });
  const swatches = [
    ['BG', C.bg],
    ['SURFACE', C.surface],
    ['BORDER', C.border],
    ['ACCENT', C.accent],
    ['ACCENT ALT', C.accentAlt],
    ['SAFE', C.safe],
    ['WARN', C.warn],
    ['DANGER', C.danger],
    ['TEXT', C.text],
    ['TEXT 2', C.text2],
    ['MUTED', C.muted],
  ];
  for (const [name, hex] of swatches) {
    const cell = V('swatch / ' + name, { w: 84, gap: 6 });
    cell.appendChild(rect(name, 84, 56, { fill: hex, radius: 8, stroke: '#2A2A31' }));
    cell.appendChild(T(name, 'micro', { size: 7, color: C.muted, ls: 8 }));
    cell.appendChild(T(hex, 'micro', { size: 7, color: C.text2, ls: 0 }));
    swatchRow.appendChild(cell);
  }
  root.appendChild(swatchRow);

  // type ramp
  const ramp = V('type ramp', { gap: 10 });
  const rows = [
    ['display 58 / mono', '₹4,850', 'display'],
    ['h1 25 / UI 800', 'MY 2026 AI TAX RECEIPT', 'h1'],
    ['h2 22 / UI 800', 'Add subscription', 'h2'],
    ['h3 16 / UI 800', 'Card studio', 'h3'],
    ['section 13 / UI 700', 'Renewing soon', 'section'],
    ['body 12 / UI 500', 'ChatGPT Plus', 'body'],
    ['caption 10 / UI 500', 'Opened 2h ago', 'caption'],
    ['label 10 / UI 700', 'MONTHLY BURN', 'label'],
    ['micro 8 / mono 600', '48H WINDOW', 'micro'],
  ];
  for (const [label, sample, style] of rows) {
    const r = H('row / ' + style, { gap: 16, cross: 'CENTER' });
    r.appendChild(T(sample, style));
    r.appendChild(T(label, 'micro', { size: 7, color: C.muted, ls: 6 }));
    ramp.appendChild(r);
  }
  root.appendChild(ramp);
}

// ---------------------------------------------------------------------------
// 14. Main
// ---------------------------------------------------------------------------

async function main() {
  await figma.loadAllPagesAsync();
  await loadFonts();

  const screenPage =
    figma.root.children.find((p) => p.name === 'SubBurn · 4 Screens') || figma.createPage();
  screenPage.name = 'SubBurn · 4 Screens';
  await figma.setCurrentPageAsync(screenPage);

  // clean up a previous run so the plugin is re-runnable
  for (const child of [...screenPage.children]) child.remove();

  makePaintStyles();
  makeTextStyles();

  const board = H('SubBurn / Board', { gap: 48, pad: 48, fill: '#060608' });
  board.name = 'SubBurn / Board';
  screenPage.appendChild(board);

  board.appendChild(screenDashboard(0));
  board.appendChild(screenQuickAdd(441));
  board.appendChild(screenCardStudio(882));
  board.appendChild(screenDetail(1323));

  // design system page
  let dsPage = figma.root.children.find((p) => p.name === 'SubBurn · Design System');
  if (!dsPage) {
    dsPage = figma.createPage();
    dsPage.name = 'SubBurn · Design System';
  }
  await figma.setCurrentPageAsync(dsPage);
  for (const child of [...dsPage.children]) child.remove();
  buildDesignSystem(dsPage);

  await figma.setCurrentPageAsync(screenPage);
  const view = screenPage.children.find((n) => n.name === 'SubBurn / Board');
  if (view) figma.viewport.scrollAndZoomIntoView([view]);

  figma.notify('SubBurn built — 4 screens, 14 paint styles, 11 text styles.', {
    timeout: 6000,
  });
  figma.closePlugin();
}

main().catch((err) => {
  figma.notify('SubBurn build failed: ' + err.message, { error: true, timeout: 12000 });
  console.error(err);
  figma.closePlugin();
});
