# SubBurn — Design & Build Handoff

**AI & SaaS subscription guilt tracker.** Dark-mode-only, 393 × 852, 8 px grid,
built around one shareable artefact: the yearly burn receipt.

Two deliverables live side by side here:

- **`index.html`** — the design source of truth. Every PNG is rendered from it,
  so screenshots cannot drift from the spec.
- **`flutter/`** — the production app. Local-first, four screens, 32 tests,
  `flutter analyze` clean.

---

## Table of contents

1. [The four screens](#the-four-screens)
2. [Design tokens](#design-tokens)
3. [Figma file](#figma-file)
4. [Flutter app](#flutter-app)
5. [Infrastructure at $0](#infrastructure-at-0)
6. [RepaintBoundary export contract](#repaintboundary-export-contract)
7. [Verification](#verification)
8. [Reproducing everything](#reproducing-everything)
9. [Decisions worth knowing](#decisions-worth-knowing)
10. [Known gaps](#known-gaps)

---

## The four screens

### 01 · Burn Dashboard — `renders/frame-1.png`

The default screen. Answers one question in under a second: *how much am I
burning, and how much of it is waste?*

| Region | Content | Notes |
|---|---|---|
| Top bar | Logo, wordmark, currency chip | 48 px |
| Hero (164 px) | `₹4,850 / mo` at 58 px mono, gradient-clipped | radial orange bloom clipped to the 24 px radius |
| Hero sub | `₹1,245 is ghost spend` | the guilt line |
| Split bar | 74.3 % active vs **25.7 % ghost** | the only chart on the screen |
| Renewing soon | Horizontal rail, 148 px cards, pulsing amber countdown | masks off at 86 % to signal scroll |
| Subscriptions | 5 rows, 56 px, monogram + monthly price | ghost rows get a **dashed** border |
| Ghost callout | `25.7 % of your burn is ghost subs` → REVIEW | |
| Tab bar | Burn · Receipts · FAB · Renewals · Controls | 64 px + safe area |

**Why it works:** the hero number is the product. Everything else is a
supporting argument, and the split bar makes that argument visual before you
read a single row.

### 02 · Quick Add — `renders/frame-2.png`

A bottom sheet whose job is a real subscription in the ledger in under ten
seconds.

| Region | Content |
|---|---|
| Handle + title | `Add subscription` 22 px w800 |
| Search | Instant, offline, 124 presets |
| Tool grid | 4 × 3 preview, 1-tap select, orange ring + check |
| Name | Free text, prefilled from the preset |
| Billing cycle | Weekly / Monthly / Yearly `−17 %` |
| Price | ₹ INR / $ USD toggle, converts at the CDN rate |
| Usage guilt | `Daily Driver` (green dot) / `Barely Touch It` (amber dot) |
| CTA | `Add to burn tracker` + live `₹1,660 /mo` chip |

### 03 · Card Studio — `renders/frame-3.png`

The viral loop. A 9:16 receipt sits centred on a stage with a dashed export
guide; the share CTA is the brightest thing on the screen.

Receipt contents: brand line, `MY 2026 AI TAX RECEIPT`, dotted rules, five
itemised tools at `monthly × 12`, ghost meter, three-up audit stats,
`₹58,200 /yr` total, roast badge, verdict line, barcode and QR.

**The roast is the hook and it costs nothing to generate.** `roast_engine.dart`
is a deterministic function of the ledger: yearly burn → one of five tiers,
then a template from that tier, then a verdict comparison. Same input, same
receipt, on every device, forever. No AI API, no network, no per-share cost.

> **TIER: SILICON VALLEY PAYPIG** — Paying ₹58,200/yr to generate memes and fix
> center divs.

### 04 · Renewal & Kill-Switch — `renders/frame-4.png`

| Region | Content |
|---|---|
| Identity card | Monogram, name, vendor, billing, `ACTIVE` badge |
| Renewal alert | `14h 22m` in amber mono + progress ring, amount, date |
| Total spent | Lifetime burn, charge count, sparkline |
| Usage guilt | `DAILY DRIVER` — tap to toggle ghost status |
| Renewal reminder | Local push toggle, 48 h and 24 h |
| If you cancel today | 3-step timeline + `Keep ₹19,920 / yr` |
| Dock | `Cancel with [OI] ↗` (danger) + privacy reassurance |

The kill-switch is deliberately **not** the loudest element. Shame converts
worse than arithmetic: `₹19,920/yr` does more work than a red button.

---

## Design tokens

Source of truth: `design-tokens.json` → `flutter/lib/core/theme/theme_tokens.dart`
(and `app_theme.dart` for the Material binding).

### Colour

| Token | Hex | Role |
|---|---|---|
| `bg` | `#09090B` | canvas / rich obsidian |
| `surface` | `#121216` | card / row |
| `surfaceHi` | `#17171C` | raised |
| `border` | `#27272A` | 1 px hairline |
| `borderHi` | `#3F3F46` | divider, inactive track |
| `accent` | `#FF4500` | electric burn orange |
| `accentAlt` | `#FF8C00` | gradient end |
| `accentWarm` | `#FFB27A` | orange **text** on dark (AA) |
| `safe` | `#10B981` | active / daily driver |
| `warn` | `#F59E0B` | renews < 48 h, ghost spend |
| `danger` | `#EF4444` | cancel / over budget |
| `text` | `#FAFAFA` | primary |
| `textSecondary` | `#A1A1AA` | secondary |
| `textMuted` | `#9A9AA4` | captions — **5.6:1, AA** |
| `mutedDeco` | `#52525B` | decoration only, never text |

> **Deviation from the brief, on purpose:** `#52525B` measures ~2.9:1 on
> `#121216`. It fails WCAG AA at caption sizes, so it is kept as
> `mutedDeco` for hairlines and gradients, and captions use `#9A9AA4`.

### Type

Plus Jakarta Sans for UI, JetBrains Mono for every numeral, price and
countdown. Both are bundled (`assets/fonts` and `assets/google_fonts`) and the
mono face carries a **transplanted ₹ glyph** — upstream JetBrains Mono has no
U+20B9, so `tools/build_fonts.py` instances the variable font, borrows the
outline from Noto Sans Mono, scales it to 0.94 em and centres it on the 600-unit
mono advance. Without it every price would fall back to another family
mid-number.

| Style | Size / LH | Weight | Family | Tracking |
|---|---|---|---|---|
| display | 58 / 58 | 600 | mono | −0.055 em |
| h1 | 25 / 26 | 800 | UI | −0.035 em |
| h2 | 22 / 24 | 800 | UI | −0.035 em |
| h3 | 16 / 20 | 800 | UI | −0.03 em |
| section | 13 / 16 | 700 | UI | −0.015 em |
| body | 12 / 16 | 500 | UI | 0 |
| caption | 10 / 14 | 500 | UI | 0 |
| label | 10 / 12 | 700 | UI | +0.115 em |
| micro | 9 / 11 | 600 | mono | +0.06 em |
| moneyLg | 34 / 36 | 600 | mono | −0.055 em |
| moneyMd | 16 / 18 | 600 | mono | −0.04 em |
| moneySm | 12 / 14 | 600 | mono | −0.03 em |

### Space / radius / elevation

- Grid 8 px; 4 px is the only half-step.
- Radius: `tile 10 · inner 12 · button 14 · composite 18 · hero 24 · sheet 26 · device 46`
- Elevation in a dark UI is an **inner top highlight** plus an orange bloom on
  emphasis surfaces only. No grey drop shadows.

### Numbers that must agree

| Rule | Value | Where it is enforced |
|---|---|---|
| Ghost share | **25.7 %** (1,245 / 4,850 = 25.67 %) | `BurnSummary.ghostShare`, printed with 1 decimal everywhere |
| Ghost spend | **₹14,940 / yr** | `BurnSummary.ghostYearly`, passed to the receipt explicitly |
| Yearly total | **₹58,200** | `BurnSummary.yearly` |
| Yearly discount | **17 %** → `12 × monthly × 0.83` | `ReceiptLine.billedYearly` |
| Renewal window | **48 h** | `SbWindow.renewingHours` |
| Reminders | **48 h and 24 h** | `NotificationService.scheduleFor` |

v1 shipped `26 %` next to `₹1,245`, which is 26 % of ₹4,850 = ₹1,261. The
percentage is now generated from the same division as the rupees, and a test
asserts `ghostShare × monthly == ghostMonthly`.

---

## Figma file

**[01 · SubBurn](https://www.figma.com/design/NNx8tBFR3qjmHjGBEsxuu1/01-SubBurn)**

| Frame | Node ID | Size |
|---|---|---|
| 01 · Burn Dashboard | `14:55` | 393 × 852 |
| 02 · Quick Add | `14:162` | 393 × 852 |
| 03 · Card Studio | `14:246` | 393 × 852 |
| 04 · Renewal & Kill-Switch | `14:495` | 393 × 852 |

Built as ~440 **editable** nodes via the `figma-rw` MCP — real auto-layout, 14
paint styles, 7 text styles. Frame 3 contains
`ExportFrame/Receipt 360x640`, the isolated export node.

> **JetBrains Mono is not installed in this Figma instance**, so numerals there
> use **Inter**. The Flutter app uses the bundled JetBrains Mono. The ₹ glyph
> exists in both, so no screenshot shows a fallback box.

Layer map, auto-layout directions and gaps are documented below for anyone
rebuilding the file.

```
SubBurn / 01 · Burn Dashboard        (Frame 393×852, bg #09090B)
├── StatusBar                        (H 54, px 25)
├── Page                             (V, gap 0, px 16)
│   ├── TopBar                       (H, gap 8, H 48, space-between)
│   ├── HeroCard                     (V, gap 8, H 164, pad 16, r 24)
│   │   ├── Glow                     (ellipse 280, radial, clipped)
│   │   ├── Amount                   (58 px mono, gradient fill)
│   │   ├── SplitBar                 (H, gap 2, H 7, r 4)  ← 74.3 / 25.7
│   │   └── Legend                   (H, space-between)
│   ├── SectionHeader/Renewing
│   ├── Rail/Renewing                (H, gap 10, H 106, overflow horizontal)
│   ├── SectionHeader/Active
│   ├── List/Subscriptions           (V, gap 8) → SubRow × 5
│   └── Callout/Ghost                (H, gap 10, H 60, r 12)
├── TabBar                           (H, space-between, H 80, absolute bottom)
└── HomeIndicator
```

`SubRow` is a component with a `ghost` boolean variant that switches the border
to dashed and dims the monogram. `RenewalCard` has an `urgency` variant
(`today` / `tomorrow` / `later`) driving badge tone and the pulse.

---

## Flutter app

```
flutter/
├── pubspec.yaml                    # no paid services, no runtime font fetch
├── android/                        # 16 KB page size, inexact alarms only
├── assets/
│   ├── fonts/                      # PJS + JBM subsets with ₹ injected
│   ├── google_fonts/               # same faces, google_fonts naming
│   └── json/                       # presets_v1.json (124 tools) + rates.json
├── lib/
│   ├── main.dart                   # boot order, runZonedGuarded
│   ├── app.dart
│   ├── core/theme/                 # tokens + Material 3 theme
│   ├── core/utils/formatters.dart  # countdowns, dates, amount parsing
│   ├── data/models/                # subscription, cycle, guilt, currency, preset
│   ├── data/hive/                  # hand-written stable adapters
│   ├── data/repositories/          # Hive store + first-run seed
│   ├── features/                   # dashboard, quick_add, studio, detail, renewals, controls, shell
│   ├── services/                   # catalogue, notifications, analytics, share, OneSignal, Firebase
│   ├── state/providers.dart        # one Riverpod graph
│   └── widgets/                    # receipt, hero, pills, badges, tiles, buttons
└── test/
    ├── subburn_test.dart           # 26 unit/widget tests
    ├── screens_preview_test.dart   # 6 golden renders of every screen
    └── goldens/                    # 393×852 @2x PNGs
```

### State

`flutter_riverpod` notifiers only — no BLoC, no service locator.

| Provider | Role |
|---|---|
| `subscriptionsProvider` | live list; every mutation writes Hive **first**, then re-reads |
| `settingsProvider` | currency, reminders, install id |
| `catalogueProvider` | CDN → 7-day cache → bundled, never throws |
| `burnSummaryProvider` | **single source of every number on screen** |
| `renewingSoonProvider` | the 48-hour queue |

### Storage

`hive_ce` with two boxes: `subscriptions_v1` and `settings_v1`. Adapters are
written by hand so the on-disk field order is code-reviewed; new fields append,
never reorder. A round-trip test covers every field.

First launch seeds five realistic rows exactly once (`settings.seeded`). They
are ordinary subscriptions — swipe-to-delete works.

### Notifications

Two per subscription, 48 h and 24 h before the charge, scheduled with
`AndroidScheduleMode.inexactAllowWhileIdle`. Inexact alarms need no
`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`, so Play review does not require the
alarms-and-reminders special access declaration. Notification ids are a stable
FNV-1a hash of the subscription id, so they survive reinstalls of the app data.

---

## Infrastructure at $0

| Concern | Implementation | Cost model |
|---|---|---|
| User data | Hive CE, on device | Zero server writes |
| Presets (124 tools) | Cloudflare R2 `subburn-cdn`, `presets_v1.json` | Free tier; cached 7 days; bundled fallback |
| FX rate | R2 `rates.json`, same bucket | One object |
| Analytics | Firebase Spark, 2 events | Free, unlimited on Spark |
| Crash reports | Crashlytics, collection disabled in debug | Free |
| Remote config | Spark, 12-hour minimum fetch | Free |
| Push | OneSignal, broadcast only | Free |
| CI | `flutter analyze && flutter test` | — |

**CDN**: `https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev`
Override at runtime through Remote Config key `cdn_base_url`.

**Firebase project**: `subburn-1b744` (Spark), Android app
`com.subburn.subburn`, config at `flutter/android/app/google-services.json`.

Every network dependency degrades: no CDN → cached or bundled catalogue; no
Firebase → analytics no-ops and the app opens anyway; no notification permission
→ the app works without reminders.

---

## RepaintBoundary export contract

The receipt is built to be captured. It sets its own 360 × 640 box, reads no
`Theme` or `MediaQuery`, clips its own glows, and pins the barcode strip to the
bottom edge so the layout can never float mid-card.

```dart
final key = GlobalKey();

RepaintBoundary(
  key: key,
  child: SubBurnReceiptCard(
    lines: const [
      ReceiptLine(name: 'ChatGPT Plus',   monthly: 1660),
      ReceiptLine(name: 'Claude Pro',     monthly: 1660),
      ReceiptLine(name: 'Cursor Pro',     monthly: 830),
      ReceiptLine(name: 'GitHub Copilot', monthly: 415),
      ReceiptLine(name: 'Midjourney',     monthly: 285),
    ],
    roastTier: 'Silicon Valley Paypig',
    roastLine: 'Paying ₹58,200/yr to generate memes and fix center divs.',
    ghostShare: 0.2567,
    ghostAmount: 14940,      // pass the real figure, never derive it
    receiptNo: 'No. 00412',
    totalOverride: 58200,
  ),
);

final image = await boundary.toImage(pixelRatio: 3); // → 1080 × 1920
```

`ShareService` does exactly this and hands the PNG to `share_plus`. A test
asserts `1080 × 1920` from a real `toImage` call.

If a longer roast or a sixth line would overflow, the content column is wrapped
in `FittedBox(scaleDown)` so the card scales by a fraction rather than clipping.

---

## Verification

```
$ python3 tools/audit.py
GEOMETRY       4/4 frames 393×852, content clears chrome
GRADIENT TEXT  3 elements (verified by design)
CONTRAST       0 below WCAG AA
TAP TARGETS    0 under 44×44
OVERFLOW       0 elements out of frame
PASS

$ python3 tools/render.py
layout audit: clean
board.png: (3600, 2324)
receipt-card.png: (1080, 1920)

$ cd flutter && flutter analyze
No issues found!

$ cd flutter && flutter test
00:02 +32: All tests passed!
```

Tests cover: Indian and western money grouping, amount parsing, countdown
formatting, all three billing cycles, USD conversion, prorated lifetime spend,
the 25.7 % ghost identity, zero-ledger safety, the 48-hour queue, roast
determinism and band escalation, template-placeholder leakage, the 360 × 640
box with no child escaping it, a real 1080 × 1920 PNG, Hive round-trips,
catalogue integrity (124 tools, unique ids, every cancel URL https), search,
pills, hero, and 44 px tap targets.

---

## Reproducing everything

```bash
cd subburn

python3 tools/build_fonts.py     # only if fonts change: subset + inject ₹
python3 tools/gen_presets.py     # 124 presets -> assets/json (+ R2 payload)
python3 tools/render.py          # board.png, frame-*.png, receipt-card.png
python3 tools/audit.py           # exit 1 on any FAIL

cd flutter
flutter pub get
flutter analyze
flutter test
flutter test test/screens_preview_test.dart --update-goldens  # refresh previews
```

Push the catalogue to the CDN:

```bash
cd /tmp
npx wrangler r2 object put subburn-cdn/presets_v1.json \
  --file /root/subburn/flutter/assets/json/presets_v1.json \
  --content-type application/json --remote
npx wrangler r2 object put subburn-cdn/rates.json \
  --file /root/subburn/flutter/assets/json/rates.json \
  --content-type application/json --remote
```

---

## Decisions worth knowing

**The rupee glyph was broken and was fixed.** JetBrains Mono has no U+20B9, so
every price would have fallen back to another family at 58 px. The font is
patched at build time rather than swapping to a worse mono.

**Ghost subscriptions look different, not just dimmer.** Dashed border,
desaturated monogram, amber label. Colour alone fails for colour-blind users,
and this is the most important state in the product.

**The renewal pulse is the only animation.** One thing moves, so it means
something. It respects the reduced-motion setting on web and is a ticker with a
real `dispose` in Flutter.

**Ghost amounts are passed in, not derived.** `0.2567 × ₹58,200` rounds to
₹14,945; the real figure is ₹14,940. A receipt that misprints its own number is
worse than no receipt, so `ghostAmount` is an explicit parameter.

**No third-party logos.** Monograms instead of brand marks: trademark-safe, zero
asset weight, consistent at 30 px. Each monogram's text colour is lifted 52 %
toward white so it clears 4.5:1 on its tint.

**The roast is deterministic.** Same ledger → same receipt. It makes the card
comparable between friends, it works offline, and it costs nothing per share.

---

## Known gaps

1. **OneSignal is wired but has no app id.** Registration needs an interactive
   login (the dashboard blocked automated sign-in). Set `onesignal_app_id` in
   Remote Config and push goes live — no code change, no release.
2. **Crashlytics is code-complete but takes its first symbol upload on the first
   release build with a real keystore.** Debug collection is intentionally off.
3. **Release signing uses the debug keystore.** Swap in the upload keystore
   before the first Play upload; `flutter build appbundle` otherwise works.
4. **iOS is generated but unconfigured** — no `GoogleService-Info.plist`, no
   APNs key. Android is the shipping target.
5. **The receipt QR is a visual motif, not a scannable code.** It needs a real
   payload and a `qr_flutter` dependency to become one.
6. **Accessibility is tested at the widget level.** No screen-reader walkthrough
   on a device, and no 200 % text-scale pass; the 130 % clamp in `MoneyText` is
   a mitigation, not a substitute.
7. **No automated Play Console upload.** The AAB builds; the listing, data
   safety form and screenshots are manual.
