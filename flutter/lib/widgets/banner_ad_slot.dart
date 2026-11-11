import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/theme_tokens.dart';
import '../services/ads_bootstrap.dart';
import '../services/ads_service.dart';

/// One anchored-adaptive banner, loaded lazily.
///
/// Placement rules this widget enforces:
/// * It renders nothing — not even its divider — until Remote Config says ads
///   are on, the SDK initialised, *and* a real ad filled. A stray hairline with
///   nothing under it reads as a layout bug.
/// * Debug builds always request Google's test unit, never the live one.
/// * It is never placed over an interactive element — callers put it below
///   content, above the tab bar.
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key});

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (kIsWeb) return;
    final ads = ref.read(adsServiceProvider);
    if (!ads.canShowBanner) return;

    // Anchored-adaptive needs the real width; measured before any await so the
    // context use is synchronous.
    final widthDp = MediaQuery.sizeOf(context).width.truncate();
    if (widthDp <= 0) return;

    if (!AdsBootstrap.isInitialised) await AdsBootstrap.initialise();
    if (!AdsBootstrap.isInitialised || !mounted) return;

    // Anchored adaptive (v9 API): full-width, Google-optimised height, and a
    // higher-earning format than the legacy fixed 320×50 banner.
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(widthDp);
    if (!mounted) return;

    final ad = BannerAd(
      // Test id in debug *first*: the Remote Config default is the live unit,
      // and requesting it from a debug build is invalid traffic.
      adUnitId: kDebugMode ? AdUnits.banner : ads.bannerUnitId!,
      size: size ?? AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // Silence is correct here: a failed fill is normal, and the slot
          // keeps rendering nothing. Never retry in a tight loop.
          debugPrint('banner failed: ${error.message}');
          ad.dispose();
          if (_ad == ad) _ad = null;
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No reservation — and no divider — until a real ad exists.
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Advertisement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: SbSpace.x2),
          // A thin divider so the ad reads as a separate region rather than
          // part of the ledger.
          Container(
            height: SbSize.hairline,
            margin: const EdgeInsets.symmetric(horizontal: SbSpace.page),
            color: context.sb.border,
          ),
          SizedBox(
            height: _ad!.size.height.toDouble(),
            width: double.infinity,
            child: AdWidget(ad: _ad!),
          ),
        ],
      ),
    );
  }
}

/// Gate + slot. Renders nothing when ads are disabled or half-configured.
class BannerAdRegion extends ConsumerWidget {
  const BannerAdRegion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsServiceProvider);
    if (!ads.canShowBanner) return const SizedBox.shrink();
    return const BannerAdSlot();
  }
}
