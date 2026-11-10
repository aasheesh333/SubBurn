# SubBurn — Architecture

**Principal-engineer summary.** The product is a local-first tracker with one
viral artefact. The architecture exists to keep three promises: the numbers
never disagree, the app works without a network, and the running cost stays at
zero as users grow.

---

## 1. Invariants

These are the rules the code is organised around. Each one is enforced by a
test or by a single-point-of-truth type.

| # | Invariant | Enforced by |
|---|---|---|
| 1 | Every number on every screen comes from one `BurnSummary` | `burnSummaryProvider`; no screen computes its own total |
| 2 | The ghost percentage and the ghost rupees are the same division | `BurnSummary.ghostShare`, test `ghost share × monthly == ghostMonthly` |
| 3 | A subscription is stored exactly as the vendor bills it | `Subscription.amount` + `cycle`; normalised only on read |
| 4 | The receipt is one 360 × 640 node with no outward paint | `RepaintBoundary` test asserting no child escapes, `1080 × 1920` PNG test |
| 5 | The roast is a pure function of the ledger | `RoastEngine` has no RNG, no clock, no network |
| 6 | No user data leaves the device | No Firestore client, no auth, no upload call anywhere in `lib/` |
| 7 | Every network dependency has an offline path | CDN → cache → asset; Firebase → no-op; push → skipped |
| 8 | The app opens with the radio off | `main()` never awaits a network call before `runApp` |

---

## 2. Layer map

```
┌─────────────────────────────────────────────────────────────┐
│ features/            screens + screen-local widgets          │
│   dashboard · quick_add · studio · detail · renewals · shell │
└───────────────▲─────────────────────────────────────────────┘
                │ watch providers
┌───────────────┴─────────────────────────────────────────────┐
│ state/providers.dart      the only state graph               │
│   subscriptions · settings · catalogue · burnSummary · rates │
└───────────────▲─────────────────────────────────────────────┘
                │ read
┌───────────────┴─────────────────────────────────────────────┐
│ domain/          pure functions, no I/O, fully unit tested   │
│   BurnSummary · RoastEngine · formatters                     │
└───────────────▲─────────────────────────────────────────────┘
                │ models
┌───────────────┴─────────────────────────────────────────────┐
│ data/            models · Hive adapters · repositories       │
└───────────────▲─────────────────────────────────────────────┘
                │
┌───────────────┴─────────────────────────────────────────────┐
│ services/        plugins: notifications, share, analytics,   │
│                  OneSignal, Firebase bootstrap, catalogue CDN│
└─────────────────────────────────────────────────────────────┘
```

Rules:

- `domain/` imports nothing from Flutter except `dart:ui` colour types. It is
  pure Dart and runs in a plain `test()` with no binding.
- `features/` never touches Hive, HTTP, or a plugin directly. Action → notifier
  → repository/service.
- `services/` wrap every plugin call so a plugin failure is a log line, not a
  crash.

---

## 3. The money pipeline

The single most important path in the product. It runs once per frame, in one
pure function.

```
Subscription                 Display currency + FX
  amount         ──┐
  currency       ──┼──► toInr() ──► × cycle.monthlyFactor ──► monthlyInr
  cycle          ──┘                                    │
                                                        ▼
                        BurnSummary.from(subs, currency, inrPerUsd)
                                                        │
        ┌───────────────────────┬───────────────────────┼───────────────┐
        ▼                       ▼                       ▼               ▼
   monthly (hero)        ghostMonthly            ghostShare         dueSoon (48 h)
                        (callout, receipt)     (bar, legend,      (renewal rail)
                                                receipt copy)
```

### Normalisation

| Cycle | Monthly equivalent | Rationale |
|---|---|---|
| monthly | `amount` | identity |
| yearly | `amount / 12` | `amount` is the real annual charge, so a discounted annual plan is already cheaper |
| weekly | `amount × 52 / 12` | 4.33 weeks in a month, exactly |

### Why yearly discount lives in the stored amount

Quick Add advertises **−17 %** for yearly billing. Rather than storing a
monthly price plus a discount flag, the app stores what the card is actually
charged and divides by 12. That makes the receipt honest by construction:

```
₹1,660/mo × 12          = ₹19,920   (monthly plan)
₹19,920 × 0.83 / 12     = ₹1,378/mo (yearly plan, same tool)
```

`ReceiptLine.billedYearly` prints `₹1,660 × 12 −17%` so the reader can see the
arithmetic instead of trusting it.

