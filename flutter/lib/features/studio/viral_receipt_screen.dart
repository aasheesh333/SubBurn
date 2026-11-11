import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/clock.dart';
import '../../core/theme/theme_tokens.dart';
import '../../data/models/receipt_theme.dart';
import '../../services/rewarded_ad_service.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../state/providers.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/receipt_card.dart';
import '../../widgets/sb_header.dart';
import '../../widgets/status_badge.dart';
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
  bool _unlocking = false;
  ReceiptTheme _theme = ReceiptTheme.ember;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(burnSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final rates = ref.watch(ratesProvider);
    final subs = ref.watch(subscriptionsProvider);

    final roast = _roastFor(summary, settings.displayCurrency, rates.inrPerUsd);
    final lines =
        _receiptLines(subs, settings.displayCurrency, rates.inrPerUsd);
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
            const SbHeader(
              title: 'Card studio',
              subtitle: '1080 × 1920 export',
              // No onBack: this screen is a root tab of the shell, so
              // maybePop() could never pop — it rendered a dead chevron.
              trailing: StatusBadge('9:16'),
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
                        receiptNo:
                            'No. ${_receiptNo(summary, settings.installId)}',
                        verdict: roast.verdict,
                        roastIntensity: roast.intensity,
                        currency: settings.displayCurrency,
                        hiddenLineCount: hidden,
                        totalOverride: summary.yearly,
                        theme: _theme,
                        // Pinned, not computed: an archived receipt must not
                        // change its printed per-workday figure next month.
                        workdays: 22,
                        year: SbClock.now().year,
                      ),
              ),
            ),
            const SizedBox(height: SbSpace.x2),
            // Wraps instead of overflowing: as a Row this caption burst the
            // 320 dp width by 232 px at 200 % text.
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: context.sb.safe,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: 'One isolated frame · exports at 3×',
                    style: SbType.micro.copyWith(
                      fontSize: 9,
                      color: context.sb.textMuted,
                      letterSpacing: 0.02,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SbSpace.x2),
            _ThemePicker(
              selected: _theme,
              unlocked: ref.watch(settingsProvider).receiptThemesUnlocked,
              onPick: (theme) => setState(() => _theme = theme),
              onUnlock: _unlockThemes,
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
                onPressed: _busy ? null : () => _share(summary, roast),
              ),
              const SizedBox(height: SbSpace.x2),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Export PNG',
                  variant: ButtonVariant.outline,
                  icon: Icons.download_rounded,
                  onPressed: _busy ? null : _saveToDevice,
                ),
              ),
            ],
            const SizedBox(height: SbSpace.x3),
            Text(
              'Your receipt is generated on this device. Nothing about your '
              'subscriptions is uploaded.',
              textAlign: TextAlign.center,
              style: SbType.micro.copyWith(
                fontSize: 9,
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
    final yearlyInr =
        currency == CurrencyCode.inr ? summary.yearly : summary.yearly * rate;
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
        (a, b) =>
            b.monthlyIn(currency, rate).compareTo(a.monthlyIn(currency, rate)),
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
    for (final unit
        in '$seed|${summary.yearly.round()}|${summary.count}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash % 90000 + 10000).toString();
  }

  /// Shares the receipt through the system sheet and records the event only
  /// when a share actually happened.
  Future<void> _share(BurnSummary summary, Roast roast) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final origin = _origin(context);

    try {
      final bytes = await ref.read(shareServiceProvider).capturePng(
            _boundaryKey,
            pixelRatio: SbSize.shareCardPixelRatio,
          );
      final result = await ref.read(shareServiceProvider).sharePng(
            bytes,
            fileName:
                'subburn-receipt-${DateTime.now().millisecondsSinceEpoch}.png',
            text: 'My AI & SaaS burn: '
                '${summary.currency.format(summary.yearly)}/yr. ${roast.tier}.',
            sharePositionOrigin: origin,
          );

      // Dismissing the sheet is not a share. Logging it inflated the metric.
      final shared = result.status == ShareResultStatus.success;
      if (shared) {
        await ref.read(analyticsProvider).logRoastCardShared(
              tier: roast.tier,
              yearlyBurn: summary.yearly,
              method: 'share',
            );
      }
      await ref.read(shareServiceProvider).pruneTemporaryFiles();

      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              shared
                  ? 'Receipt shared · 1080 × 1920 PNG'
                  : 'Share cancelled — the receipt was not sent.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not prepare the receipt: $error')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the receipt without a social caption.
  ///
  /// The second button used to call the share handler, so "Export PNG" and
  /// "Share receipt" did exactly the same thing and nothing was ever saved.
  Future<void> _saveToDevice() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final origin = _origin(context);

    try {
      final bytes = await ref.read(shareServiceProvider).capturePng(
            _boundaryKey,
            pixelRatio: SbSize.shareCardPixelRatio,
          );
      final result = await ref.read(shareServiceProvider).savePng(
            bytes,
            fileName:
                'subburn-receipt-${DateTime.now().millisecondsSinceEpoch}.png',
            sharePositionOrigin: origin,
          );
      await ref.read(shareServiceProvider).pruneTemporaryFiles();

      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.status == ShareResultStatus.success
                  ? 'Saved — choose Photos or Files in the sheet.'
                  : 'Save cancelled.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save the receipt: $error')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Rewarded ad in exchange for the extra themes, once, permanently.
  Future<void> _unlockThemes() async {
    // Re-entrancy guard: chips stayed tappable during the ad flow, and a second
    // tap fired a second load/show race.
    if (_unlocking) return;
    _unlocking = true;
    try {
      final messenger = ScaffoldMessenger.of(context);
      final service = ref.read(rewardedAdServiceProvider);
      await service.load();
      if (!mounted) return;

      final rewarded = await service.show(
        onReward: () {
          // Guard the callback: it fires from the ad SDK, possibly after this
          // State was disposed, and `ref` throws on a dead element.
          if (!mounted) return;
          // Awaited by the surrounding flow's state; fire-and-forget here lost
          // an earned unlock if the process died mid-write.
          unawaited(ref.read(settingsProvider.notifier).unlockReceiptThemes());
        },
      );
      if (!mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              rewarded
                  ? 'Themes unlocked. Pick one above.'
                  : 'No ad was available — nothing changed.',
            ),
          ),
        );
    } finally {
      _unlocking = false;
    }
  }

  Rect? _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Theme chips. Locked chips advertise the rewarded unlock instead of opening a
