# Play Store screenshots — templates and the ready-to-upload set

Two things live here:

1. **Ready to upload right now** — `store/assets/screenshots-1080x1920/` (6
   frames, 1080 × 1920, headline + phone mockup, brand-matched). No Figma
   needed. Upload these if you want to ship today.
2. **Editable in Figma** — free community templates below, plus our own assets
   in `store/figma/` to drop straight in.

---

## Free Figma templates (checked Nov 2026)

Ranked by fit for SubBurn, not by popularity.

| # | Template | Why it suits us | Link |
|---|---|---|---|
| **1** | **The App Store Screenshot Sheet** — Cody Simmonds | Built *from the current store specs*, includes the Google Play phone/tablet frames **plus** the 1024×500 feature graphic and 512² icon. Frames are already the right ratio, so nothing gets rejected on export. Free, no plugin required. | `figma.com/community/file/...` via codysimmonds.substack.com/p/the-app-store-screenshot-sheet-a |
| **2** | **Free App Store & Play Store Screenshot Template** | 20 layouts (5 per device) covering Android phone + tablet; auto-layout components, so swapping a screenshot updates every size. Cleanest editing experience of the free files. | `figma.com/community/file/1567178403275769113` |
| **3** | **Google Play Store Screenshot Templates — BRIX Templates** | Vector-only, includes a **Pixel 7 Pro portrait frame** and the Play icon template. Best if you want the screenshots to look like real Android hardware. BRIX freebie licence covers commercial app use. | `figma.com/community/file/1171962232089988786` |
| 4 | App Store & Google Play Screenshot Template — Screenshot Store 2026 | Phone + tablet + desktop in one file, aimed at indie launches and A/B tests. | `figma.com/community/file/1656401505142216834` |
| 5 | 500+ App Store screenshot templates | Overkill for six frames, but useful when you want many style options to compare. | `figma.com/community/file/1471925742378558731` |
| 6 | Appstore and Google Play Screenshot Templates (all sizes, auto-scaling) | Good if you later add iOS; every element scales across sizes automatically. | `figma.com/community/file/1470068538633644101` |

**Skip** the files that need a paid plugin ("Mockup") to place images — several
of the older popular ones do, and reviewers in the comments report they break
aspect ratios. Templates 1–3 above do not.

### How to use one with our assets

1. Duplicate the Figma file (Community → Duplicate).
2. Delete its placeholder screens.
3. Drag in `store/figma/screens/*-1080x1920.png` — they are already 1080×1920,
   so they drop in without rescaling.
4. Keep the headline copy from `store/assets/screenshots-1080x1920/` (it is
   written and approved): burn, add-in-ten-seconds, share-the-receipt,
   cancel-links-that-work, renewals-before-charge, local-first.
5. Export at 1× as **PNG or JPG with no transparency** — both stores reject a
   transparent background, and that is the failure people hit most.

---

## What we produced (no Figma required)

```
store/assets/screenshots-1080x1920/   final, upload-ready (6 × 1080×1920)
store/assets/screenshots/             plain UI captures at 2:1 (786×1572)
store/assets/icon-512.png             Play icon, 512², no alpha
store/assets/feature-graphic-1024x500.png
store/figma/screens/                  the same six screens at 1080×1920,
                                      without headlines — drop into any template
store/figma/icon-512.png, mark-256.png, feature-graphic-1024x500.png
```

### Copy used on the frames

| Frame | Headline | Shows |
|---|---|---|
| 1 | Your yearly burn, in one number. | Dashboard hero, ghost split |
| 2 | Add a subscription in ten seconds. | Quick Add with preset grid |
| 3 | Share the receipt. Make the burn visible. | Receipt studio, 9:16 card |
| 4 | Cancel links that actually work. | Detail + cancel dock |
| 5 | Know what renews before it charges. | Renewals timeline |
| 6 | Local-first. Nothing uploaded. | Controls, storage + privacy |

### Rules these already satisfy

- 2–8 phone screenshots (we ship 6)
- min 320 px, max aspect **2:1** (ours are exactly 1080×1920)
- no transparency, no device-frame watermark, no misleading UI
- text legible at thumbnail size (72 px headlines)
- no "Download now"/"Install" call-to-action in the image (Play policy)
- no competitor names or store badges
