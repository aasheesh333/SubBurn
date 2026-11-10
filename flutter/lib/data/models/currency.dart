import 'package:intl/intl.dart';

/// Currencies the tracker can display and store.
///
/// Amounts are always stored in the currency they were entered in — the same
/// way a bank statement shows them — and converted only for aggregation.
enum CurrencyCode {
  inr,
  usd;

  String get symbol => switch (this) {
        CurrencyCode.inr => '₹',
        CurrencyCode.usd => r'$',
      };

  String get code => switch (this) {
        CurrencyCode.inr => 'INR',
        CurrencyCode.usd => 'USD',
      };

  /// Indian grouping for INR (`₹1,24,000`), western grouping for USD.
  ///
  /// **Decimals are preserved.** This used to round every amount to a whole
  /// unit, so a $9.99 subscription was stored correctly and then displayed as
  /// $10 everywhere — dashboard, rows, receipt total, detail. For a money app
  /// that is a wrong number, not a formatting choice.
  ///
  /// Whole amounts stay whole (`₹1,660`, not `₹1,660.00`), which keeps the
  /// design's mono figures clean.
  String format(num amount) {
    final pattern = this == CurrencyCode.inr ? 'en_IN' : 'en_US';
    final isWhole = amount == amount.roundToDouble();
    final digits = NumberFormat.decimalPatternDigits(
      locale: pattern,
      decimalDigits: isWhole ? 0 : 2,
    ).format(amount);
    return '$symbol$digits';
  }

  static CurrencyCode fromStorage(String value) => CurrencyCode.values.firstWhere(
        (c) => c.name == value,
        orElse: () => CurrencyCode.inr,
      );
}
