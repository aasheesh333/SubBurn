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
  String format(num amount, {bool compact = false}) {
    final whole = amount.round();
    if (compact && whole >= 100000) {
      final lakhs = whole / 100000;
      return '$symbol${lakhs.toStringAsFixed(lakhs >= 10 ? 0 : 1)}L';
    }
    final digits = NumberFormat.decimalPattern(
      this == CurrencyCode.inr ? 'en_IN' : 'en_US',
    ).format(whole);
    return '$symbol$digits';
  }

  static CurrencyCode fromStorage(String value) => CurrencyCode.values.firstWhere(
        (c) => c.name == value,
        orElse: () => CurrencyCode.inr,
      );
}
