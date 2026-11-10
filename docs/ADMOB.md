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
| Banner (adaptive) | **Yes, one** | Predictable revenue, zero policy risk when it sits below content. Placed at the bottom of the dashboard, under the ghost callout, above the tab bar. |
| Rewarded | **Yes, opt-in** | The only format where the interruption is the user's own choice, so it cannot cost retention. The reward is two extra receipt themes — cosmetic, permanent, and nothing else is gated. |
| Interstitial | **No** | Must not fire at app open, mid-task, or between a tap and its result. In an app opened for seconds it destroys the experience and the highest-risk format for policy action. |
| App open | **No** | Google requires it not to obscure the first screen's content, and it reads as a toll booth on a utility app. |
| Native advanced | **No** | Needs bespoke layout work to look native; not worth the complexity at this stage. |

---

## Policy rules the implementation enforces

1. **No ad on a functional surface.** The banner appears only on the dashboard's
   scroll tail. Never on the subscription detail screen, in Quick Add, in the
   edit sheet, on the legal pages, or anywhere inside the receipt.
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
10. **The privacy policy names AdMob**, the two formats, the data involved, and
    the opt-out path. Play's Data Safety form must be updated to match (below).

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
