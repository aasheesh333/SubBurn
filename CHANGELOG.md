# Changelog

## 1.0.0 — 2026-11-09

First shipped version of the Flutter app, alongside the design package.

### Product

- Burn dashboard with monthly hero, active-vs-ghost split bar, 48-hour renewal
  rail and swipe-to-delete ledger.
- Quick Add with instant offline search over 124 presets, one-tap fill, billing
  cycle, currency conversion and usage guilt.
- Card studio: a 9:16 receipt exported at exactly 1080 × 1920, with a
  deterministic offline roast engine (5 tiers, 30 templates).
- Subscription detail with renewal countdown, lifetime spend, ghost toggle,
  reminder control and a direct vendor cancellation link.
- Renewals agenda and a controls screen.
- Ships with an empty ledger by design: no demo or sample subscriptions.

### Fixed from the design review

- Yearly `−17 %` now has a backing pricing rule instead of being chrome:
  yearly-billed tools are stored at their real annual charge and divided by 12.
- Ghost share is 25.7 % everywhere (1,245 / 4,850 = 25.67 %). The v1 receipt
  printed a rounded 26 % next to a rupee figure that did not match it.
- `Cancel subscription URL` → `Cancel with [OI]`, taken from the vendor.
- Terminology unified on "ghost" across hero, rows, callout, quick add, receipt
  and Figma frames.

### Platform

- `flutter_riverpod` state, `hive_ce` local store with hand-written adapters.
- Cloudflare R2 static catalogue with a 7-day cache and bundled fallback.
- Firebase Spark: Analytics (2 events), Crashlytics, Messaging, Remote Config
  at a 12-hour minimum fetch.
- OneSignal wired behind Remote Config for broadcast push.
- Inexact local reminders at T−48 h and T−24 h; no exact-alarm permission.
- Android 16 KB page-size packaging, dark launch theme, R8 with keep rules.
