import 'package:flutter/material.dart';

import '../data/models/currency.dart';
import '../data/models/receipt_theme.dart';
import '../core/theme/theme_tokens.dart';
import '../theme/subburn_tokens.dart';
import '../widgets/money_text.dart';

/// A single itemised line on the receipt.
///
/// [monthly] is always the monthly equivalent of the charge the vendor really
/// takes. Nothing here re-applies an annual discount: Quick Add already stores
/// the discounted annual amount, so applying 17 % again would print a figure
/// the user was never charged (it used to — ₹13,778 instead of ₹16,600).
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.monthly,
    this.months = 12,
    this.billedYearly = false,
  });

  final String name;

  /// Monthly equivalent of the real charge.
  final num monthly;

  final int months;

  /// True when the vendor bills this tool once a year. Used for the label only.
  final bool billedYearly;

  num get annual => (monthly * months).round();

  String quantityLabelIn(CurrencyCode currency) => billedYearly
      ? '${currency.format(annual)} billed yearly'
      : '${currency.format(monthly)}/mo × $months';
}

/// The viral artefact.
///
/// **Handoff invariant:** this widget is *self-contained*. It draws to its own
/// 360×640 box, uses no shadows that bleed outside its bounds, and never reads
/// ambient theme/inherited widgets. That is what makes it safe to wrap in a
/// single [RepaintBoundary] and export at 3× → 1080×1920 PNG with no clipping.
///
/// ```dart
/// final key = GlobalKey();
/// RepaintBoundary(key: key, child: SubBurnReceiptCard(...));
/// final image = await key.currentContext!.findRenderObject() as RenderRepaintBoundary;
/// final bytes = await image.toImage(pixelRatio: 3).then((i) => i.toByteData(format: ImageByteFormat.png));
/// ```
class SubBurnReceiptCard extends StatelessWidget {
  const SubBurnReceiptCard({
    super.key,
    required this.lines,
    required this.roastTier,
    required this.roastLine,
    required this.ghostShare,
    required this.receiptNo,
    this.ghostAmount,
    this.headline = 'MY 2026 AI',
    this.headlineAccent = 'TAX RECEIPT',
    this.subline = 'AUDIT OF RECKLESS OPTIMISM',
    this.verdict = 'That is 2 years of a Mumbai gym membership.',
    this.year = 2026,
    this.roastIntensity = 4,
    this.currency = CurrencyCode.inr,
    this.hiddenLineCount = 0,
    this.totalOverride,
    this.workdays = 22,
    this.theme = ReceiptTheme.ember,
  });

  final List<ReceiptLine> lines;
  final String roastTier;
  final String roastLine;

  /// 0..1 — drives the ghost-spend meter width.
  final double ghostShare;

  /// Exact yearly ghost spend. Pass it rather than deriving from [ghostShare]
  /// so the printed figure matches the data (no rounding drift).
  final num? ghostAmount;
  final String receiptNo;
  final String headline;
  final String headlineAccent;
  final String subline;
  final String verdict;
  final int year;

  /// 1..5 — how many of the five roast-meter bars are lit.
  final int roastIntensity;

  /// Currency every figure on the card is rendered in.
  final CurrencyCode currency;

  /// Tools excluded from the itemised list when the ledger is long.
  /// Their spend still counts towards the total.
  final int hiddenLineCount;

  /// Authoritative yearly total. When null it is derived from [lines] — which
  /// is only correct when every line is shown.
  final num? totalOverride;

  /// Weekdays in the current month, used for the per-workday figure.
  final int workdays;

  /// Colour treatment. Ember is the product default; the other two are the
  /// rewarded unlock.
  final ReceiptTheme theme;

  num get _total =>
      totalOverride ?? lines.fold<num>(0, (sum, l) => sum + l.annual);

