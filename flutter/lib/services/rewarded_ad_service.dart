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

  final Ref _ref;
  RewardedAd? _ad;
  bool _loading = false;

  bool get isReady => _ad != null;

  Future<void> load() async {
    if (_ad != null || _loading) return;
    final ads = _ref.read(adsServiceProvider);
    final unitId = ads.rewardedUnitId;
    if (unitId == null || unitId.isEmpty) return;
    if (!AdsBootstrap.isInitialised) await AdsBootstrap.initialise();
    if (!AdsBootstrap.isInitialised) return;

    _loading = true;
    await RewardedAd.load(
      adUnitId: kDebugMode ? AdUnits.rewarded : unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('rewarded failed: ${error.message}');
          _loading = false;
        },
      ),
    );
  }

  /// Shows the ad. [onReward] runs only after the SDK confirms the reward was
  /// earned, so a user who closes early does not get the theme and does not feel
  /// cheated either way.
  Future<bool> show({required VoidCallback onReward}) async {
    final ad = _ad;
    if (ad == null) {
      await load();
      if (_ad == null) return false;
    }
    final showing = _ad!;
    var rewarded = false;
    showing.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        load(); // warm the next one without blocking
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
