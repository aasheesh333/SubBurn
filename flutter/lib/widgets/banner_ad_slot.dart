import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_tokens.dart';
import '../services/ads_service.dart';

/// Reserved space for a banner ad, rendered only when ads are actually
/// configured.
///
/// The slot exists now so the layout does not jump on the day AdMob is enabled,
/// but it renders nothing while [AdsService.canShowBanner] is false — an empty
/// grey box is worse than no box, and Play treats a linked ad SDK as a data
/// collection change.
class BannerAdSlot extends ConsumerWidget {
  const BannerAdSlot({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsServiceProvider);
    if (!ads.canShowBanner) return const SizedBox.shrink();

    // The real banner plugin is intentionally not linked yet. This box marks the
    // reserved area and keeps the design honest until the AdMob unit exists.
    return Semantics(
      label: 'Advertisement',
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: SbSpace.page),
        decoration: BoxDecoration(
          color: context.sb.surface,
          borderRadius: BorderRadius.circular(SbRadius.inner),
          border: Border.all(color: context.sb.border),
        ),
        alignment: Alignment.center,
        child: Text(
          'AD',
          style: SbType.micro.copyWith(
            fontSize: 8,
            color: context.sb.textMuted,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