  @override
  Widget build(BuildContext context) {
    // Hard-locked to the export box, and hard-locked to the dark palette: the
    // receipt is a dark artefact that gets exported as a PNG, so it must look
    // identical in light mode. Reading the ambient theme here made the title
    // white-on-white.
    // One label for the whole card: as loose text nodes it read as forty
    // disconnected fragments in TalkBack.
    return ReceiptThemeScope(
      theme: theme,
      child: Semantics(
        container: true,
        label: 'AI tax receipt: ${currency.format(_total)} per year, '
            '$roastTier. $verdict',
        child: ExcludeSemantics(
          child: SizedBox(
            width: SbSize.shareCard.width,
            height: SbSize.shareCard.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SbRadius.composite),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF0B0B0E)),
                child: Stack(
                  children: [
                    // glows live *inside* the clip, so the export has clean edges
                    Positioned(
                      left: -90,
                      top: -230,
                      child: Container(
                        width: 420,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Derived from the active receipt theme — a hardcoded
                          // ember bloom contradicted every themed element under
                          // Mono/Gold, on screen and in the exported PNG. This
                          // is built above the scope, so it reads `theme`
                          // directly rather than ReceiptThemeScope.of().
                          gradient: RadialGradient(
                            colors: [
                              theme.accent.withValues(alpha: 0.30),
                              theme.accentAlt.withValues(alpha: 0.08),
                              const Color(0x00000000),
                            ],
                            stops: const [0, 0.46, 0.68],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -80,
                      bottom: -235,
                      child: Container(
                        width: 520,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.accent.withValues(alpha: 0.24),
                              const Color(0x00000000),
                            ],
                            stops: const [0, 0.64],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      // Bottom inset reserves the barcode strip, which is pinned to
                      // the edge so it never floats mid-card.
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 88),
                      child: FittedBox(
                        // Authored at 316 px wide. If a long roast or a sixth line
                        // makes the column taller than the export box, the content
                        // scales down by a fraction instead of overflowing.
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 316,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BrandRow(year: year, receiptNo: receiptNo),
                              const SizedBox(height: 10),
                              _Title(
                                headline: headline,
                                accent: headlineAccent,
                                subline: subline,
                              ),
                              const SizedBox(height: 10),
                              const _DashedRule(),
                              const SizedBox(height: 9),
                              const _ColumnHeads(),
                              const SizedBox(height: 7),
                              for (final l in lines) ...[
                                _LineRow(line: l, currency: currency),
                                const SizedBox(height: 7),
                              ],
                              if (hiddenLineCount > 0) ...[
                                Text(
                                  '+ $hiddenLineCount MORE TOOLS · STILL BURNING',
                                  style: SbType.micro.copyWith(
                                    fontSize: 6.5,
                                    color: const Color(0xFF6E6E78),
                                    letterSpacing: 0.12 * 6.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],
                              const SizedBox(height: 1),
                              _GhostStrip(
                                share: ghostShare,
                                amount: ghostAmount ??
                                    (_total * ghostShare).round(),
                                currency: currency,
                              ),
                              const SizedBox(height: 9),
                              _StatsStrip(
                                total: _total,
                                toolCount: lines.length + hiddenLineCount,
                                currency: currency,
                                workdays: workdays,
                              ),
                              const SizedBox(height: 9),
                              _TotalBlock(total: _total, currency: currency),
                              const SizedBox(height: 8),
                              _RoastBlock(
                                tier: roastTier,
                                line: roastLine,
                                intensity: roastIntensity,
                              ),
                              const SizedBox(height: 8),
                              _VerdictStrip(verdict: verdict),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 22,
                      right: 22,
                      bottom: 20,
                      child: _ReceiptFooterStrip(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.year, required this.receiptNo});

  final int year;
  final String receiptNo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            gradient: SbGradients.burn,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'SUBBURN · WRAPPED $year',
          style: SbType.micro.copyWith(
            fontSize: 8,
            color: ReceiptThemeScope.of(context).accentAlt,
            letterSpacing: 0.17 * 8,
          ),
        ),
        const Spacer(),
        Text(
          receiptNo,
          style: SbType.micro.copyWith(
            fontSize: 8,
            color: const Color(0xFF6E6E78),
            letterSpacing: 0.1 * 8,
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(
      {required this.headline, required this.accent, required this.subline});

  final String headline;
  final String accent;
  final String subline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$headline\n',
              style: SbType.h1.copyWith(color: SbPalette.dark.text),
            ),
            TextSpan(
              text: accent,
              style: SbType.h1.copyWith(color: ReceiptThemeScope.of(context).accent),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          subline,
          style: SbType.micro.copyWith(
            fontSize: 8,
            color: const Color(0xFF6E6E78),
            letterSpacing: 0.15 * 8,
          ),
        ),
      ],
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 3.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Container(width: dash, height: 1, color: const Color(0xFF3A3A42)),
              const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads();

  @override
  Widget build(BuildContext context) {
    final style = SbType.micro.copyWith(
      fontSize: 6.5,
      color: const Color(0xFF55555F),
      letterSpacing: 0.14 * 6.5,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text('LINE ITEM', style: style), Text('ANNUAL', style: style)],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.currency});

  final ReceiptLine line;
  final CurrencyCode currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expanded, not Spacer: a long tool name (a real catalogue entry, or a
        // user's custom name) used to push the amount off the card edge.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SbType.body.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE9E9EC),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                line.quantityLabelIn(currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SbType.micro.copyWith(
                  fontSize: 7.5,
                  color: const Color(0xFF6E6E78),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          currency.format(line.annual),
          style: SbType.micro.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: SbPalette.dark.text,
          ),
        ),
      ],
    );
  }
}

/// One decimal so 25.67 % prints as 25.7 % instead of a rounded lie.
String _percent(double share) {
  final pct = share * 100;
  if ((pct - pct.roundToDouble()).abs() < 0.05) return pct.round().toString();
  return pct.toStringAsFixed(1);
}

class _GhostStrip extends StatelessWidget {
  const _GhostStrip({
    required this.share,
    required this.amount,
    required this.currency,
  });

  final double share;
  final num amount;
  final CurrencyCode currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: SbPalette.dark.warn.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: SbPalette.dark.warn.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'GHOST SPEND',
                style: SbType.micro.copyWith(
                  fontSize: 7,
                  color: const Color(0xFFC79447),
                  letterSpacing: 0.12 * 7,
                ),
              ),
              const Spacer(),
              Text(
                '${_percent(share)}% · ${currency.format(amount)}/YR',
                style: SbType.micro.copyWith(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFBBF24),
                  letterSpacing: 0.04 * 7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: (share * 1000).round().clamp(1, 1000),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SbPalette.dark.warn,
                            ReceiptThemeScope.of(context).accent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - share) * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: Color(0xFF242329)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-up audit strip: tool count, monthly average, per-workday cost.
/// The per-workday framing is the line that actually lands the joke.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.total,
    required this.toolCount,
    required this.currency,
    required this.workdays,
  });

  final num total;
  final int toolCount;
  final CurrencyCode currency;
  final int workdays;

  @override
  Widget build(BuildContext context) {
    final monthly = total / 12;
    final perWorkday = monthly / (workdays <= 0 ? 22 : workdays);

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF26262D)),
          bottom: BorderSide(color: Color(0xFF26262D)),
        ),
      ),
      child: Row(
        children: [
          _Stat(k: 'TOOLS', v: '$toolCount', divider: false),
          _Stat(k: 'AVG / MO', v: currency.format(monthly)),
          _Stat(k: 'PER WORKDAY', v: currency.format(perWorkday.round())),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.k, required this.v, this.divider = true});

  final String k;
  final String v;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.fromLTRB(divider ? 10 : 0, 9, 4, 10),
        decoration: BoxDecoration(
          border: divider
              ? const Border(left: BorderSide(color: Color(0xFF26262D)))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              style: SbType.micro.copyWith(
                fontSize: 6,
                color: const Color(0xFF5E5E68),
                letterSpacing: 0.15 * 6,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    v,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: SbType.micro.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE4E4E8),
                      letterSpacing: -0.03 * 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.total, required this.currency});

  final num total;
  final CurrencyCode currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF26262D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL YEARLY BURN',
            style: SbType.micro.copyWith(
              fontSize: 7,
              color: const Color(0xFF7B7B85),
              letterSpacing: 0.17 * 7,
            ),
          ),
          const SizedBox(height: 1),
          MoneyText(
            total,
            style: SbType.display
                .copyWith(fontSize: 40, letterSpacing: -0.055 * 40),
            gradient: ReceiptThemeScope.of(context).totalGradient,
            suffix: '/yr',
            // The receipt is dark-locked; the ambient light theme's muted grey
            // leaked in here and failed contrast on the near-black card (and in
            // the exported PNG). Pin the suffix to the dark palette.
            suffixColor: SbPalette.dark.textMuted,
            scaleWithSystem: false,
            semanticLabel: '${currency.format(total)} per year',
          ),
        ],
      ),
    );
  }
}