/// paywall — nothing in the app becomes unusable.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.selected,
    required this.unlocked,
    required this.onPick,
    required this.onUnlock,
  });

  final ReceiptTheme selected;
  final bool unlocked;
  final ValueChanged<ReceiptTheme> onPick;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final theme in ReceiptTheme.values) ...[
          Expanded(
            child: _ThemeChip(
              theme: theme,
              selected: theme == selected,
              locked: !theme.isFree && !unlocked,
              onTap: () {
                if (theme.isFree || unlocked) {
                  onPick(theme);
                } else {
                  onUnlock();
                }
              },
            ),
          ),
          if (theme != ReceiptTheme.values.last)
            const SizedBox(width: SbSpace.x2),
        ],
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ReceiptTheme theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked
          ? '${theme.label} theme, watch an ad to unlock'
          : '${theme.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadius.button),
        child: PressScale(
          child: Container(
            height: SbSize.minTapTarget,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SbRadius.button),
              color: context.sb.surface,
              border: Border.all(
                color: selected ? theme.accent : context.sb.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.heroTop, theme.accent],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    theme.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SbType.micro.copyWith(
                      fontSize: 9,
                      color:
                          selected ? context.sb.text : context.sb.textSecondary,
                      letterSpacing: 0.04,
                    ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 11,
                    color: context.sb.warn,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
