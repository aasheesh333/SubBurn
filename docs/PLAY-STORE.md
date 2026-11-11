# Play Store submission — SubBurn

Everything Play Console asks for, with the exact answers for this app.
Package: `com.dhanuk.subburn` · Version: `1.0.0 (1)`.

> The application id changed from `com.subburn.subburn` before first release.
> The Firebase Android app for the new id is registered
> (`1:363613857398:android:dd83bd3f6cb6b7e9276157`) and
> `android/app/google-services.json` contains both ids, so an old test build
> still resolves its config. The upload key is unchanged.

---

## 1. Build the signed App Bundle

**Easiest:** push a commit. CI builds both the AAB and an installable APK and
publishes them under the run's **Artifacts** section
(`.github/workflows/build.yml`). Download `SubBurn-aab-<sha>.aab` and upload it
to Play. `versionCode` is the GitHub run number, so it increases on every build.

Locally:

```bash
cd flutter
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Signing is read from `android/key.properties` (never committed):
`storeFile=keystore/subburn-release.jks`, alias `mykey`.
If that file is missing the build falls back to the debug key and cannot be
uploaded — the Gradle log prints a warning.

CI builds both on every push (`.github/workflows/build.yml`), verified
2026-11-09: APK 264 s, AAB 306 s, both signed with the certificate below.
`versionCode` = GitHub run number, so it is monotonic across uploads.

Keystore certificate SHA-256:

```
96:D7:6A:02:DC:7D:A1:79:07:06:BD:32:48:68:27:38:63:C8:BF:01:D3:D3:FB:F7:20:48:48:3C:13:3F:77:55
```

**Back up the `.jks` and its password.** Losing it means losing the ability to
update the app (unless Play App Signing is enabled and you use an upload key).

---

## 2. Store listing

| Field | Value |
|---|---|
| App name | `SubBurn — Subscription Burn` |
| Short description (80) | `Track AI & SaaS subscriptions, see your yearly burn, share the receipt.` |
| Category | Finance |
| Tags | Subscriptions, Budgeting, Productivity |
| Contact email | `support@dhanuksoftwares.com` |
| Website | `https://dhanuk.page.gd/SubBurn/` |
| Privacy policy | `https://dhanuk.page.gd/SubBurn/privacy.html` |
| Privacy mirror | `https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev/privacy.html` |

### Full description

```
SubBurn is a guilt tracker for the subscriptions you forgot you were paying for.

Add ChatGPT, Claude, Cursor, Netflix, Spotify or any of 124 built-in tools, and
SubBurn answers one question in under a second: how much am I burning, and how
much of it do I actually use?

• Monthly burn in ₹ or $, with yearly and weekly plans normalised
• Active-use vs ghost-spend split, so waste is visible before you read a single row
• Renewal warnings 48 hours and 24 hours before every charge
• Lifetime spend per subscription, prorated from your real billing dates
• A direct link to each vendor's own cancellation page
• A 9:16 year-end receipt with a deterministic roast, exported at 1080 × 1920

Local-first by design: your subscriptions are stored on your phone. There is no
account, no cloud database, and the app never uploads your ledger. One banner
above the navigation bar and an optional rewarded video are the only ads, and
nothing is gated behind them. No tracking beyond anonymous crash reports and a
few bucketed product events.

Light and dark, following the device. Made for people with too many tabs.
```

### Graphics checklist

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit, no alpha | **to produce** |
| Feature graphic | 1024 × 500 PNG/JPEG | **to produce** |
| Phone screenshots | ≥ 2, 16:9 or 9:16, 320–3840 px | ready: `flutter/test/goldens/*.png` |
| Tablet screenshots | optional | — |

Screenshots available: `01-dashboard`, `02-quick-add`, `03-studio`, `04-detail`,
`05-renewals`, `06-controls`, `08-first-run`.

---

## 3. Data safety form

Answer these exactly — they match `privacy.html` and the code.

