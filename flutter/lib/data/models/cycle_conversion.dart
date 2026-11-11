import 'billing_cycle.dart';

/// Switching the billing cycle on Quick Add must convert the amount, not just
/// relabel it.
///
/// Kept as a pure function so the rule is unit-testable without pumping the
/// sheet: the same 17 % annual discount must apply no matter which cycle the
/// user came from, and leaving yearly must undo exactly what entering it added.
abstract final class CycleConversion {
  /// Annual discount advertised on the Yearly pill.
  static const annualDiscount = 0.17;

  /// Converts [amount] from [from] to [to].
  ///
  /// [discountApplied] says whether the current yearly amount already includes
  /// the annual discount, so a round trip is loss-free.
  static ConversionResult convert({
    required double amount,
    required BillingCycle from,
    required BillingCycle to,
    required bool discountApplied,
  }) {
    if (from == to) {
      return ConversionResult(amount, discountApplied: discountApplied);
    }

    final monthly = amount * from.monthlyFactor;

    if (to == BillingCycle.yearly) {
      // Entering yearly from any cycle: apply the discount exactly once.
      final yearly = monthly * 12 * (1 - annualDiscount);
      return ConversionResult(_round(yearly), discountApplied: true);
    }

    // Leaving yearly: undo the discount only if it was actually applied.
    final unDiscounted =
        discountApplied ? monthly / (1 - annualDiscount) : monthly;
    return ConversionResult(
      _round(unDiscounted / to.monthlyFactor),
      discountApplied: false,
    );
  }

  /// Rounds to currency minor units, not whole units: rounding to `1` turned a
  /// toggled $9.99/mo plan into $10/mo — the exact cent-eating bug the
  /// formatter layer was fixed for.
  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

class ConversionResult {
  const ConversionResult(this.amount, {required this.discountApplied});

  final double amount;
  final bool discountApplied;
}
