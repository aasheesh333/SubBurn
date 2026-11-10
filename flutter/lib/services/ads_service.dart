import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Ad readiness, not ads.
///
/// Play requires a data-safety declaration the moment an ad SDK is linked, so
/// the ad slot ships **disabled** and the dependency is added only when the
/// AdMob account exists. This service is the switch: it reads Remote Config and
/// decides whether an ad surface may render at all.
///
/// To turn ads on later:
///   1. add `google_mobile_ads` to pubspec and the AdMob app id to the manifest,
///   2. set `admob_banner_unit` / `admob_interstitial_unit` in Remote Config,
///   3. flip `ads_enabled` to true and declare "Advertising" in the Play data
///      safety form (device or other IDs, approximate location if the SDK asks).
class AdsService {
  const AdsService({required this.enabled, this.bannerUnitId, this.interstitialUnitId});

  final bool enabled;
  final String? bannerUnitId;
  final String? interstitialUnitId;

  /// True only when the flag is on *and* a unit id exists. A half-configured
  /// ad surface renders nothing rather than an empty grey box.
  bool get canShowBanner => enabled && (bannerUnitId?.isNotEmpty ?? false);

  /// Rewarded is opt-in, so it only needs an id, not a separate flag: if the
  /// console clears this id, the unlock button simply hides.
  String? get rewardedUnitId => interstitialUnitId;

  static const disabled = AdsService(enabled: false);

  static AdsService fromRemoteConfig(FirebaseRemoteConfig? config) {
    if (config == null) return disabled;
    try {
      final enabled = config.getBool('ads_enabled');
      if (!enabled) return disabled;
      return AdsService(
        enabled: true,
        bannerUnitId: config.getString('admob_banner_unit'),
        interstitialUnitId: config.getString('admob_interstitial_unit'),
      );
    } catch (error) {
      debugPrint('Ads config unavailable: $error');
      return disabled;
    }
  }
}

/// Resolved once at boot from Remote Config.
final adsServiceProvider = Provider<AdsService>((ref) => AdsService.disabled);