**Does your app collect or share any of the required user data types?** Yes.

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| App activity → *Other actions* (`sub_added`, `roast_card_shared`) | Yes | No | Analytics | No |
| App info & performance → *Crash logs* | Yes | No | App functionality / diagnostics | No |
| App info & performance → *Other app performance data* | Yes | No | Analytics | No |
| Device or other IDs → *Device or other IDs* (install id, push token) | Yes | No | App functionality, Analytics | Yes (push can be declined) |
| Device or other IDs → *Device or other IDs* (Google advertising ID) | Yes | **Yes — shared with Google AdMob** | Advertising | Yes (consent form, and Controls → Ads → Manage) |

Everything else: **No** — no name, email, phone, contacts, location, photos,
files, health, financial info, messages, or browsing history.

- Is data encrypted in transit? **Yes.**
- Can users request deletion? **Yes** — uninstall, or *Controls → Delete all
  subscriptions*; email for server-side deletion.
- Is data sold? **No.** (Note: sharing an advertising ID with AdMob counts as
  "shared with third parties" in the Data Safety form, not as a sale.)
- Does the app contain ads? **Yes** — one dashboard banner plus an optional
  rewarded video. No interstitials, no app-open ads.
- Is data used for advertising? **No.**
- Is data used to track users across apps/sites? **No.**
- Committed to the Play Families policy? **N/A** (not targeted at children).

**Financial info note:** prices the user types are stored only on the device and
are never transmitted, so they are *not* "collected" in Play's sense. Do not
declare financial info as collected.

---

## 4. Content & declarations

| Question | Answer |
|---|---|
| Ads | No |
| In-app purchases | No |
| User-generated content / social features | **No** — the receipt is generated locally and shared through the OS share sheet |
| Health / medical claims | No |
| Government app | No |
| News app | No |
| Target audience | 18+ (Finance category, no child-directed features) |
| Content rating questionnaire | Utility / Productivity; no violence, sex, profanity, drugs, gambling |
| Encryption | Uses standard HTTPS only → declare "uses encryption" but exempt under the standard exception |
| Accessibility | Not claimed; screen-reader pass still pending |

---

## 5. Permissions justification (if asked)

| Permission | Why |
|---|---|
| `INTERNET` | Static preset catalogue + FX rate from CDN; Firebase config and analytics |
| `POST_NOTIFICATIONS` | Optional renewal reminders at 48 h / 24 h |
| `VIBRATE` | Reminder alerts |
| `RECEIVE_BOOT_COMPLETED` | Re-arm scheduled reminders after a reboot |

No `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`, no location, contacts, storage,
camera, microphone, or `QUERY_ALL_PACKAGES`.

---

## 6. Release flow

1. Internal testing track → install on 2 devices, check: add → reminder fires →
   receipt exports 1080 × 1920 → cancel link opens → delete removes the row.
2. Closed testing (12 testers, 14 days) if the account is new — Play requires
   this for personal developer accounts created after Nov 2023.
3. Production, staged rollout 5 % → 20 % → 50 % → 100 %.
4. Watch Crashlytics + Android vitals for 48 h at each step.

---

## 7. Known gaps before production

- [ ] App icon + feature graphic (512² and 1024×500)
- [ ] iOS build (`GoogleService-Info.plist`, APNs key) — Android-only launch is fine
- [ ] Screen-reader + 200 % text pass on a physical device
- [x] `flutter build appbundle` verified by CI (signed AAB artifact)
- [x] No demo/seed data; every ledger row is user-entered
- [x] Live FX rate with a 24-hour cache
- [ ] Real device pass on the signed artifact
- [x] Release keystore wired and verified (`keytool -list` passes)
- [x] Crashlytics mapping upload configured
- [x] Backups disabled (`allowBackup=false`, data extraction rules)
- [x] Privacy policy hosted over HTTPS
- [x] OneSignal app id configured