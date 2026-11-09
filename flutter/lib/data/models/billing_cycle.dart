/// How a subscription is billed.
///
/// Normalisation rule used everywhere in the app:
/// * monthly  → amount
/// * yearly   → amount / 12   (the amount is the *actual* annual charge, so a
///   discounted annual plan is already cheaper per month)
/// * weekly   → amount * 52 / 12
///
/// Storing the real charge and normalising on read means a ₹8,280/yr plan and
/// a ₹690/mo plan are compared correctly without the UI inventing a discount.
library;

import '../../core/clock.dart';

/// Billing cadence for a subscription.
enum BillingCycle {
  weekly,
  monthly,
  yearly;

  /// Human label used in pills and pickers.
  String get label => switch (this) {
        BillingCycle.weekly => 'Weekly',
        BillingCycle.monthly => 'Monthly',
        BillingCycle.yearly => 'Yearly',
      };

  /// Short suffix printed after a price.
  String get suffix => switch (this) {
        BillingCycle.weekly => '/wk',
        BillingCycle.monthly => '/mo',
        BillingCycle.yearly => '/yr',
      };

  /// Multiplier that converts one charge into a monthly figure.
  double get monthlyFactor => switch (this) {
        BillingCycle.weekly => 52 / 12,
        BillingCycle.monthly => 1,
        BillingCycle.yearly => 1 / 12,
      };

  /// Charges per year — used by the lifetime-spend chart.
  double get chargesPerYear => switch (this) {
        BillingCycle.weekly => 52,
        BillingCycle.monthly => 12,
        BillingCycle.yearly => 1,
      };

  /// Advances [from] by exactly one billing period.
  ///
  /// Month arithmetic is clamped to the last valid day of the target month.
  /// Dart's `DateTime(year, month + 1, day)` *overflows* instead: a
  /// subscription billing on 31 January would renew on 3 March, and one billed
  /// yearly on 29 February would renew on 1 March. Both are wrong by days, and
  /// both silently shift every following renewal.
  DateTime advance(DateTime from) => switch (this) {
        BillingCycle.weekly => from.add(const Duration(days: 7)),
        BillingCycle.monthly => addMonths(from, 1),
        BillingCycle.yearly => addMonths(from, 12),
      };

  /// The charge before [next] — the start of the period that is ending.
  ///
  /// Derived by walking back, because a clamped advance is not invertible:
  /// 28 Feb → 31 Mar forward, but 31 Mar → 28 Feb backward. Walking back from
  /// the known next charge keeps the period honest.
  DateTime previousFrom(DateTime next) => switch (this) {
        BillingCycle.weekly => next.subtract(const Duration(days: 7)),
        BillingCycle.monthly => addMonths(next, -1),
        BillingCycle.yearly => addMonths(next, -12),
      };

  /// The first billing date strictly after [now], starting from [start].
  ///
  /// A subscription added today may have started two years ago, so the next
  /// charge is not simply `advance(now)` — it walks from the real start date.
  DateTime nextAfter(DateTime start, {DateTime? now}) {
    final clock = now ?? SbClock.now();
    var date = start;
    for (var i = 0; i <= 600 && !date.isAfter(clock); i++) {
      date = advance(date);
    }
    return date;
  }

  /// Adds [months] to [date], clamping the day to the target month's length.
  static DateTime addMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final year = date.year + (targetMonth - 1) ~/ 12;
    final month = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day <= lastDay ? date.day : lastDay;
    return DateTime(year, month, day);
  }

  static BillingCycle fromStorage(String value) => BillingCycle.values.firstWhere(
        (c) => c.name == value,
        orElse: () => BillingCycle.monthly,
      );
}
