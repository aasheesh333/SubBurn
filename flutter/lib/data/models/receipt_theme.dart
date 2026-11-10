import 'package:flutter/material.dart';

/// Receipt colour treatments.
///
/// The default is the product's own burn palette. The other two are the
/// rewarded unlock: watching one ad once opens them permanently. They are
/// cosmetic only — no data, no totals, no feature is behind them, so nobody is
/// ever blocked from using the app.
enum ReceiptTheme {
  ember('Ember', Color(0xFFFF4500), Color(0xFFFF8C00), Color(0xFFFFA03A)),
  mono('Mono', Color(0xFFFAFAFA), Color(0xFFA1A1AA), Color(0xFFFFFFFF)),
  gold('Gold', Color(0xFFD4A017), Color(0xFFF0C24B), Color(0xFFFFD97A));

  const ReceiptTheme(this.label, this.accent, this.accentAlt, this.heroTop);

  final String label;

  /// Primary accent used for the title, total and roast border.
  final Color accent;

  /// Gradient end.
  final Color accentAlt;

  /// Bright stop of the total's gradient.
  final Color heroTop;

  bool get isFree => this == ReceiptTheme.ember;

  LinearGradient get totalGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heroTop, accent],
        stops: const [0, 0.78],
      );
}

/// Makes the active theme readable from any descendant of the receipt without
/// threading a parameter through eight constructors.
class ReceiptThemeScope extends InheritedWidget {
  const ReceiptThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final ReceiptTheme theme;

  static ReceiptTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ReceiptThemeScope>();
    return scope?.theme ?? ReceiptTheme.ember;
  }

  @override
  bool updateShouldNotify(ReceiptThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
