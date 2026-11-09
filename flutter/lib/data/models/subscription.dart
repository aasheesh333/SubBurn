import 'billing_cycle.dart';
import 'currency.dart';
import 'usage_guilt.dart';

/// One tracked subscription.
///
/// Everything here is local-first: the object is stored in Hive and this app
/// never uploads it. [amount] is stored in [currency] exactly as the vendor
/// charges it, and normalised only when aggregating.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.vendor,
    required this.monogram,
    required this.brandColor,
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.guilt,
    required this.category,
    required this.startDate,
    required this.nextBillingDate,
    required this.cancelUrl,
    this.remindersEnabled = true,
    this.presetId,
  });

  final String id;
  final String name;
  final String vendor;

  /// 1–2 character monogram shown in the brand tile.
  final String monogram;

  /// ARGB int, e.g. `0xFF10A37F`.
  final int brandColor;

  /// The real charge for one billing period.
  final double amount;

  final CurrencyCode currency;
  final BillingCycle cycle;
  final UsageGuilt guilt;

  /// `ai`, `dev`, `streaming`, `design`, … Used by the roast engine.
  final String category;

  final DateTime startDate;
  final DateTime nextBillingDate;
  final String cancelUrl;
  final bool remindersEnabled;

  /// Links back to the CDN preset this row was created from, when it was.
  final String? presetId;

  bool get isGhost => guilt.isGhost;

  bool get isAiTool => category == 'ai' || category == 'dev';

  bool get isStreaming => category == 'streaming';

  /// Amount per month, expressed in [target].
  ///
  /// Conversion is single-pass and stateless: INR is the base unit because the
  /// product is rupee-denominated at launch.
  double monthlyIn(CurrencyCode target, double inrPerUsd) {
    final inr = amount * (currency == CurrencyCode.usd ? inrPerUsd : 1);
    final monthlyInr = inr * cycle.monthlyFactor;
    return target == CurrencyCode.inr ? monthlyInr : monthlyInr / inrPerUsd;
  }

  double yearlyIn(CurrencyCode target, double inrPerUsd) =>
      monthlyIn(target, inrPerUsd) * 12;

  /// Total charged between [startDate] and [asOf], prorated to the month.
  ///
  /// Prorating is deliberate: a subscription started 2 weeks ago has burned
  /// half a month, and showing a whole month would overstate the number the
  /// whole product is about.
  double lifetimeIn(
    CurrencyCode target,
    double inrPerUsd, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    if (now.isBefore(startDate)) return 0;
    final days = now.difference(startDate).inHours / 24.0;
    final months = days / 30.4375;
    return monthlyIn(target, inrPerUsd) * months;
  }

  /// How long until the next charge. Negative means overdue.
  Duration timeUntilRenewal({DateTime? now}) =>
      nextBillingDate.difference(now ?? DateTime.now());

  bool renewsWithin(Duration window, {DateTime? now}) {
    final left = timeUntilRenewal(now: now);
    return !left.isNegative && left <= window;
  }

  /// The next charge after [from], walking the billing cycle forward.
  DateTime followingCharge(DateTime from) => cycle.advance(from);

  Subscription copyWith({
    String? name,
    String? vendor,
    String? monogram,
    int? brandColor,
    double? amount,
    CurrencyCode? currency,
    BillingCycle? cycle,
    UsageGuilt? guilt,
    String? category,
    DateTime? startDate,
    DateTime? nextBillingDate,
    String? cancelUrl,
    bool? remindersEnabled,
    String? presetId,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      vendor: vendor ?? this.vendor,
      monogram: monogram ?? this.monogram,
      brandColor: brandColor ?? this.brandColor,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      cycle: cycle ?? this.cycle,
      guilt: guilt ?? this.guilt,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      cancelUrl: cancelUrl ?? this.cancelUrl,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      presetId: presetId ?? this.presetId,
    );
  }
}

/// Aggregate figures the dashboard and the receipt both read.
///
/// Computed once from a list so the hero number, the split bar, the callout
/// and the shared receipt can never disagree — the bug that shipped in v1.
class BurnSummary {
  const BurnSummary({
    required this.monthly,
    required this.ghostMonthly,
    required this.count,
    required this.ghostCount,
    required this.currency,
    required this.inrPerUsd,
    required this.dueSoon,
    required this.aiMonthly,
    required this.streamingMonthly,
  });

  final double monthly;
  final double ghostMonthly;
  final int count;
  final int ghostCount;
  final CurrencyCode currency;
  final double inrPerUsd;
  final List<Subscription> dueSoon;
  final double aiMonthly;
  final double streamingMonthly;

  double get yearly => monthly * 12;

  double get ghostYearly => ghostMonthly * 12;

  /// 0..1. Returns 0 when there is nothing tracked, never NaN.
  double get ghostShare => monthly <= 0 ? 0 : ghostMonthly / monthly;

  double get activeMonthly => monthly - ghostMonthly;

  double get activeShare => monthly <= 0 ? 0 : 1 - ghostShare;

  String get monthlyLabel => currency.format(monthly);

  String get yearlyLabel => currency.format(yearly);

  static BurnSummary from(
    List<Subscription> subs, {
    required CurrencyCode currency,
    required double inrPerUsd,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    var monthly = 0.0;
    var ghost = 0.0;
    var ai = 0.0;
    var streaming = 0.0;
    var ghostCount = 0;

    for (final s in subs) {
      final m = s.monthlyIn(currency, inrPerUsd);
      monthly += m;
      if (s.isGhost) {
        ghost += m;
        ghostCount++;
      }
      if (s.isAiTool) ai += m;
      if (s.isStreaming) streaming += m;
    }

    final due = subs
        .where((s) => s.renewsWithin(
              const Duration(hours: SbWindow.renewingHours),
              now: clock,
            ))
        .toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));

    return BurnSummary(
      monthly: monthly,
      ghostMonthly: ghost,
      count: subs.length,
      ghostCount: ghostCount,
      currency: currency,
      inrPerUsd: inrPerUsd,
      dueSoon: due,
      aiMonthly: ai,
      streamingMonthly: streaming,
    );
  }
}

/// Window constants kept out of the token file so they can be tuned in one
/// place without touching the visual system.
abstract final class SbWindow {
  static const renewingHours = 48;
  static const reminderHours = 48;
  static const finalNoticeHours = 24;
}
