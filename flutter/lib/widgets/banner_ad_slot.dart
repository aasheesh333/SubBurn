import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/theme_tokens.dart';
import '../services/ads_bootstrap.dart';
import '../services/ads_service.dart';

/// One anchored-adaptive banner for the entire app, loaded lazily and once.
///
/// The slot is mounted by [HomeShell] above the bottom navigation bar, which
/// gives it three properties the old per-screen placement could not:
/// * **Static** — a single instance lives as long as the shell, so switching
///   tabs never disposes or reloads it. Timed reloads are left to the SDK's
///   own refresh cycle ("reload, but on time").
/// * **Always at the bottom** — same position and height on every screen,
///   above the tab bar, never over content or a tap target.
/// * **Small** — the standard anchored-adaptive size (~50 dp), not the large
///   ~100 dp variant: a banner should be a strip, not a second screen.
///   Height is reserved once, when the first real ad fills, and then stays
///   constant everywhere. A failed fill keeps rendering nothing rather than
///   an empty grey band.
///
/// Debug builds always request Google's test unit, never the live one.
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

    // Standard anchored adaptive (~50 dp on phones), NOT the "large" variant:
    // large anchored adaptive takes ~100 dp of chrome, far too much of a
    // utility app's screen. google_mobile_ads 9.2.0 only offers the standard
    // size through this (nominally deprecated) call — its suggested
    // replacement is the large one — so the lint is silenced deliberately.
    const anchoredAdaptive =
        // ignore: deprecated_member_use
        AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize;
    final size = await anchoredAdaptive(widthDp);
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