class _RoastBlock extends StatelessWidget {
  const _RoastBlock({
    required this.tier,
    required this.line,
    required this.intensity,
  });

  final String tier;
  final String line;
  final int intensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        // Themed wash: the ember-tinted fill stayed orange under Mono/Gold
        // while the border and tier text had already been migrated.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ReceiptThemeScope.of(context).accent.withValues(alpha: 0.14),
            ReceiptThemeScope.of(context).accentAlt.withValues(alpha: 0.03),
          ],
        ),
        border:
            Border.all(
              color: ReceiptThemeScope.of(context)
                  .accent
                  .withValues(alpha: 0.38),
            ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TIER: ',
                style: SbType.micro.copyWith(
                  fontSize: 7.5,
                  color: ReceiptThemeScope.of(context).accent,
                  letterSpacing: 0.1 * 7.5,
                ),
              ),
              Expanded(
                child: Text(
                  tier.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.micro.copyWith(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: ReceiptThemeScope.of(context).accent,
                    letterSpacing: 0.1 * 7.5,
                  ),
                ),
              ),
              const SizedBox(width: SbSpace.x2),
              for (var i = 0; i < 5; i++) ...[
                Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    // Lit bars follow the theme's own gradient. The old fixed
                    // SbGradients.burn shader overrode the themed color
                    // entirely (a shader wins over paint.color), so Mono/Gold
                    // meters still rendered ember.
                    color: i < intensity
                        ? ReceiptThemeScope.of(context).accent
                        : const Color(0xFF2A2A31),
                    gradient: i < intensity
                        ? ReceiptThemeScope.of(context).totalGradient
                        : null,
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            line,
            style: SbType.caption.copyWith(
              fontSize: 9,
              height: 1.4,
              color: const Color(0xFFDCDCE0),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictStrip extends StatelessWidget {
  const _VerdictStrip({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF212127)),
      ),
      child: Row(
        children: [
          Text(
            'VERDICT',
            style: SbType.micro.copyWith(
              fontSize: 6.5,
              color: const Color(0xFF5C5C66),
              letterSpacing: 0.16 * 6.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              verdict,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SbType.caption.copyWith(
                fontSize: 9.5,
                color: const Color(0xFFC9C9D0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barcode and footer, pinned to the bottom edge of the card.
class _ReceiptFooterStrip extends StatelessWidget {
  const _ReceiptFooterStrip();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Barcode(),
        SizedBox(height: 8),
        _ReceiptFooter(),
      ],
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode();

  @override
  Widget build(BuildContext context) {
    final widths = [1.0, 1.0, 2.0, 1.0, 3.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0, 3.0];
    return Opacity(
      opacity: 0.62,
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            for (var i = 0; i < 46; i++) ...[
              Container(
                  width: widths[i % widths.length],
                  color: const Color(0xFF9C9CA6)),
              const SizedBox(width: 1.6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptFooter extends StatelessWidget {
  const _ReceiptFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(
            top:
                BorderSide(color: Color(0xFF2A2A31), style: BorderStyle.solid)),
      ),
      child: Row(
        children: [
          Text(
            'SUBBURN.APP',
            style: SbType.micro.copyWith(
              fontSize: 6.5,
              color: const Color(0xFF55555F),
              letterSpacing: 0.13 * 6.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 18,
            height: 18,
            child: GridView.count(
              crossAxisCount: 5,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: List.generate(25, (i) {
                final on = {
                  0,
                  1,
                  2,
                  5,
                  6,
                  7,
                  10,
                  12,
                  14,
                  17,
                  18,
                  19,
                  20,
                  22,
                  24
                };
                return ColoredBox(
                  color: on.contains(i)
                      ? const Color(0xFF6E6E78)
                      : const Color(0xFF6E6E78).withValues(alpha: 0.14),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
