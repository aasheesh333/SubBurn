import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Ad readiness, not ads.
///
/// Play requires a data-safety declaration the moment an ad SDK is linked.
/// This service is the switch: it reads Remote Config and decides whether an
/// ad surface may render at all.
///
/// Remote Config keys (defaults live in `RemoteConfigService`):
///   * `ads_enabled` — master switch,
///   * `admob_banner_unit` — the dashboard banner,
///   * `admob_rewarded_unit` — the opt-in theme-unlock video.
///
/// Debug builds never use these ids: both slots swap in Google's official test
/// units so a developer cannot generate invalid traffic on a live unit.
class AdsService {
  const AdsService(
      {required this.enabled, this.bannerUnitId, this.rewardedUnitId});

  final bool enabled;
  final String? bannerUnitId;
  final String? rewardedUnitId;

  /// True only when the flag is on *and* a unit id exists. A half-configured
  /// ad surface renders nothing rather than an empty grey box.
  bool get canShowBanner => enabled && (bannerUnitId?.isNotEmpty ?? false);

  /// Rewarded is opt-in, so it only needs an id, not a separate flag: if the
  /// console clears this id, the unlock flow reports "no ad available" instead
  /// of pretending a reward was earned.
  bool get canShowRewarded => enabled && (rewardedUnitId?.isNotEmpty ?? false);

  static const disabled = AdsService(enabled: false);

  static AdsService fromRemoteConfig(FirebaseRemoteConfig? config) {
    if (config == null) return disabled;
    try {
      final enabled = config.getBool('ads_enabled');
      if (!enabled) return disabled;
      return AdsService(
        enabled: true,
        bannerUnitId: config.getString('admob_banner_unit'),
        rewardedUnitId: config.getString('admob_rewarded_unit'),
      );
    } catch (error) {
      debugPrint('Ads config unavailable: $error');
      return disabled;
    }
  }
}

/// Resolved once at boot from Remote Config.
final adsServiceProvider = Provider<AdsService>((ref) => AdsService.disabled);
