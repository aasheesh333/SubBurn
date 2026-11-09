import 'package:flutter/material.dart';

import '../data/models/currency.dart';
import '../theme/subburn_tokens.dart';
import 'money_text.dart';
import 'tool_tile.dart';
import 'status_badge.dart';

/// Monthly burn hero.
///
/// Structure that matters for handoff:
///  • 24 px radius, 16 px padding, 164 px tall
///  • amount is gradient-clipped (ShaderMask) over a radial glow
///  • the split bar is `activeFraction` wide; ghost is the remainder
class BurnHeroCard extends StatelessWidget {
  const BurnHeroCard({
    super.key,
    required this.monthlyTotal,
    required this.activeAmount,
    required this.ghostAmount,
    this.toolCount = 0,
    this.delta,
    this.currency = CurrencyCode.inr,
  });

  final num monthlyTotal;
  final num activeAmount;
  final num ghostAmount;
  final int toolCount;

  /// Month-over-month change, e.g. `620`.
  final num? delta;

  /// Display currency for the amount and the delta.
  final CurrencyCode currency;

  double get _activeFraction {
    final total = activeAmount + ghostAmount;
    if (total <= 0) return 1;
    return (activeAmount / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _pctLabel(_activeFraction);
    final ghostPct = _pctLabel(1 - _activeFraction);

    return Container(
      // Authored at 164-172 px. A minimum instead of a fixed height means the
      // card grows with large text on a small screen instead of clipping.
      constraints: const BoxConstraints(minHeight: 164),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SbRadius.hero),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1214), Color(0xFF131316), Color(0xFF111114)],
          stops: [0, 0.52, 1],
        ),
        border: Border.all(color: const Color(0xFF33271F)),
        boxShadow: const [SbShadow.cardInner, SbShadow.heroGlow],
      ),
      child: Stack(
        children: [
          // Radial bloom. Drawn in the unpadded stack so it can bleed to the
          // card edge and fade out naturally; the container clip trims it.
          Positioned(
            right: -96,
            top: -150,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x5CFF4500), Color(0x1AFF8C00), Color(0x00FF8C00)],
                    stops: [0, 0.45, 0.72],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SbSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'MONTHLY BURN',
                      style: SbType.label.copyWith(color: SbColors.textMuted),
                    ),
                    const Spacer(),
                    if (delta != null)
                      _Delta(delta: delta!, currency: currency),
                  ],
                ),
                const SizedBox(height: SbSpace.x1),
                MoneyText(
                  monthlyTotal,
                  style: SbType.display,
                  gradient: SbGradients.heroAmount,
                  suffix: '/ mo',
                  currency: currency,
                  semanticLabel:
                      '${currency.format(monthlyTotal)} per month',
                ),
                const SizedBox(height: 10),
                if (toolCount == 0)
                  Text(
                    'Nothing tracked yet',
                    style: SbType.caption.copyWith(
                      color: SbColors.textSecondary,
                    ),
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$toolCount ${toolCount == 1 ? 'tool' : 'tools'} tracked · ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SbType.caption
                              .copyWith(color: SbColors.textSecondary),
                        ),
                      ),
                      MoneyText(
                        ghostAmount,
                        style: SbType.micro.copyWith(fontSize: 9.5),
                        color: SbColors.accentWarm,
                      ),
                      Text(
                        ' is ghost spend',
                        style: SbType.caption
                            .copyWith(color: SbColors.textSecondary),
                      ),
                    ],
                  ),
                // A 100 %-active bar over zero subscriptions is a claim, not a
                // measurement, so the split only appears once it can be true.
                if (toolCount > 0) ...[
                  const SizedBox(height: SbSpace.x3),
                  _SplitBar(activeFraction: _activeFraction),
                  const SizedBox(height: SbSpace.x2),
                  Row(
                    children: [
                      _Legend(
                        color: SbColors.accent,
                        label: 'Active use',
                        value: pct,
                      ),
                      const Spacer(),
                      _Legend(
                        color: const Color(0xFF7A7A86),
                        label: 'Ghost subs',
                        value: ghostPct,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `74.3%` — one decimal so the bar, the legend and the receipt can never
/// disagree about the same number.
String _pctLabel(double fraction) {
  final pct = (fraction * 100).clamp(0, 100);
  return pct == pct.roundToDouble()
      ? '${pct.round()}%'
      : '${pct.toStringAsFixed(1)}%';
}

class _Delta extends StatelessWidget {
  const _Delta({required this.delta, required this.currency});

  final num delta;
  final CurrencyCode currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Drawn, not an icon font glyph, so it can never render as tofu.
        const CustomPaint(
          size: Size(6, 6),
          painter: _CaretPainter(),
        ),
        const SizedBox(width: 3),
        Text(
          '${currency.format(delta)} added this month',
          style: SbType.micro.copyWith(
            fontSize: 8,
            color: SbColors.accentWarm,
            letterSpacing: 0.02,
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SbColors.accentWarm
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => false;
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.activeFraction});

  final double activeFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: Row(
          children: [
            Expanded(
              flex: (activeFraction * 1000).round(),
              child: Container(
                decoration: const BoxDecoration(gradient: SbGradients.burn),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: ((1 - activeFraction) * 1000).round().clamp(1, 1000),
              child: Container(color: const Color(0xFF7A7A86)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            gradient: color == SbColors.accent ? SbGradients.burn : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: SbType.caption.copyWith(fontSize: 9.5, color: SbColors.textSecondary),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: SbType.micro.copyWith(fontSize: 9, color: SbColors.textMuted),
        ),
      ],
    );
  }
}

/// Renewal warning state used by the horizontal rail on the dashboard.
enum RenewalUrgency { today, tomorrow, later }

class RenewalCard extends StatelessWidget {
  const RenewalCard({
    super.key,
    required this.name,
    required this.monogram,
    required this.brandColor,
    required this.amount,
    required this.countdown,
    this.urgency = RenewalUrgency.today,
  });

  final String name;
  final String monogram;
  final Color brandColor;
  final num amount;
  final String countdown;
  final RenewalUrgency urgency;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 104,
      child: Container(
        padding: const EdgeInsets.fromLTRB(SbSpace.x3, 11, SbSpace.x3, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SbRadius.inner),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SbColors.surfaceHi, SbColors.surface],
          ),
          border: Border.all(color: SbColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ToolTile(mark: monogram, brandColor: brandColor, size: 30),
                const SizedBox(width: SbSpace.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SbType.body.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        urgency == RenewalUrgency.later ? 'Renews tomorrow' : 'Renews today',
                        style: SbType.micro.copyWith(
                          fontSize: 7.5,
                          color: SbColors.textMuted,
                          letterSpacing: 0.01,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            MoneyText(amount, style: SbType.moneyMd, suffix: '/mo'),
            StatusBadge(
              countdown,
              tone: urgency == RenewalUrgency.later ? BadgeTone.neutral : BadgeTone.warn,
              leadingDot: true,
              pulse: urgency != RenewalUrgency.later,
            ),
          ],
        ),
      ),
    );
  }
}
