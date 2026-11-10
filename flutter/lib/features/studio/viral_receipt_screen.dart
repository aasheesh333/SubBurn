import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/clock.dart';
import '../../core/theme/theme_tokens.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../state/providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/receipt_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/surface_card.dart';
import 'roast_engine.dart';

/// Screen 3 — the viral loop.
///
/// The receipt is a single 360 × 640 node wrapped in a [RepaintBoundary], so
/// exporting it at 3× gives an exact 1080 × 1920 PNG for Stories. Nothing on
/// this screen except that node is captured.
class ViralReceiptScreen extends ConsumerStatefulWidget {
  const ViralReceiptScreen({super.key, this.onAddSubscription});

  final VoidCallback? onAddSubscription;

  @override
  ConsumerState<ViralReceiptScreen> createState() => _ViralReceiptScreenState();
}

class _ViralReceiptScreenState extends ConsumerState<ViralReceiptScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(burnSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final rates = ref.watch(ratesProvider);
    final subs = ref.watch(subscriptionsProvider);

    final roast = _roastFor(summary, settings.displayCurrency, rates.inrPerUsd);
    final lines = _receiptLines(subs, settings.displayCurrency, rates.inrPerUsd);
    final hidden = subs.length > lines.length ? subs.length - lines.length : 0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SbSpace.page,
          SbSpace.x2,
          SbSpace.page,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _IconButton(
                  icon: Icons.chevron_left_rounded,
                  label: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: SbSpace.x2),
                Text(
                  'Card studio',
                  style: SbType.h3.copyWith(color: context.sb.text),
                ),
                const Spacer(),
                const StatusBadge('9:16 · 1080×1920'),
              ],
            ),
            const SizedBox(height: SbSpace.x3),
            Expanded(
              child: _Stage(
                boundaryKey: _boundaryKey,
                child: summary.count == 0
                    ? const _EmptyReceipt()
                    : SubBurnReceiptCard(
                        lines: lines,
                        roastTier: roast.tier,
                        roastLine: roast.line,
                        ghostShare: summary.ghostShare,
                        ghostAmount: summary.ghostYearly,
                        receiptNo: 'No. ${_receiptNo(summary, settings.installId)}',
                        verdict: roast.verdict,
                        roastIntensity: roast.intensity,
                        currency: settings.displayCurrency,
                        hiddenLineCount: hidden,
                        totalOverride: summary.yearly,
                        // Pinned, not computed: an archived receipt must not
                        // change its printed per-workday figure next month.
                        workdays: 22,
                        year: SbClock.now().year,
                      ),
              ),
            ),
            const SizedBox(height: SbSpace.x2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: context.sb.safe,
                ),
                const SizedBox(width: 4),
                Text(
                  'One isolated frame · exports at 3×',
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: context.sb.textMuted,
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SbSpace.x3),
            if (summary.count == 0)
              PrimaryButton(
                label: 'Add a subscription first',
                icon: Icons.add_rounded,
                onPressed: widget.onAddSubscription,
              )
            else ...[
              PrimaryButton(
                label: _busy ? 'Rendering…' : 'Share receipt',
                icon: _busy ? null : Icons.ios_share_rounded,
                onPressed: _busy ? null : () => _share(summary, roast, 'share'),
              ),
              const SizedBox(height: SbSpace.x2),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Export PNG',
                  variant: ButtonVariant.outline,
                  icon: Icons.download_rounded,
                  onPressed: _busy
                      ? null
                      : () => _share(summary, roast, 'save'),
                ),
              ),
            ],
            const SizedBox(height: SbSpace.x3),
            Text(
              'Your receipt is generated on this device. Nothing about your '
              'subscriptions is uploaded.',
              textAlign: TextAlign.center,
              style: SbType.micro.copyWith(
                fontSize: 8,
                color: context.sb.textMuted,
                letterSpacing: 0.02,
                height: 1.5,
              ),
            ),
            const SizedBox(height: SbSpace.x3),
          ],
        ),
      ),
    );
  }

  Roast _roastFor(BurnSummary summary, CurrencyCode currency, double rate) {
    if (summary.count == 0) return Roast.empty;
    final yearlyInr = currency == CurrencyCode.inr
        ? summary.yearly
        : summary.yearly * rate;
    final monthlyInr = yearlyInr / 12;
    return const RoastEngine().generate(
      RoastInput(
        yearlyInr: yearlyInr,
        monthlyInr: monthlyInr,
        ghostShare: summary.ghostShare,
        aiShare: summary.monthly <= 0
            ? 0
            : (summary.aiMonthly / summary.monthly).clamp(0.0, 1.0),
        toolCount: summary.count,
        currency: currency,
      ),
    );
  }

  /// The card has room for six itemised lines. Anything beyond that is folded
  /// into a "+N more" line and still counted in the total.
  List<ReceiptLine> _receiptLines(
    List<Subscription> subs,
    CurrencyCode currency,
    double rate,
  ) {
    final ranked = [...subs]..sort(
        (a, b) => b
            .monthlyIn(currency, rate)
            .compareTo(a.monthlyIn(currency, rate)),
      );
    return ranked.take(6).map((s) {
      return ReceiptLine(
        name: s.name,
        monthly: s.monthlyIn(currency, rate),
        billedYearly: s.cycle == BillingCycle.yearly,
      );
    }).toList(growable: false);
  }

  /// A stable per-install receipt number. Deriving it from the amount alone
  /// meant two users with the same ledger printed the same "No. 00412".
  String _receiptNo(BurnSummary summary, String? installId) {
    final seed = installId ?? 'subburn';
    var hash = 0x811C9DC5;
    for (final unit in '$seed|${summary.yearly.round()}|${summary.count}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash % 90000 + 10000).toString();
  }

  Future<void> _share(BurnSummary summary, Roast roast, String method) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final bytes = await ref
          .read(shareServiceProvider)
          .capturePng(_boundaryKey, pixelRatio: SbSize.shareCardPixelRatio);
      final result = await ref.read(shareServiceProvider).sharePng(
            bytes,
            fileName:
                'subburn-receipt-${DateTime.now().millisecondsSinceEpoch}.png',
            text: 'My AI & SaaS burn: ${summary.currency.format(summary.yearly)}/yr. '
                '${roast.tier}.',
            sharePositionOrigin: origin,
          );

      await ref.read(analyticsProvider).logRoastCardShared(
            tier: roast.tier,
            yearlyBurn: summary.yearly,
            method: method,
          );

      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.status == ShareResultStatus.dismissed
                  ? 'Receipt is ready — 1080 × 1920 PNG'
                  : 'Receipt shared · 1080 × 1920 PNG',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not export the receipt: $error')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.boundaryKey, required this.child});

  final GlobalKey boundaryKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SbRadius.composite),
        gradient: RadialGradient(
          radius: 0.9,
          colors: context.sb.isDark
              ? const [Color(0xFF1A1013), Color(0xFF0B0B0E)]
              : [context.sb.surfaceHi, context.sb.bg],
        ),
        border: Border.all(color: context.sb.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GuidePainter(context.sb.mutedDeco)),
          ),
          Padding(
            padding: const EdgeInsets.all(SbSpace.x4),
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: boundaryKey,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed export guide from the design — purely decorative, drawn outside
/// the RepaintBoundary so it can never appear in the PNG.
class _GuidePainter extends CustomPainter {
  _GuidePainter(this.color);

  /// Painters cannot read the theme; the caller resolves the colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(
      SbSpace.x1,
      SbSpace.x1,
      size.width - SbSpace.x2,
      size.height - SbSpace.x2,
    );
    const dash = 4.0;
    const gap = 5.0;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(SbRadius.inner),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) => false;
}

class _EmptyReceipt extends StatelessWidget {
  const _EmptyReceipt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SbSize.shareCard.width,
      height: SbSize.shareCard.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0E),
          borderRadius: BorderRadius.circular(SbRadius.composite),
          border: Border.all(color: context.sb.border),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SbSpace.x6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 34,
                  color: context.sb.textMuted,
                ),
                const SizedBox(height: SbSpace.x3),
                Text(
                  'Your receipt is empty',
                  textAlign: TextAlign.center,
                  style: SbType.h3.copyWith(color: context.sb.text),
                ),
                const SizedBox(height: SbSpace.x1),
                Text(
                  'Add a subscription and a savage, itemised receipt appears here.',
                  textAlign: TextAlign.center,
                  style: SbType.caption.copyWith(color: context.sb.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadius.tile),
        child: SurfaceCard(
          height: 44,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 44,
            child: Icon(icon, size: 20, color: context.sb.text),
          ),
        ),
      ),
    );
  }
}
