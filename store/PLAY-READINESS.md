# Play submission readiness — verified against the Nov 2026 requirements

Checked 2026-11-13 against the current Google Play / Android Developers pages.
Every "✅" below was confirmed from the **built artifact**, not from intent.

## Submission gate (hard requirements)

| Requirement | Rule (as of 31 Aug 2026) | Ours | Evidence |
|---|---|---|---|
| Target API level | New apps + updates must target **API 36+** | **36** | `targetSdk = flutter.targetSdkVersion`; Flutter 3.47.4 pins 36. Decoded from the AAB manifest: `targetSdkVersion` present, `compileSdkVersion 37` |
| Bundle format | New apps must ship an **AAB** | ✅ AAB 68.0 MB | `SubBurn-<sha>.aab` artifact, signed |
| Signing | Upload key + Play App Signing | ✅ v1/v2/v3 | `keytool -printcert` on both APK and AAB: same cert, SHA256 `96:D7:6A:02…3F:77:55` |
| 16 KB page size | Required for new apps/updates targeting Android 15+ | ✅ | `readelf -lW` on all `arm64-v8a` `.so`: every `LOAD` segment aligned `0x4000` or `0x10000` |
| Package name | Immutable after publish | `com.dhanuk.subburn` | Manifest + AAB |
| Version code | Must increase per upload | `versionCode` = CI run number | `docs/PLAY-STORE.md`; `versionName 1.0.0` |

## Policy / declarations

| Requirement | Ours | Where |
|---|---|---|
| Ads declaration ("app contains ads") | **Yes** — banner, capped app-open (2 h), opt-in rewarded | `docs/ADMOB.md`, `docs/PLAY-STORE.md` |
| Data safety form | Declared: advertising ID shared with AdMob; analytics buckets; no names/prices/vendors; data not sold | `docs/PLAY-STORE.md` §3 |
| Privacy policy, publicly reachable over HTTPS | ✅ | `https://dhanuk.page.gd/SubBurn/privacy.html` (InfinityFree) + R2 mirror, HTTP 200 verified |
| Account deletion requirement | **N/A** — no accounts, everything local | privacy policy |
| Permissions justified | `INTERNET` (catalogue/FX), `POST_NOTIFICATIONS` (reminders), `VIBRATE`, `RECEIVE_BOOT_COMPLETED` (re-arm after reboot) | manifest — no location, contacts, storage, exact-alarm |
| Exact alarm permission | **Not requested** (`inexactAllowWhileIdle`) — avoids the restricted-permission declaration | manifest + `notification_service.dart` |
| Backup disabled | `allowBackup=false`, `fullBackupContent=false`, `dataExtractionRules` | manifest |
| Cleartext traffic | `usesCleartextTraffic=false` | manifest |
| R8/resource shrinking | Enabled; notification small icon kept via `keep.xml` | `build.gradle.kts`, verified in `resources.arsc` |
| Content rating | Utility/Productivity questionnaire, no restricted content | `docs/PLAY-STORE.md` §4 |
| Financial features | Subscription *tracker*, not a financial product: no lending, no payments, no advice | full description |

## Store listing assets

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512 × 512, 32-bit PNG, no alpha | ✅ `store/assets/icon-512.png` (512×512 RGB) |
| Feature graphic | 1024 × 500 | ✅ `store/assets/feature-graphic-1024x500.png` |
| Phone screenshots | 2–8, min 320 px, **max aspect 2:1** | ✅ `store/assets/screenshots/` — six frames at 786×1572 (exactly 2:1). The raw goldens are 786×1704 (2.17:1) and would have been **rejected**; they are padded, not cropped, so no UI is lost |
| Short description | ≤ 80 chars | ✅ 71 chars (`docs/PLAY-STORE.md`) |
| Full description | ≤ 4000 chars | ✅ |
| Category / contact | Finance, `support@dhanuksoftwares.com` | ✅ |
| Tablet screenshots | Optional (app is phone-first) | — |
| Promo video | Optional | — |

## Before you press publish (things only you can do)

1. **Play Console → App content**: complete Data safety, Ads, Content rating, Target audience, News app (no), COVID (no).
2. **Payments/tax profile** in Play Console (required even for a free app before the account can publish).
3. **Upload the AAB** from the latest Build run, then link the store listing in AdMob (App → App settings → Add store) so ad serving leaves "limited" review.
4. **`app-ads.txt`** at the site root: `google.com, pub-4285271252655677, DIRECT, f08c47fec0942fa0` — AdMob withholds some demand without it.
5. **Real-device pass on the signed artifact** (the one item no CI can cover): install the universal APK, add a subscription, check reminders on a reboot, share a receipt, confirm the banner sits above the nav bar on all four tabs.
6. **Accessibility pass**: TalkBack + 200 % text on the dashboard, quick add and detail.

## Known trade-offs (accepted, documented)

- **Inexact reminders** may fire up to ~15 min late under Doze. Exact alarms would need the restricted `USE_EXACT_ALARM` permission, which Play audits.
- **OEM battery managers** can drop alarms; the app re-arms on every launch/resume but cannot exempt itself.
- **Universal APK is 64 MB**; Play's generated splits are ~20–25 MB per device. The APK is for sideloading/testing, the AAB is what ships.
- **No iOS build** — Android-only launch is allowed.
