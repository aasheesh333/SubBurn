/**
 * SubBurn — Figma design system spec.
 *
 * This file is the single source of truth that the figma-rw MCP build script
 * reads. It mirrors index.html / design-tokens.json exactly, but expressed as
 * Figma primitives (FRAME / RECTANGLE / TEXT) so the canvas can be rebuilt
 * losslessly at any time.
 *
 * Coordinates are absolute design-space (frame-local for children).
 */

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

// JetBrains Mono is not installed in this Figma instance, so all numeric
// text uses Inter (tabular-ish) — visually close, and the ₹ glyph exists.
const MONO = 'Inter';
const UI = 'Plus Jakarta Sans';

const TOOLS = [
  { name: 'ChatGPT Plus',   mark: 'AI', plan: 'OPENAI · PLUS',        color: '#10A37F', inr: 1660, guilt: 'daily'  },
  { name: 'Claude Pro',     mark: 'CL', plan: 'ANTHROPIC · PRO',      color: '#D97757', inr: 1660, guilt: 'daily'  },
  { name: 'Cursor Pro',     mark: 'CU', plan: 'ANYSPHERE · PRO',      color: '#9C9CA6', inr: 830,  guilt: 'barely' },
  { name: 'GitHub Copilot', mark: 'GH', plan: 'GITHUB · INDIVIDUAL',  color: '#A78BFA', inr: 415,  guilt: 'barely' },
  { name: 'Midjourney',     mark: 'MJ', plan: 'MIDJOURNEY · LITE',    color: '#7C8797', inr: 285,  guilt: 'daily'  },
];

const POPULAR = [
  ['AI','ChatGPT','#10A37F'], ['MJ','Midjourney','#7C8797'], ['CU','Cursor','#9C9CA6'], ['NF','Netflix','#E50914'],
  ['SP','Spotify','#1DB954'], ['GH','Copilot','#A78BFA'],     ['NO','Notion','#D4D4D8'], ['FG','Figma','#F24E1E'],
  ['AD','Adobe CC','#FA0F00'],['CV','Canva','#00C4CC'],       ['PX','Perplexity','#1FB8CD'], ['GR','Grammarly','#15C39A'],
];

// Indian grouping: 4850 -> 4,850 · 124000 -> 1,24,000
function inr(n) {
  let s = String(Math.round(n));
  if (s.length > 3) {
    const last3 = s.slice(-3);
    let head = s.slice(0, -3);
    const parts = [];
    while (head.length > 2) { parts.unshift(head.slice(-2)); head = head.slice(0, -2); }
    if (head) parts.unshift(head);
    s = parts.join(',') + ',' + last3;
  }
  return '₹' + s;
}

module.exports = { C, MONO, UI, TOOLS, POPULAR, inr };
