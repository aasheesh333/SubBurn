import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob placement rules for SubBurn.
///
/// The formats are chosen for revenue *and* for not wrecking a two-second
/// utility app:
///
/// * **Banner** — one, at the very bottom of the dashboard, below all content
///   and above the tab bar. Never over a button, never on the detail screen,
///   never inside the receipt.
/// * **Rewarded** — opt-in only. The user taps "Unlock a premium receipt
///   theme"; the reward is the theme. Nothing is ever gated behind an ad that
///   the user did not ask for.
///
/// Deliberately **not** used:
/// * Interstitial — highest policy risk (must not fire at app open, during a
///   task, or between a tap and its result) and the worst retention cost in an
///   app opened for seconds.
/// * App-open — same problem, and Google requires it not to cover the first
///   screen's content.
/// * Ads on the share/export flow — the receipt is the product.
abstract final class AdUnits {
  /// Live unit ids from the AdMob console (public identifiers, not secrets).
  static const bannerAndroid = 'ca-app-pub-4285271252655677/4419017228';
  static const rewardedAndroid = 'ca-app-pub-4285271252655677/5895575414';

  /// Google's official test ids. Always used in debug so a real developer
  /// never clicks a live ad — invalid traffic is the fastest way to a ban.
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get banner => kDebugMode ? _testBanner : bannerAndroid;
  static String get rewarded => kDebugMode ? _testRewarded : rewardedAndroid;
}

/// Initialises the Mobile Ads SDK once, with UMP consent where required.
class AdsBootstrap {
  static bool _initialised = false;
  static bool get isInitialised => _initialised;

  /// Set by tests and previews so no test ever depends on the SDK.
  static bool disabled = false;

  static Future<void> initialise() async {
    if (_initialised || disabled) return;
    try {
      // Request consent first: in the EEA/UK the SDK must not gather ad
      // identifiers before the user answers. `gatherConsent` shows Google's own
      // message when one is required and returns immediately otherwise.
      await _gatherConsent();
      final status = await MobileAds.instance.initialize();
      debugPrint('AdMob initialised: ${status.adapterStatuses.keys.join(', ')}');
      _initialised = true;
    } catch (error) {
      // Ads are optional revenue; a failure here must never affect the app.
      debugPrint('AdMob init skipped: $error');
    }
  }

  static Future<void> _gatherConsent() async {
    final params = ConsentRequestParameters();
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('Consent form error: ${formError.message}');
            }
          });
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        debugPrint('Consent info error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    // Never block the first frame on a network round-trip.
    await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => debugPrint('Consent timed out; continuing without it'),
    );
  }

  /// Opens the privacy options entry point. Google requires this to be
  /// reachable from the app whenever a consent form applies.
  static Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('Privacy options error: ${formError.message}');
        }
      });
    } catch (error) {
      debugPrint('Privacy options unavailable: $error');
    }
  }
}
