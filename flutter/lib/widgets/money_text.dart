import 'package:flutter/widgets.dart';

import '../data/models/currency.dart';
import '../theme/subburn_tokens.dart';

/// Formats money the way the design does: Indian digit grouping (`₹4,850`,
/// `₹58,200`, `₹1,24,000`), no decimals when the amount is whole.
String formatInr(num amount, {bool symbol = true}) {
  final whole = amount == amount.roundToDouble();
  final s = amount.abs().toStringAsFixed(whole ? 0 : 2);
  final parts = s.split('.');
  var digits = parts[0];

  if (digits.length > 3) {
    final last3 = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final buf = <String>[];
    while (head.length > 2) {
      buf.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) buf.insert(0, head);
    digits = '${buf.join(',')},$last3';
  }

  final out = parts.length > 1 ? '$digits.${parts[1]}' : digits;
  final sign = amount < 0 ? '−' : '';
  return '$sign${symbol ? '₹' : ''}$out';
}

/// Currency / countdown text. Always monospace, always tabular so digits
/// don't jitter when a value updates live.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.color,
    this.suffix,
    this.suffixColor,
    this.gradient,
    this.semanticLabel,
    this.currency,
    this.scaleWithSystem = true,
  }) : rawValue = null;

  /// Pre-formatted string (e.g. `'14h 22m'`) instead of a formatted amount.
  const MoneyText.raw(
    String value, {
    super.key,
    this.style,
    this.color,
    this.suffix,
    this.suffixColor,
    this.gradient,
    this.semanticLabel,
    this.currency,
    this.scaleWithSystem = true,
  })  : rawValue = value,
        amount = null;

  final num? amount;
  final String? rawValue;
  final TextStyle? style;
  /// Defaults to the theme's primary text colour when null.
  final Color? color;
  final String? suffix;

  /// Overrides the suffix colour. The dark-locked share receipt needs this:
  /// the ambient light theme's muted grey on the receipt's near-black card
  /// failed contrast and leaked into the exported PNG.
  final Color? suffixColor;
  final Gradient? gradient;
  final String? semanticLabel;

  /// When set, the amount is formatted in this currency (Indian or western
  /// digit grouping). Defaults to the rupee formatter for design parity.
  final CurrencyCode? currency;

  /// Whether the number scales with the OS text-size setting.
  ///
  /// True almost everywhere: clamping to 1.3 ignored users who run 200 %, which
  /// is a WCAG failure. The share receipt is the exception — it is a fixed
  /// 360 × 640 image, so scaling it would break the export layout.
  final bool scaleWithSystem;

  String get _text {
    if (rawValue != null) return rawValue!;
    final value = amount ?? 0;
    return currency?.format(value) ?? formatInr(value);
  }

  @override
  Widget build(BuildContext context) {
    final base = (style ?? SbType.moneyMd)
        .copyWith(color: gradient == null ? (color ?? context.sb.text) : null);

    Widget text = Text(
      _text,
      style: base,
      semanticsLabel: semanticLabel ?? _text,
      textScaler: scaleWithSystem
          ? MediaQuery.textScalerOf(context)
          : TextScaler.noScaling,
    );

    if (gradient != null) {
      text = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: gradient!.createShader,
        child: text,
      );
    }

    if (suffix == null) return text;

    // The amount must never be the thing that overflows. On a 320 px screen at
    // 130 % text a five-digit price plus its suffix is wider than the card, so
    // the number is allowed to shrink inside its own run while the suffix keeps
    // its intrinsic size.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: text,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          suffix!,
          style: SbType.micro.copyWith(
            color: suffixColor ?? context.sb.textMuted,
            fontSize: 8.5,
            letterSpacing: 0,
          ),
          textScaler: scaleWithSystem
              ? MediaQuery.textScalerOf(context)
              : TextScaler.noScaling,
        ),
      ],
    );
  }
}