### Display currency

INR is the base unit. USD amounts convert at the rate from `rates.json`
(default 83, and a higher-than-market fallback is deliberate: under-reporting
burn is the one error this product must never make).

---

## 4. Persistence

```
Box<Subscription>  'subscriptions_v1'   one row per subscription
Box<AppSettings>   'settings_v1'        one row: currency, reminder opt-in, installId
```

Adapters are **hand-written** (`local_adapters.dart`), not generated:

- the on-disk field order is reviewed code, not an artefact of field
  declaration order;
- new fields append at the end with a default on read, so an app update can
  never corrupt a box;
- no build_runner step in CI.

**The store is empty on install and nothing is ever written to it by the app
itself.** No demo rows, no sample ledger, no "try a receipt" shortcut that
fakes data. Every number the product displays is a number the user entered,
which is the only defensible position for a finance app: invented data is
indistinguishable from a bug.

Consequences that are deliberate:

- the hero hides its split bar until there is more than one tool, because
  "100 % active" over an empty ledger is a claim, not a measurement;
- `BurnSummary` of an empty list is all zeros and never `NaN`;
- the receipt renders an explicit empty state instead of a placeholder card;
- the renewals screen shows "0 this month" rather than an example row.

Sample ledgers exist only in `test/`, where they cannot reach a user.

---

## 5. Remote content

```
open.er-api.com/v6/latest/USD      live USD→INR (cached 24 h in prefs)
Cloudflare R2  subburn-cdn
├── presets_v1.json   124 tools: name, vendor, monogram, brandColor,
│                     category, defaultPrice, currency, cycle, cancelUrl
└── rates.json        { inrPerUsd, asOf }   fallback when the live feed fails
bundled assets/json  offline copy of both
```

Preset `defaultPrice` values are **suggestions**, not facts: Quick Add labels
them as such and the user edits the field to match their invoice. Nothing in the
app invents a price at runtime.

The exchange rate is fetched live (24-hour cache) so a user is never converted
against a rate frozen at build time. `ExchangeRates.fromErApi` rejects
implausible values (outside 30–300 INR/USD) and falls back rather than showing a
nonsense total.

`CatalogueService.load()`:

1. cache younger than **7 days** → return it;
2. else `GET` with an 8 s timeout → validate (`tools.isNotEmpty`) → persist;
3. else cached copy, even if stale;
4. else the **bundled** asset.

It cannot throw. `SocketException`, `ClientException` and `FormatException` are
all caught and fall through. The Controls screen prints which of the four
sources is live, so a stale cache is visible rather than silent.

`tools/gen_presets.py` generates the JSON *and* is the same file pushed to R2, so
the bundled fallback and the CDN copy cannot drift.

---

## 6. Notifications

Two alarms per subscription: **T−48 h** and **T−24 h**.

```
AndroidScheduleMode.inexactAllowWhileIdle
```

Deliberate: inexact alarms need no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`,
which keeps the Play listing free of the alarms-and-reminders special-access
declaration. A renewal reminder does not need second-level precision, and the
trade is documented in the manifest comment so nobody "fixes" it later.

Notification ids are a stable FNV-1a hash of the subscription id, so cancelling
works after a restart and ids never collide with the 32-bit Android space.

Scheduling is idempotent: the notifier cancels both ids, then schedules both
again. Deleting a subscription cancels both.

---

## 7. Export pipeline

```
GlobalKey ──► RepaintBoundary (360 × 640)
                    │
                    ▼  toImage(pixelRatio: 3)
              1080 × 1920 ui.Image
                    │
                    ▼  toByteData(png)
              Uint8List ──► temp dir ──► share_plus
