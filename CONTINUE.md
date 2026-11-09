# SubBurn — CONTINUE

> **Agent instruction:** read this file, then start work. This file is a
> temporary handoff. **When the task in it is complete, delete this file.**

---

## Say this to resume

> continue this file CONTINUE.md

---

## What this project is

SubBurn — a 4-screen mobile UI for an **AI & SaaS subscription guilt tracker**.
Dark mode only. 393 × 852 (iPhone 15 Pro). 16px page padding. 8px spatial grid.
48px gutter between artboards in Figma.

The hook: it turns your yearly subscription burn into a **shareable roast
receipt** for Instagram Stories / X.

---

## Where everything lives

**Project root: `/root/subburn`** (run opencode from here)

| Path | What it is |
|---|---|
| `index.html` | **SOURCE OF TRUTH.** All tokens + all 4 frames in CSS. Every PNG and SVG is generated from this, so they can never drift. |
| `design-tokens.json` | Machine-readable tokens |
| `HANDOFF.md` | Design rationale, token tables, Figma layer map, `RepaintBoundary` export contract |
| `README.md` | Short entry point |
| `renders/board.png` | All 4 frames, 48px gap, @2x |
| `renders/frame-1..4.png` | Single frames @3x (1179 × 2556) |
| `renders/receipt-card.png` | Isolated 9:16 card, exactly 1080 × 1920 |
| `renders/svg/` | Per-frame SVGs for Figma import |
| `tools/render.py` | Regenerates every PNG + layout audit |
| `tools/audit.py` | WCAG contrast · 44px tap targets · frame overflow. **Currently PASS** |
| `tools/build_fonts.py` | Subsets PJS + JBM and **injects a ₹ (U+20B9) glyph into JBM** (upstream has none) |
| `flutter/` | Real package: 9 widgets, tokens, 7 tests, `flutter analyze` clean |
| `figma-plugin/` | Full desktop-app plugin (`manifest.json` + 1.8k lines `code.js`) that builds real auto-layout frames + styles. Unused so far — the MCP path won the web editor. |

### Live Figma file

**https://www.figma.com/design/NNx8tBFR3qjmHjGBEsxuu1/01-SubBurn**

Built as **~440 real editable nodes** via the `figma-rw` MCP — not images.
4 frames + 14 paint styles + 7 text styles.

| Frame | Node ID | Size |
|---|---|---|
| 01 · Burn Dashboard | `14:55` | 393 × 852 |
| 02 · Quick Add | `14:162` | 393 × 852 |
| 03 · Card Studio | `14:246` | 393 × 852 |
| 04 · Renewal & Kill-Switch | `14:495` | 393 × 852 |

Frame 3 contains `ExportFrame/Receipt 360x640` — the isolated export node.

---

## Decisions already locked (do not re-litigate)

- **Dark mode only.**
- **JetBrains Mono is NOT installed** in this Figma instance → all numerals use
  **Inter**. The ₹ glyph exists in both PJS and Inter. Do not reintroduce JBM.
- Frame 3's receipt is **360 × 640**, one self-contained node, so it maps to a
  single Flutter `RepaintBoundary`. Glows are clipped inside it — no shadows
  bleeding out (a bleed gets cut by the boundary and leaves a seam).
- `textMuted` was raised from the brief's `#52525B` to `#9A9AA4`. The original
  fails WCAG AA at caption sizes (~2.9:1). `#52525B` survives only as a
  **decoration** token.
- **Spend ledger:** 14 charges = 8 × ₹830 (Oct'25–May'26) + 6 × ₹1,660
  (Jun'26–Nov'26) = **₹16,570**, avg **₹1,184/mo**.
  Bar chart = 14 bars, last 6 orange (the Jun '26 price rise).
- **Receipt verdict:** `"That is 2 years of a Mumbai gym membership."`
  (₹58,200 does not buy a MacBook Air in India — starts ~₹99,900.)
- Receipt total **₹58,200/yr** and monthly **₹4,850** are correct and verified:
  1,660+1,660+830+415+285 = ₹4,850; × 12 = ₹58,200.

---

## Known open items (pick these up first)

1. **"Yearly save 17%" is unbacked.** Frame 2 claims it; Frame 3 books every tool
   at 12 × monthly with zero discount. Decide which is true and make them agree.
2. **Ghost share is inconsistent.** Actual is 25.67%; shown as 26%; but the ₹
   figure (₹1,245) is 26% of ₹4,850 = ₹1,261. Pick one and reconcile % and ₹.
3. **`"Cancel subscription URL"` is a literal placeholder.** Should read
   `"Cancel with [OI] ↗"` using the vendor from the row above it.
4. **Terminology drift.** "ghost", "unused", "dead weight", "buys nothing" all
   mean the same thing across the 4 screens. Unify.

---

## How to work

**For any visual change:**

```bash
cd /root/subburn
# edit index.html, then:
python3 tools/render.py     # regenerates every PNG
python3 tools/audit.py      # MUST stay PASS
```

**If you touch tokens**, update **both** (`design-tokens.json` and
`flutter/lib/theme/subburn_tokens.dart` — they're duplicated, not generated).

**After any component change:**

```bash
cd /root/subburn/flutter
flutter analyze && flutter test     # 7 tests must pass
```

**To push to Figma**, use the `figma-rw` MCP. If it reports
`plugin not connected`:

```bash
CDP_PORT=9223 FORCE_NAV=1 \
FIGMA_FILE_URL="https://www.figma.com/design/NNx8tBFR3qjmHjGBEsxuu1/01-SubBurn" \
node /root/bin/figma-ensure-plugin.js
```

Then **verify** `get_metadata().fileName === "01 SubBurn"` before writing.

If Figma Desktop itself is down:

```bash
systemctl restart figma-desktop
```

---

## Safety rules (hard requirements)

- **Only touch the SubBurn file** (key `NNx8tBFR3qjmHjGBEsxuu1`). The same Figma
  account also holds **ScrollBrake, ExamVault, SnapSweep** — never modify them.
  The MCP has been seen attached to the wrong file; **always check
  `get_metadata().fileName` first.**
- **Never press `Ctrl+A` on a Figma canvas** to "clear" a page. It selects across
  pages and has previously spawned stray Slides/Spec documents.
- **Never use File → Place image with an SVG** in the Figma *web* editor — it
  spawns a "Spec" document pane that covers the canvas. In the desktop app, place
  PNG, or write via the MCP directly.
- Figma MCP shape/gradient support is limited (solid fills + strokes only). For
  gradients either place the PNG or accept a solid approximation.

---

## Verification state at handoff

```
python3 tools/audit.py     → PASS   (0 contrast fails · 0 sub-44px targets · 0 overflow)
python3 tools/render.py    → layout audit: clean
flutter analyze            → No issues found
flutter test               → 7/7 passed
Figma get_metadata()       → fileName "01 SubBurn", 4 frames at x 0/441/882/1323
```

---

**Reminder: delete this file once the work is done.**
