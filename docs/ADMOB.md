# AdMob — SubBurn

Ad serving is live in code. This file records the configuration, why each format
was chosen, and the policy rules the implementation follows.

---

## Account configuration

| Item | Value |
|---|---|
| AdMob app | **SubBurn** (`apps.admob.com` → 8713310448) |
| App ID | `ca-app-pub-4285271252655677~8713310448` |
| Banner unit | `ca-app-pub-4285271252655677/4419017228` — `SubBurn_Dashboard_Banner` |
| Rewarded unit | `ca-app-pub-4285271252655677/5895575414` — `SubBurn_UnlockTheme_Rewarded` |
| App-open unit | `ca-app-pub-4285271252655677/3390744697` — `SubBurn_AppOpen_Launch` |
| App store status | **Not yet listed** — marked "No" at creation, so AdMob is doing its review. Ad serving is limited until the app is published to Play and approved. |

The App ID lives in `android/app/src/main/AndroidManifest.xml`
(`com.google.android.gms.ads.APPLICATION_ID`). Unit IDs live in
`lib/services/ads_bootstrap.dart` and can be overridden from Remote Config
(`ads_enabled`, `admob_banner_unit`, `admob_rewarded_unit`) without a release.

**Debug builds always use Google's official test unit ids**, so a developer can
never click a live ad. Invalid traffic is the fastest route to an account ban.

---

## Formats: what is used and what is deliberately not

| Format | Used | Why |
|---|---|---|
| Banner (anchored adaptive) | **Yes, one** | Predictable revenue, zero policy risk when it sits below content. Mounted once at shell level, above the bottom navigation bar, so it is visible on all four tabs, loads once per session and is never reloaded by tab switches (the SDK's own refresh cycle handles timed reloads). Requests the **standard** anchored-adaptive size (~50 dp on phones) — the large ~100 dp variant took too much of the screen for a utility app, and the legacy fixed 320×50 letterboxes on wide phones. Pushed routes (subscription detail) and modal sheets (add/edit) cover the shell, so no ad is ever visible while editing or sharing. |
| Rewarded | **Yes, opt-in, two entry points** | The only format where the interruption is the user's own choice, so it cannot cost retention and carries the highest eCPM. Rewards: (1) two extra receipt themes — cosmetic, permanent; (2) a plain "support the developer" thank-you. Nothing is gated behind either. The banner is permanent by product decision: no perk, toggle or pause ever removes it, so the base revenue floor never disappears. |
| Interstitial | **No** | Must not fire at app open, mid-task, or between a tap and its result. A timed interstitial ("every 3 minutes") is policy abuse and the fastest route to an account ban; in an app opened for seconds it also destroys retention, which is the lever that compounds. |
| App open | **Yes, hard-capped** | The only full-screen format Google designs for the open/resume moment, and the compliant substitute for timed interstitials: it monetises session starts without interrupting any task. Gates enforced in `AppOpenAdService`: never on the first launch after install, at most once per 2 h (cold starts and resumes share the cap), resume shows only after ≥1 min in background, load budgets of 4 s (cold) / 3 s (resume) drop the opportunity instead of popping in late, and never stacked with another show. |
| Native advanced | **No** | Needs bespoke layout work to look native; not worth the complexity at this stage. |

Debug builds always request Google's official test unit ids — the swap happens
in `BannerAdSlot`/`RewardedAdService` *before* any config value is consulted, so
a debug build can never request a live unit even if Remote Config ships one.

---

## Policy rules the implementation enforces

1. **No ad on a functional surface.** The single banner lives at shell level,
   above the bottom navigation bar, on the four main tabs only. Pushed routes
   (subscription detail, legal pages) and modal sheets (Quick Add, edit) cover
   the shell, so no ad is ever visible while reading, editing or sharing.
2. **No ad near a call to action.** The banner sits below all content with a
   divider, so a mis-tap on "Add" or "Review" cannot land on it.
3. **No ad on the share/export flow.** The receipt is the product; an ad would
   also end up inside the exported PNG if it overlapped the boundary.
4. **No accidental clicks.** The banner only reserves height after a real ad
   loads, so there is no invisible tappable area.
5. **Consent first (UMP).** `AdsBootstrap` requests consent before
   `MobileAds.initialize()`. Where a form is required it is shown; where it is not
   it returns immediately.
6. **Privacy options are reachable in-app.** Controls → Ads → **MANAGE** calls
   `ConsentForm.showPrivacyOptionsForm`, which Google requires whenever a consent
   form applies.
7. **Declining costs nothing.** Every feature, including the free receipt theme,
   works without ads. Only the two cosmetic themes need a rewarded view.
8. **Ads never delay the UI.** `AdsBootstrap.initialise()` runs after the first
   frame, and the consent call has a 6 s timeout that fails open.
9. **No ad refresh loop.** A failed fill is logged and dropped; there is no retry
   storm.
10. **The privacy policy names AdMob**, every format, the data involved, and
    the opt-out path. Play's Data Safety form must be updated to match (below).
11. **App-open gates are code, not convention.** `AppOpenAdService.allowed()` is
    a pure function (unit-tested) implementing the first-launch skip and the
    2 h cap; the shell supplies the lifecycle moments. A future contributor
    cannot "just show it more often" without editing a tested gate.
12. **The banner never disappears.** No perk, consent state or config flag
    other than the master `ads_enabled` kill-switch removes the banner; the
    earlier 24 h pause perk was withdrawn so the revenue floor is permanent.
    UX pressure is handled by the banner's placement (below all content,
    ~50 dp) and by the opt-in rewarded perks instead.

---

## Remaining steps (account-side, cannot be done from code)

- [ ] **Publish on Play**, then link the store listing in AdMob (App → App
      settings → Add store). Review takes a few days; ad serving stays limited
      until it passes.
- [ ] **Payments**: add tax info and a payment method in AdMob → Payments
      (required before the $100 threshold can be paid out).
- [ ] **ads.txt**: AdMob generates `app-ads.txt` for the developer website.
      Upload it to the site root (`https://dhanuk.page.gd/app-ads.txt`) with the
      publisher id `pub-4285271252655677`. Without it, some demand is withheld.
- [ ] **Play Data Safety** must now declare: *Device or other IDs — collected,
      shared with third parties, for Advertising*. Also *App activity* if you
      keep Analytics.
- [ ] **Play Ads declaration**: mark the app as containing ads.

---

## Revenue expectations (set honestly)

SubBurn is a low-session-frequency utility: users open it weekly, not hourly.
Banner eCPM on Indian traffic for a finance-adjacent app is roughly $0.3–1.2 per
1000 impressions; rewarded is higher (often 3–10×) because the user opted in.
At 10,000 daily active users with two screens viewed per session, a single
banner is in the low tens of dollars a day, not thousands. Rewarded adds more per
engaged user but only if users actually want the themes.

The lever that matters is **retention**, not ad density. That is why no
interstitial was added: it would raise short-term eCPM and lower day-30 retention,
which is the thing that compounds.
