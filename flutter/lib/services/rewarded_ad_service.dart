import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_bootstrap.dart';
import 'ads_service.dart';

/// Loads and shows one rewarded ad on demand.
///
/// Rewarded is the only format where the user chooses to watch, so it is the
/// only format that can carry real revenue without costing retention — and the
/// only one that is safe under AdMob's policy for interrupting a flow, because
/// the interruption is the user's own tap.
///
/// The reward here is a real product feature: an extra receipt theme. Nothing is
/// gated that the user could previously reach, and no feature is taken away.
class RewardedAdService {
  RewardedAdService(this._ref);

  /// The SDK's own load callback can lag the platform call by seconds, so
  /// `load()` completes only when the callback fires. Without this the first
  /// unlock tap always loses the race and reports "no ad available".
  static const _loadTimeout = Duration(seconds: 15);

  final Ref _ref;
  RewardedAd? _ad;
  Future<void>? _inFlight;

  bool get isReady => _ad != null;

  /// The unit actually requested: Google's test id in debug (never a live unit —
  /// invalid traffic is the fastest route to a ban), the configured live unit
  /// in release.
  String? _effectiveUnitId() {
    if (kDebugMode) return AdUnits.rewarded;
    final ads = _ref.read(adsServiceProvider);
    if (!ads.canShowRewarded) return null;
    return ads.rewardedUnitId;
  }

  Future<void> load() {
    if (_ad != null) return Future<void>.value();
    return _inFlight ??= _loadOnce().whenComplete(() => _inFlight = null);
  }

  Future<void> _loadOnce() async {
    final unitId = _effectiveUnitId();
    if (unitId == null) return;
    if (!AdsBootstrap.isInitialised) await AdsBootstrap.initialise();
    if (!AdsBootstrap.isInitialised) return;

    final completer = Completer<void>();
    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            if (!completer.isCompleted) completer.complete();
          },
          onAdFailedToLoad: (error) {
            debugPrint('rewarded failed: ${error.message}');
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );
    } catch (error) {
      debugPrint('rewarded load threw: $error');
      if (!completer.isCompleted) completer.complete();
    }
    // Safety net: a platform that drops callbacks must not hang the UI.
    await completer.future.timeout(_loadTimeout, onTimeout: () {});
  }

  /// Shows the ad. [onReward] runs only after the SDK confirms the reward was
  /// earned, so a user who closes early does not get the theme and does not feel
  /// cheated either way.
  Future<bool> show({required VoidCallback onReward}) async {
    if (_ad == null) {
      await load();
      if (_ad == null) return false;
    }
    final showing = _ad!;
    var rewarded = false;
    showing.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        unawaited(load()); // warm the next one without blocking
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('rewarded show failed: ${error.message}');
        ad.dispose();
        _ad = null;
      },
    );
    await showing.show(
      onUserEarnedReward: (_, reward) {
        rewarded = true;
        onReward();
      },
    );
    return rewarded;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(ref);
  ref.onDispose(service.dispose);
  return service;
});
