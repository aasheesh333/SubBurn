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
  DateTime advance(DateTime from) => switch (this) {
        BillingCycle.weekly => from.add(const Duration(days: 7)),
        BillingCycle.monthly => DateTime(from.year, from.month + 1, from.day),
        BillingCycle.yearly => DateTime(from.year + 1, from.month, from.day),
      };

  static BillingCycle fromStorage(String value) => BillingCycle.values.firstWhere(
        (c) => c.name == value,
        orElse: () => BillingCycle.monthly,
      );
}
