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
  /// yearly on 29 February would renew on 1 March. Both are wrong by days.
  ///
  /// Single hops only. Repeated `advance` calls accumulate the clamp (31 Jan →
  /// 28 Feb → 28 Mar, while vendors charge 31 Mar) — iterate with [nthAfter]
  /// from the anchor instead.
  DateTime advance(DateTime from) => switch (this) {
        BillingCycle.weekly => from.add(const Duration(days: 7)),
        BillingCycle.monthly => addMonths(from, 1),
        BillingCycle.yearly => addMonths(from, 12),
      };

  /// The charge date [n] periods after [anchor], always measured from the
  /// anchor so a short-month clamp never sticks: a 31 Jan monthly plan renews
  /// 28 Feb *and* 31 Mar, exactly like real vendors bill.
  DateTime nthAfter(DateTime anchor, int n) => switch (this) {
        BillingCycle.weekly => anchor.add(Duration(days: 7 * n)),
        BillingCycle.monthly => addMonths(anchor, n),
        BillingCycle.yearly => addMonths(anchor, 12 * n),
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
  /// charge is not simply `advance(now)` — it is computed from the real start
  /// date. The elapsed-period estimate keeps this O(1)-ish: the old fixed 600
  /// iteration cap returned a *past* date for weekly plans older than ~11
  /// years, which then crashed the date picker (`initialDate < firstDate`).
  DateTime nextAfter(DateTime start, {DateTime? now}) {
    final clock = now ?? SbClock.now();
    var n = _periodsBetween(start, clock);
    var date = nthAfter(start, n);
    // The estimate can be one low (DST) or high; walk to the exact spot.
    while (!date.isAfter(clock)) {
      n++;
      date = nthAfter(start, n);
    }
    while (n > 0) {
      final earlier = nthAfter(start, n - 1);
      if (!earlier.isAfter(clock)) break;
      n--;
      date = earlier;
    }
    // n == 0 means the first charge *is* the start date — return it verbatim.
    // nthAfter would floor it to midnight, which is earlier than a start with
    // a time-of-day and broke the "next charge never precedes start" invariant.
    if (n == 0) return start;
    return date;
  }

  /// Lower-bound estimate of whole periods elapsed from [start] to [clock].
  int _periodsBetween(DateTime start, DateTime clock) {
    if (!clock.isAfter(start)) return 0;
    switch (this) {
      case BillingCycle.weekly:
        // A DST 23h day can undercount by one; the caller walks forward.
        final days = clock.difference(start).inDays;
        return days > 7 ? days ~/ 7 - 1 : 0;
      case BillingCycle.monthly:
      case BillingCycle.yearly:
        final months =
            (clock.year - start.year) * 12 + clock.month - start.month - 1;
        final estimate = months < 0 ? 0 : months;
        return this == BillingCycle.monthly ? estimate : estimate ~/ 12;
    }
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

  static BillingCycle fromStorage(String value) =>
      BillingCycle.values.firstWhere(
        (c) => c.name == value,
        orElse: () => BillingCycle.monthly,
      );
}
