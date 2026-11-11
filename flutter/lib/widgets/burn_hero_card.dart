import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../data/models/currency.dart';
import '../theme/subburn_tokens.dart';
import 'money_text.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.sb.heroSurface,
          stops: const [0, 0.52, 1],
        ),
        border: Border.all(color: context.sb.heroBorder),
        boxShadow: [
          ...context.sb.cardShadow,
          if (context.sb.isDark) SbShadow.heroGlow,
        ],
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
                  gradient: SbGradients.heroGlow,
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
                      style: SbType.label.copyWith(color: context.sb.textMuted),
                    ),
                    const Spacer(),
                    // Flexible + ellipsis: both ends of this row are intrinsic
                    // and overflowed by ~100 px at 200 % text scale.
                    if (delta != null)
                      Flexible(child: _Delta(delta: delta!, currency: currency)),
                  ],
                ),
                const SizedBox(height: SbSpace.x1),
                // Keyed by currency so a currency switch snaps to the new value
                // instead of rolling the counter across units — animating
                // ₹8,300 → $100 shows dollar amounts that never existed.
                SbAnimatedNumber(
                  key: ValueKey(currency),
                  value: monthlyTotal,
                  builder: (context, value) => MoneyText(
                    value,
                    style: SbType.display,
                    // Palette gradient, not the dark-only token: the light
                    // theme's heroAmount starts mid-orange because white-on-
                    // white made the product's headline number invisible.
                    gradient: context.sb.heroAmount,
                    suffix: '/ mo',
                    currency: currency,
                    semanticLabel:
                        '${currency.format(monthlyTotal)} per month',
                  ),
                ),
                const SizedBox(height: 10),
                if (toolCount == 0)
                  Text(
                    'Nothing tracked yet',
                    style: SbType.caption.copyWith(
                      color: context.sb.textSecondary,
                    ),
                  )
                else
                  // One flexible Text, not three: at 320 dp the separate runs
                  // overflowed by 73 px because only the first could shrink.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$toolCount '
                              '${toolCount == 1 ? 'tool' : 'tools'} tracked · ',
                        ),
                        TextSpan(
                          text: currency.format(ghostAmount),
                          style: SbType.micro.copyWith(
                            fontSize: 9.5,
                            color: context.sb.accentWarm,
                          ),
                        ),
                        const TextSpan(text: ' is ghost spend'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SbType.caption
                        .copyWith(color: context.sb.textSecondary),
                  ),
                // A 100 %-active bar over zero subscriptions is a claim, not a
                // measurement, so the split only appears once it can be true.
                if (toolCount > 0) ...[
                  const SizedBox(height: SbSpace.x3),
                  _SplitBar(
                    activeFraction: _activeFraction,
                    ghostPercent: ghostPct,
                  ),
                  const SizedBox(height: SbSpace.x2),
                  // Two legends that can each shrink; `Spacer` pushed them
                  // past the card edge at 320 dp.
                  Row(
                    children: [
                      Expanded(
                        child: _Legend(
                          color: context.sb.accent,
                          label: 'Active use',
                          value: pct,
                        ),
                      ),
                      const SizedBox(width: SbSpace.x2),
                      Expanded(
                        child: _Legend(
                          color: context.sb.mutedDeco,
                          label: 'Ghost subs',
                          value: ghostPct,
                          alignEnd: true,
                        ),
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
        CustomPaint(
          size: const Size(6, 6),
          painter: _CaretPainter(context.sb.accentWarm),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${currency.format(delta)} added this month',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SbType.micro.copyWith(
              fontSize: 8,
              color: context.sb.accentWarm,
              letterSpacing: 0.02,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter(this.color);

  /// Painters have no BuildContext, so the resolved colour is passed in.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  const _SplitBar({required this.activeFraction, required this.ghostPercent});

  final double activeFraction;

  /// Printed in the semantics label so screen readers get the same split the
  /// bar shows visually.
  final String ghostPercent;

  @override
  Widget build(BuildContext context) {
    final active = activeFraction.clamp(0.0, 1.0);
    final reduce = SbMotion.reduced(context);

    return Semantics(
      // ghostPercent already carries its '%' — the old label made screen
      // readers announce "26.0% percent".
      label:
          'Active use ${(active * 100).toStringAsFixed(1)} percent, ghost subscriptions ${ghostPercent.replaceAll('%', '')} percent',
      child: TweenAnimationBuilder<double>(
        // Grows from the left once, and animates any change in the split.
        tween: Tween<double>(begin: reduce ? active : 0, end: active),
        duration: SbMotion.of(context, SbMotion.value),
        curve: SbMotion.curve,
        builder: (context, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            // At exactly 0 % or 100 % a single full-width segment is drawn:
            // the flex clamp(1, …) needed to avoid a zero-width child used to
            // leave a visible stub of the opposite colour.
            child: value <= 0
                ? Container(color: context.sb.mutedDeco)
                : value >= 1
                    ? Container(
                        decoration:
                            const BoxDecoration(gradient: SbGradients.burn),
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: (value * 1000).round().clamp(1, 1000),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: SbGradients.burn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            flex: ((1 - value) * 1000).round().clamp(1, 1000),
                            child: Container(color: context.sb.mutedDeco),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final Color color;
  final String label;
  final String value;

  /// Right-hand legend sits against the card edge.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            gradient: color == context.sb.accent ? SbGradients.burn : null,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SbType.caption
                .copyWith(fontSize: 9.5, color: context.sb.textSecondary),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: SbType.micro.copyWith(fontSize: 9, color: context.sb.textMuted),
        ),
      ],
    );
    return alignEnd ? Align(alignment: Alignment.centerRight, child: row) : row;
  }
}
