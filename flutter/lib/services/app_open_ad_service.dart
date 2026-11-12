import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../state/providers.dart';
import 'ads_bootstrap.dart';
import 'ads_service.dart';

/// App-open ads: the only full-screen format Google designs for the moment a
/// user *opens* an app, and the only compliant way to monetise session starts
/// (a timer-driven interstitial or "rewarded every 3 minutes" would be policy
/// abuse and the fastest route to an account ban).
///
/// The gates below are the entire user-experience contract:
/// * **Never on the first launch after install** — Google's guidance, and a
///   new user has not received any value yet.
/// * **At most once per 2 hours**, cold starts and resumes combined.
/// * **Only after a real absence** on resume (≥1 min in background), so task
///   switchers never trigger it.
/// * **Never stacked** with another app-open show in progress.
/// * **Load budgets** — if the ad is not ready within a few seconds the
///   opportunity is dropped instead of popping over a screen the user is
///   already using.
/// * Debug builds use Google's test unit, like every other format.
class AppOpenAdService {
  AppOpenAdService(this._ref);

  static const frequencyCap = Duration(hours: 2);
  static const minBackground = Duration(minutes: 1);
  static const coldStartBudget = Duration(seconds: 4);
  static const resumeBudget = Duration(seconds: 3);

  final Ref _ref;
  bool _showing = false;
  DateTime? _backgroundedAt;
  static bool _coldStartAttempted = false;

  /// Pure so the caps are unit-testable without the SDK.
  static bool allowed({
    required DateTime now,
    required int lastShownAt,
    required int launchCount,
  }) {
    if (launchCount < 2) return false; // first launch after install
    if (lastShownAt <= 0) return true;
    return now.millisecondsSinceEpoch - lastShownAt >=
        frequencyCap.inMilliseconds;
  }

  String? _unitId() {
    if (kDebugMode) return AdUnits.appOpen;
    final ads = _ref.read(adsServiceProvider);
    return ads.canShowAppOpen ? ads.appOpenUnitId : null;
  }

  void noteBackgrounded() => _backgroundedAt = DateTime.now();

  /// Called once per process, after the shell's first frame.
  Future<void> maybeShowOnColdStart() async {
    if (_coldStartAttempted) return;
    _coldStartAttempted = true;
    await _maybeShow(coldStartBudget);
  }

  /// Called when the app returns to the foreground.
  Future<void> maybeShowOnResume() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (DateTime.now().difference(since) < minBackground) return;
    await _maybeShow(resumeBudget);
  }

  Future<void> _maybeShow(Duration budget) async {
    if (_showing) return;
    final settings = _ref.read(settingsProvider);
    if (!allowed(
      now: DateTime.now(),
      lastShownAt: settings.appOpenLastShownAt,
      launchCount: settings.launchCount,
    )) {
      return;
    }
    final unitId = _unitId();
    if (unitId == null) return;
    if (!AdsBootstrap.isInitialised) await AdsBootstrap.initialise();
    if (!AdsBootstrap.isInitialised) return;

    final completer = Completer<AppOpenAd?>();
    try {
      await AppOpenAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('app-open failed: ${error.message}');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (error) {
      debugPrint('app-open load threw: $error');
      if (!completer.isCompleted) completer.complete(null);
    }
    final ad = await completer.future.timeout(budget, onTimeout: () => null);
    if (ad == null) return; // dropped, not delayed: never pop in late

    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('app-open show failed: ${error.message}');
        ad.dispose();
        _showing = false;
      },
    );
    // The cap counts from the show, not the dismiss: two resumes inside the
    // cap window must not each queue another ad.
    await _ref.read(settingsProvider.notifier).recordAppOpenShown();
    await ad.show();
  }

  void dispose() {
    _backgroundedAt = null;
  }
}

final appOpenAdServiceProvider = Provider<AppOpenAdService>((ref) {
  final service = AppOpenAdService(ref);
  ref.onDispose(service.dispose);
  return service;
});