```

Constraints that make this safe:

- the boundary wraps **only** the card — chrome, stage glow and dashed guide are
  siblings, outside it;
- every glow in the card is a child clipped by `ClipRRect`, so nothing paints
  outside the bounds;
- the card reads no `Theme` or `MediaQuery`, so it renders identically inside an
  `FittedBox` preview and in the export;
- the content column is inside `FittedBox(scaleDown)`, so a long roast scales by
  a fraction instead of overflowing the box.

---

## 8. Firebase bootstrap

```
Firebase.initializeApp()
├── Crashlytics        FlutterError.onError + PlatformDispatcher.onError
├── Analytics          2 product events, bucketed parameters only
├── Messaging          subscribeToTopic('subburn_global') + background handler
└── Remote Config      12 h minimum fetch, every key has an in-app default
```

Wrapped in `try/catch`. If any of it fails — no network on first run, missing
config in a fork, an emulator without Play Services — the app returns
`FirebaseRuntime.offline()`: analytics becomes a no-op object, Remote Config
becomes `null`, CDN falls back to the hard-coded URL. `runApp` still happens.

`main()` is inside `runZonedGuarded`, so an error thrown before the first frame
is reported rather than swallowed.

---

## 8b. Theming

`SbPalette` (a `ThemeExtension`) holds every semantic colour for one
brightness; `AppTheme.light` and `AppTheme.dark` are built by one function, so a
token cannot exist in one theme and be missing from the other.

- Widgets read `context.sb.text`, never `SbColors.text`. `SbColors` survives
  only for gradients, shadows and tests.
- Custom painters have no context, so the resolved colour is passed in.
- The default is `ThemePreference.system`: a new install follows the phone.
- Contrast is enforced by `test/theme_contrast_test.dart`, which measures every
  text/surface pairing in both palettes at 4.5:1 (3:1 for large text and UI
  glyphs). It caught amber-on-white at 2.15:1 during the light-theme port.
- The receipt always uses the dark palette: it is a dark artefact exported as a
  PNG, so it must look identical whatever the app theme is.

## 8c. Release-only failure modes

These cannot be caught by `flutter run` or widget tests, so each has a deliberate
guard:

| Failure | Guard |
|---|---|
| Resource shrinker deletes `ic_stat_subburn` (referenced only by a Dart string) → notification init throws → reminders dead in release only | `res/raw/keep.xml` with `tools:keep`; verified by reading `resources.arsc` out of the built APK |
| R8 strips Play Core split-install classes referenced by the Flutter engine | `-dontwarn com.google.android.play.core.**` in `proguard-rules.pro` |
| Keystore path resolved against `android/app/` instead of `android/` | `rootProject.file(...)` in the signing config |
| Obfuscated stack traces | Crashlytics Gradle plugin uploads the R8 mapping |
| Three services prompting for notification permission at boot | only `NotificationService` asks, in context |

**Rule:** any behaviour that depends on packaging (resources, R8, signing,
manifest) must be verified against the *release artifact*, not the debug build.

## 9. Why the cost stays at zero

| Scaling pressure | Why it does not apply |
|---|---|
| Database reads/writes | There is no server database. Hive is on the device. |
| Image/asset hosting | Receipts are generated on-device and shared through the OS sheet. |
| API calls per user | The only calls are two static JSON files, cached 7 days, and Firebase config. |
| Analytics volume | Two events, no per-user dimensions. Spark is unlimited for these. |
| Push fan-out | OneSignal free tier, broadcast only — no per-device segmentation. |
| Receipt generation | Pure Dart arithmetic. No AI API, no server render. |

At 10 M installs the CDN bill is the only variable, and both objects are
~40 KB, immutable per version, and served through a CDN edge with free egress on
R2's free tier.

---

## 10. Failure modes and their behaviour

| Failure | User sees |
|---|---|
| No network on first launch | Bundled catalogue, INR at 83, app fully usable |
| CDN 404 / bad JSON | Cached copy, then bundled; "Offline catalogue" strip in the shell |
| Notification permission denied | Reminder toggles stay on but do nothing; no crash |
| Firebase unavailable | Everything works; analytics silently no-ops |
| OneSignal not configured | Init skipped with a debug log |
| Cancel URL empty | Button reads "Cancel in vendor settings" and explains why |
| Export fails | Snackbar with the error; the card is untouched |
| Subscription deleted | Snackbar with UNDO, restoring both the row and its alarms |

---

## 11. Testing strategy

- **Domain** — pure `test()`, no widget binding: formatting, cycles, FX,
  lifetimes, summary identity, roast determinism and band escalation.
- **Persistence** — a real Hive box in a temp directory: full field round-trip,
  delete, settings.
- **Content** — the shipped `presets_v1.json` is parsed and validated: ≥ 100
  tools, unique ids, every cancel URL `https`.
- **Widgets** — receipt fits its box and no child escapes; real `toImage`
  returns `1080 × 1920`; pills expose selection; hero prints both percentages;
  tap targets ≥ 44 px.
- **Golden screens** — every screen rendered at 393 × 852 @2x, committed, so a
  visual regression fails CI instead of shipping.

Run: `flutter test` (32 tests). Refresh goldens:
`flutter test test/screens_preview_test.dart --update-goldens`.
