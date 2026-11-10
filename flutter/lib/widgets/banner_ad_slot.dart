import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/theme_tokens.dart';
import '../services/ads_bootstrap.dart';
import '../services/ads_service.dart';

/// One adaptive banner, loaded lazily.
///
/// Placement rules this widget enforces:
/// * It renders nothing until Remote Config says ads are on *and* the SDK
///   initialised, so a misconfigured build never shows a grey box.
/// * It reserves its height only after a real ad loads, so the layout does not
///   jump if the fill fails (a blank rectangle is worse than no rectangle).
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
    if (!AdsBootstrap.isInitialised) await AdsBootstrap.initialise();
    if (!AdsBootstrap.isInitialised || !mounted) return;

    final ad = BannerAd(
      adUnitId: ads.bannerUnitId ?? AdUnits.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // Silence is correct here: a failed fill is normal, and the layout
          // simply keeps its space. Never retry in a tight loop.
          debugPrint('banner failed: ${error.message}');
          ad.dispose();
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
    // No reservation until a real ad exists: an empty grey band reads as a bug.
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Advertisement',
      child: SizedBox(
        height: _ad!.size.height.toDouble(),
        width: double.infinity,
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

/// A thin divider above the banner so it reads as a separate region rather than
/// part of the ledger.
class BannerAdRegion extends ConsumerWidget {
  const BannerAdRegion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsServiceProvider);
    if (!ads.canShowBanner) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: SbSpace.x2),
        Container(
          height: SbSize.hairline,
          margin: const EdgeInsets.symmetric(horizontal: SbSpace.page),
          color: context.sb.border,
        ),
        const BannerAdSlot(),
      ],
    );
  }
}
