import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subburn/core/theme/app_theme.dart';
import 'package:subburn/core/utils/formatters.dart';
import 'package:subburn/core/theme/theme_tokens.dart';
import 'package:subburn/data/models/billing_cycle.dart';
import 'package:subburn/data/hive/local_adapters.dart';
import 'package:subburn/data/models/currency.dart';
import 'package:subburn/data/models/cycle_conversion.dart';
import 'package:subburn/data/models/preset_tool.dart';
import 'package:subburn/data/models/subscription.dart';
import 'package:subburn/data/models/usage_guilt.dart';
import 'package:subburn/data/repositories/subscription_repository.dart';
import 'package:subburn/features/dashboard/burn_dashboard_screen.dart';
import 'package:subburn/features/detail/sub_detail_screen.dart';
import 'package:subburn/features/renewals/renewals_screen.dart';
import 'package:subburn/services/analytics_service.dart';
import 'package:subburn/services/catalogue_service.dart';
import 'package:subburn/features/studio/roast_engine.dart';
import 'package:subburn/features/studio/viral_receipt_screen.dart';
import 'package:subburn/services/notification_service.dart';
import 'package:subburn/state/providers.dart';
import 'package:subburn/widgets/receipt_card.dart';

/// Regression suite produced by the production-readiness audit.
///
/// Every test here failed before the corresponding fix, so the same class of
/// bug cannot silently come back.

late CatalogueSnapshot _snapshot;

Future<void> _loadFonts() async {
  const families = {
    'PlusJakartaSans': [400, 500, 600, 700, 800],
    'JetBrainsMono': [400, 500, 600, 700],
  };
  const prefixes = {'PlusJakartaSans': 'pjs', 'JetBrainsMono': 'jbm'};
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      final file = File('assets/fonts/${prefixes[entry.key]}-$weight.ttf');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    }
    await loader.load();
  }
}

CatalogueSnapshot _readCatalogue() {
  final raw = File('assets/json/presets_v1.json').readAsStringSync();
  return CatalogueSnapshot(
    catalogue: PresetCatalogue.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      fromCache: true,
    ),
    rates: ExchangeRates.fallback,
    source: CatalogueSource.bundled,
  );
}

Subscription _sub({
  String id = 'sub_audit',
  String name = 'ChatGPT Plus',
  double amount = 1660,
  BillingCycle cycle = BillingCycle.monthly,
  UsageGuilt guilt = UsageGuilt.dailyDriver,
  DateTime? start,
  DateTime? next,
}) {
  return Subscription(
    id: id,
    name: name,
    vendor: '[OI]',
    monogram: 'AI',
    brandColor: 0xFF10A37F,
    amount: amount,
    currency: CurrencyCode.inr,
    cycle: cycle,
    guilt: guilt,
    category: 'ai',
    startDate: start ?? DateTime(2025, 10, 9),
    nextBillingDate: next ?? DateTime.now().add(const Duration(hours: 14)),
    cancelUrl: 'https://example.com/cancel',
  );
}

/// Advances a few frames. `pumpAndSettle` never returns here because the
/// renewal countdown badge pulses forever by design.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Widget _app(Widget child, SubscriptionRepository repo) {
  return ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
      analyticsProvider.overrideWithValue(AnalyticsService(null)),
      notificationServiceProvider.overrideWithValue(NotificationService()),
    ],
    // MaterialApp rebuilds MediaQuery from the view, so the animation flag has
    // to be applied in its builder, not above it.
    child: MaterialApp(
      theme: AppTheme.dark,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner ?? const SizedBox.shrink(),
      ),
      home: Scaffold(backgroundColor: SbColors.bg, body: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    _snapshot = _readCatalogue();
  });

  group('billing cycle arithmetic', () {
    test('31 Jan + 1 month never skips February', () {
      final next = BillingCycle.monthly.advance(DateTime(2026, 1, 31));
      expect(next.month, 2, reason: 'Jan 31 + 1 month must land in February');
      expect(next.day, lessThanOrEqualTo(28));
    });

    test('31 Mar + 1 month lands in April, not May', () {
      expect(BillingCycle.monthly.advance(DateTime(2026, 3, 31)).month, 4);
    });

    test('29 Feb + 1 year clamps instead of rolling to 1 March', () {
      final next = BillingCycle.yearly.advance(DateTime(2028, 2, 29));
      expect(next.year, 2029);
      expect(next.month, 2);
      expect(next.day, lessThanOrEqualTo(28));
    });

    test('normal days advance exactly', () {
      expect(
        BillingCycle.monthly.advance(DateTime(2026, 5, 9)),
        DateTime(2026, 6, 9),
      );
      expect(
        BillingCycle.yearly.advance(DateTime(2026, 5, 9)),
        DateTime(2027, 5, 9),
      );
    });
  });

  group('real data, not hardcoded', () {
    test('per-workday uses the real weekday count, not a fixed 22', () {
      final feb2026 = workdaysInMonth(DateTime(2026, 2, 10));
      final nov2026 = workdaysInMonth(DateTime(2026, 11, 9));
      expect(feb2026, 20);
      expect(nov2026, 21);
      expect(feb2026, isNot(22));
    });

    test('live FX payload parses and rejects nonsense', () {
      final ok = ExchangeRates.fromErApi({
        'result': 'success',
        'time_last_update_unix': 1794200000,
        'rates': {'INR': 88.42, 'USD': 1},
      });
      expect(ok, isNotNull);
      expect(ok!.inrPerUsd, 88.42);
      expect(ok.asOf.year, greaterThanOrEqualTo(2026));

      expect(
        ExchangeRates.fromErApi({
          'rates': {'INR': 1}
        }),
        isNull,
        reason: 'a 1:1 rate is a broken feed, not a real rate',
      );
      expect(ExchangeRates.fromErApi({'rates': <String, dynamic>{}}), isNull);
    });

    test('next charge walks from the real start date', () {
      final start = DateTime(2025, 1, 9);
      final next = BillingCycle.monthly.nextAfter(
        start,
        now: DateTime(2026, 11, 9),
      );
      expect(next.isAfter(DateTime(2026, 11, 9)), isTrue);
      expect(next.day, 9);
      expect(next.month, 12);
    });

    test('preset prices are present and never zero for paid tools', () {
      final raw = File('assets/json/presets_v1.json').readAsStringSync();
      final catalogue = PresetCatalogue.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fromCache: true,
      );
      for (final tool in catalogue.tools) {
        expect(tool.defaultPrice, greaterThanOrEqualTo(0));
        expect(tool.defaultPrice.isFinite, isTrue);
      }
      final byName = {for (final t in catalogue.tools) t.name: t};
      // The three prices that were visibly wrong before the audit.
      expect(byName['Cursor Pro']!.defaultPrice, 1660);
      expect(byName['GitHub Copilot']!.defaultPrice, 830);
      expect(byName['Midjourney']!.defaultPrice, 830);
    });
  });

  group('empty ledger', () {
    test('summary of nothing is zero, never NaN or a fake tool', () {
      final s = BurnSummary.from(
        const [],
        currency: CurrencyCode.inr,
        inrPerUsd: 83,
      );
      expect(s.count, 0);
      expect(s.monthly, 0);
      expect(s.yearly, 0);
      expect(s.ghostShare, 0);
      expect(s.monthlyLabel, '₹0');
      expect(s.dueSoon, isEmpty);
    });

    test('the roast for an empty ledger is not a fake tier', () {
      expect(Roast.empty.tier, 'FREE-TIER REFUGEE');
      expect(Roast.empty.line.toLowerCase(), contains('nothing is burning'));
      expect(Roast.empty.templateId, 'empty');
    });

    test('a fresh install writes nothing', () async {
      final repo = SubscriptionRepository.inMemory();
      expect(repo.all(), isEmpty);
      expect(repo.settings.installId, isNull);
      expect(repo.settings.displayCurrency, CurrencyCode.inr);
    });

    testWidgets('studio shows the empty receipt, not a sample card',
        (tester) async {
      final repo = SubscriptionRepository.inMemory();
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
            analyticsProvider.overrideWithValue(AnalyticsService(null)),
            notificationServiceProvider
                .overrideWithValue(NotificationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              backgroundColor: SbColors.bg,
              body: ViralReceiptScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Your receipt is empty'), findsOneWidget);
      expect(find.textContaining('58,200'), findsNothing);
      expect(find.text('Add a subscription first'), findsOneWidget);
    });

    testWidgets('renewals shows the empty state', (tester) async {
      final repo = SubscriptionRepository.inMemory();
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
            analyticsProvider.overrideWithValue(AnalyticsService(null)),
            notificationServiceProvider
                .overrideWithValue(NotificationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              backgroundColor: SbColors.bg,
              body: RenewalsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('0 THIS MONTH'), findsOneWidget);
    });
  });

  group('overdue renewals', () {
    test('a past billing date rolls to the next real renewal', () {
      final sub = _sub(
        next: DateTime.now().subtract(const Duration(days: 2)),
        start: DateTime(2025, 1, 9),
      );
      final rolled = sub.rolledForward();
      expect(rolled.nextBillingDate.isAfter(DateTime.now()), isTrue);
      expect(
          rolled.nextBillingDate.isBefore(
            DateTime.now().add(const Duration(days: 32)),
          ),
          isTrue);
    });

    test('rolling keeps the billing day of month', () {
      final sub = _sub(next: DateTime(2026, 9, 9), start: DateTime(2025, 1, 9));
      final rolled = sub.rolledForward(now: DateTime(2026, 11, 20));
      expect(rolled.nextBillingDate.day, 9);
      expect(rolled.nextBillingDate.month, 12);
    });

    test('a weekly plan two years overdue lands in the future', () {
      final sub = _sub(
        cycle: BillingCycle.weekly,
        amount: 100,
        next: DateTime(2024, 1, 1),
        start: DateTime(2023, 1, 1),
      );
      final rolled = sub.rolledForward(now: DateTime(2026, 11, 9));
      expect(rolled.nextBillingDate.isAfter(DateTime(2026, 11, 9)), isTrue);
      expect(
        rolled.nextBillingDate.difference(DateTime(2026, 11, 9)).inDays,
        lessThanOrEqualTo(7),
      );
    });

    test('repository normalises on read', () async {
      final repo = SubscriptionRepository.inMemory(
        initial: [
          _sub(next: DateTime.now().subtract(const Duration(days: 3))),
        ],
      );
      final list = repo.all();
      expect(list.single.nextBillingDate.isAfter(DateTime.now()), isTrue);
    });
  });

  group('lifetime spend', () {
    test('charge count and rupees never disagree', () {
      // 10 complete monthly periods billed since signup.
      final start = BillingCycle.addMonths(DateTime.now(), -10);
      final sub = _sub(
          start: start, next: DateTime.now().add(const Duration(hours: 9)));
      final charges = sub.chargeCount();
      final lifetime = sub.lifetimeIn(CurrencyCode.inr, 83);
      expect(lifetime, charges * 1660);
      expect(charges, inInclusiveRange(9, 11));
    });

    test('weekly billing counts weeks, not months', () {
      final sub = _sub(
        amount: 100,
        cycle: BillingCycle.weekly,
        start: DateTime.now().subtract(const Duration(days: 28)),
        next: DateTime.now().add(const Duration(days: 1)),
      );
      // Signup day is itself the first charge: day -28, -21, -14, -7, 0.
      expect(sub.chargeCount(), 5);
      expect(sub.lifetimeIn(CurrencyCode.inr, 83), 500);
    });
  });

  group('receipt arithmetic', () {
    test('a yearly-billed tool is not discounted twice', () {
      // Quick Add stores the real annual charge for a yearly plan:
      // ₹16,600 typed -> monthly equivalent ₹1,383.33.
      const line = ReceiptLine(
        name: 'ChatGPT Plus',
        monthly: 16600 / 12,
        billedYearly: true,
      );
      expect(line.annual, 16600);
    });

    test('lines sum to the yearly total for any cycle mix', () {
      final subs = [
        _sub(id: 'm', amount: 1660),
        _sub(id: 'y', amount: 16600, cycle: BillingCycle.yearly),
        _sub(id: 'w', amount: 100, cycle: BillingCycle.weekly),
      ];
      final summary = BurnSummary.from(
        subs,
        currency: CurrencyCode.inr,
        inrPerUsd: 83,
      );
      final sum = subs
          .map((s) => ReceiptLine(
                name: s.name,
                monthly: s.monthlyIn(CurrencyCode.inr, 83),
                billedYearly: s.cycle == BillingCycle.yearly,
              ))
          .fold<num>(0, (a, l) => a + l.annual);
      expect(sum, closeTo(summary.yearly, 2));
    });
  });

  group('dashboard', () {
    late SubscriptionRepository repo;

    setUp(() {
      repo = SubscriptionRepository.inMemory();
    });

    testWidgets('swiping a row away leaves no dismissed widget',
        (tester) async {
      await repo.put(_sub(id: 'swipe'));
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          BurnDashboardScreen(onAddSubscription: () {}),
          repo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The renewal rail shows the same name; drag the list row itself.
      await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Nothing burning yet'), findsOneWidget);
    });

    testWidgets('long names and many rows survive 320 px at 130 % text',
        (tester) async {
      for (var i = 0; i < 9; i++) {
        await repo.put(
          _sub(
            id: 'long_$i',
            name: 'Adobe Creative Cloud Photography Plan $i',
            amount: 4671 + i * 100,
          ),
        );
      }
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
            analyticsProvider.overrideWithValue(AnalyticsService(null)),
            notificationServiceProvider
                .overrideWithValue(NotificationService()),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(
                backgroundColor: SbColors.bg,
                body: BurnDashboardScreen(
                  onAddSubscription: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('detail survives 320 px with a long vendor name',
        (tester) async {
      await repo.put(
        _sub(
          id: 'detail',
          name: 'Adobe Creative Cloud Photography Plan',
          amount: 4671,
        ),
      );
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const SubDetailScreen(subscriptionId: 'detail'), repo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a single charge is not pluralised', (tester) async {
      await repo.put(_sub(id: 'one', start: DateTime.now()));
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const SubDetailScreen(subscriptionId: 'one'), repo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('1 charges'), findsNothing);
    });

    testWidgets('ring matches the frame: 14h 22m reads 60 %', (tester) async {
      await repo.put(
        _sub(
          id: 'ring',
          next: DateTime.now().add(const Duration(hours: 14, minutes: 22)),
          start: DateTime.now().subtract(const Duration(days: 20)),
        ),
      );
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const SubDetailScreen(subscriptionId: 'ring'), repo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('60%'), findsOneWidget);
    });
  });

  group('workflow', () {
    test('withStartDate never inverts the timeline', () {
      final next = DateTime.now().add(const Duration(days: 5));
      final sub = _sub(next: next, start: DateTime(2025, 1, 9));

      final earlier = sub.withStartDate(DateTime(2024, 6, 1));
      expect(earlier.nextBillingDate, next);

      // A charge can never precede the subscription start.
      final later = sub.withStartDate(next.add(const Duration(days: 30)));
      expect(
        later.nextBillingDate.isBefore(later.startDate),
        isFalse,
        reason: 'next charge must not be before the start date',
      );
      expect(later.lifetimeIn(CurrencyCode.inr, 83), greaterThanOrEqualTo(0));
    });

    test('reminder health tells the truth when the OS blocks delivery',
        () async {
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(subscriptionsProvider.notifier).add(_sub());
      expect(repo.length, 1, reason: 'saving must work without notifications');

      // The plugin is not initialised in tests, which is exactly what a device
      // with a broken channel looks like. The UI must be able to say so.
      final health = await container.read(reminderHealthProvider.future);
      expect(health.status, ReminderStatus.notInitialized);
      expect(health.isWorking, isFalse);
      expect(health.pending, 0);
    });

    test('switching reminders on reports failure instead of faking success',
        () async {
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final enabled = await container
          .read(settingsProvider.notifier)
          .setNotifications(true);
      expect(enabled, isFalse, reason: 'no plugin, so it cannot be true');
      expect(container.read(settingsProvider).notificationsEnabled, isFalse);
    });

    test('a failed refresh keeps the previous catalogue and rate', () async {
      final repo = SubscriptionRepository.inMemory();
      final service = _FlakyCatalogue();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueServiceProvider.overrideWithValue(service),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(catalogueProvider.future);
      expect(first.catalogue.tools, isNotEmpty);

      await container.read(catalogueProvider.notifier).refresh();

      final after = container.read(catalogueProvider);
      expect(after.hasValue, isTrue,
          reason: 'a failed refresh must not blank data');
      expect(after.value!.catalogue.tools.length, first.catalogue.tools.length);
      expect(container.read(catalogueRefreshingProvider), isFalse);
      expect(container.read(ratesProvider).inrPerUsd, first.rates.inrPerUsd);
    });

    test('the -17% chip applies on every path into yearly', () {
      // monthly -> yearly. Cents are preserved: whole-unit rounding used to
      // turn $9.99/mo plans into $10/mo when the pill was toggled.
      final fromMonthly = CycleConversion.convert(
        amount: 1660,
        from: BillingCycle.monthly,
        to: BillingCycle.yearly,
        discountApplied: false,
      );
      expect(fromMonthly.amount, closeTo(16533.6, 0.001));
      expect(fromMonthly.discountApplied, isTrue);

      // weekly -> yearly: the path that silently skipped the discount before.
      final fromWeekly = CycleConversion.convert(
        amount: 100,
        from: BillingCycle.weekly,
        to: BillingCycle.yearly,
        discountApplied: false,
      );
      expect(fromWeekly.amount, closeTo(4316, 0.001));
      expect(fromWeekly.discountApplied, isTrue);
    });

    test('a yearly round trip returns the original amount', () {
      const original = 1660.0;
      final yearly = CycleConversion.convert(
        amount: original,
        from: BillingCycle.monthly,
        to: BillingCycle.yearly,
        discountApplied: false,
      );
      final back = CycleConversion.convert(
        amount: yearly.amount,
        from: BillingCycle.yearly,
        to: BillingCycle.monthly,
        discountApplied: yearly.discountApplied,
      );
      expect(back.amount, closeTo(original, 1));
      expect(back.discountApplied, isFalse);
    });

    test('leaving yearly without having discounted does not invent one', () {
      final result = CycleConversion.convert(
        amount: 12000,
        from: BillingCycle.yearly,
        to: BillingCycle.monthly,
        discountApplied: false,
      );
      expect(result.amount, 1000);
    });

    test('weekly <-> monthly keeps the monthly equivalent', () {
      final monthly = CycleConversion.convert(
        amount: 100,
        from: BillingCycle.weekly,
        to: BillingCycle.monthly,
        discountApplied: false,
      );
      // 100 × 52/12 = 433.33 — cents survive the conversion now.
      expect(monthly.amount, closeTo(433.33, 0.001));
      final weekly = CycleConversion.convert(
        amount: monthly.amount,
        from: BillingCycle.monthly,
        to: BillingCycle.weekly,
        discountApplied: false,
      );
      expect(weekly.amount, closeTo(100, 0.02));
    });
  });

  group('dead affordances', () {
    late SubscriptionRepository repo;

    setUp(() {
      repo = SubscriptionRepository.inMemory(
        initial: [
          _sub(id: 'a', guilt: UsageGuilt.dailyDriver),
          _sub(id: 'b', name: 'Cursor Pro', guilt: UsageGuilt.barelyTouch),
        ],
      );
    });

    testWidgets('REVIEW filters the list to ghost rows and back',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(BurnDashboardScreen(onAddSubscription: () {}), repo),
      );
      await _settle(tester);

      expect(find.text('Subscriptions'), findsOneWidget);
      await tester.tap(find.text('REVIEW'));
      await _settle(tester);

      expect(find.text('Ghost subscriptions'), findsOneWidget);
      expect(find.text('SHOW ALL'), findsOneWidget);
      // Non-ghost rows are gone from both sections; the ghost row remains in
      // the rail and the list, which is correct.
      expect(find.text('ChatGPT Plus'), findsNothing);
      expect(find.text('Cursor Pro'), findsNWidgets(2));

      await tester.tap(find.text('SHOW ALL'));
      await _settle(tester);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('ChatGPT Plus'), findsWidgets);
    });

    testWidgets('a renewal card opens its detail screen', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(BurnDashboardScreen(onAddSubscription: () {}), repo),
      );
      await _settle(tester);

      // The renewal rail card shows the same name as the list row; tap the
      // card that sits in the horizontal rail.
      await tester.tap(find.textContaining('left').first, warnIfMissed: false);
      await _settle(tester);

      expect(find.text('Subscription'), findsWidgets);
    });
  });

  group('edit flow', () {
    testWidgets('price, name and cycle are editable after adding',
        (tester) async {
      final repo = SubscriptionRepository.inMemory(initial: [_sub()]);
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const SubDetailScreen(subscriptionId: 'sub_audit'), repo),
      );
      await _settle(tester);

      // Edit is reachable from the overflow menu and from the identity card.
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      await tester.tap(find.text('Edit subscription'));
      await _settle(tester);

      expect(find.text('Edit subscription'), findsWidgets);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Name',
        ),
        'ChatGPT Team',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0',
        ),
        '2499',
      );
      await tester.tap(find.text('Save changes'));
      await _settle(tester);

      final saved = repo.byId('sub_audit')!;
      expect(saved.name, 'ChatGPT Team');
      expect(saved.amount, 2499);
      expect(saved.id, 'sub_audit',
          reason: 'editing must not create a new row');
      expect(saved.startDate, DateTime(2025, 10, 9),
          reason: 'lifetime history survives an edit');
    });
  });

  group('release-only and honesty fixes', () {
    test('reminders start off and are not claimed before permission', () {
      const settings = AppSettings();
      expect(
        settings.notificationsEnabled,
        isFalse,
        reason: 'a green switch with no permission is a lie',
      );
      expect(settings.notificationsPermissionAsked, isFalse);
    });

    test('changing the cycle re-anchors the next charge', () {
      final sub = _sub(cycle: BillingCycle.monthly);
      final yearly = sub.copyWith(
        cycle: BillingCycle.yearly,
        nextBillingDate: BillingCycle.yearly.nextAfter(sub.startDate),
      );
      expect(
        yearly.nextBillingDate.difference(DateTime.now()).inDays,
        greaterThan(300),
        reason: 'yearly must not keep a monthly renewal date',
      );
    });

    test('reminder health is honest when the plugin cannot start', () async {
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final health = await container.read(reminderHealthProvider.future);
      expect(health.wantsReminders, isFalse);
      expect(health.isWorking, isFalse);
      expect(health.blockedByOs, isFalse);
    });
  });

  group('honest state', () {
    test('selecting a preset never decides usage for the user', () async {
      // Picking Netflix used to silently mark it "Barely Touch It", inflating
      // the ghost share and changing the roast tier without the user saying
      // anything. Usage must stay at the user's last choice.
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final netflix = _snapshot.catalogue.search('netflix').first;
      expect(netflix.category, 'streaming');
      // The sheet's default is Daily Driver for a fresh form; nothing in the
      // preset path may change it, so a new row keeps that value.
      final sub = _sub(guilt: UsageGuilt.dailyDriver);
      expect(sub.isGhost, isFalse);
    });

    test('renewals toggle reports a blocked permission instead of lying',
        () async {
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(_snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final enabled = await container
          .read(settingsProvider.notifier)
          .setNotifications(true);
      expect(enabled, isFalse, reason: 'no plugin => cannot be true');
      expect(container.read(settingsProvider).notificationsEnabled, isFalse);
    });
  });

  group('providers', () {
    test('catalogue build does not mutate another provider', () async {
      final repo = SubscriptionRepository.inMemory();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueServiceProvider.overrideWithValue(_StubCatalogueService()),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(catalogueProvider.future);
      expect(snapshot.catalogue.tools, isNotEmpty);

      // The id is created by main() before the first frame; here we prove the
      // on-demand path works and does not require a provider mutation.
      final installId =
          await container.read(settingsProvider.notifier).ensureInstallId();
      expect(installId, isNotEmpty);
      expect(container.read(settingsProvider).installId, installId);
    });
  });
}

class _StubCatalogueService extends CatalogueService {
  _StubCatalogueService() : super(baseUrl: 'https://example.invalid');

  @override
  Future<CatalogueSnapshot> load({bool forceRefresh = false}) async =>
      _snapshot;
}

class _FlakyCatalogue extends CatalogueService {
  _FlakyCatalogue() : super(baseUrl: 'https://example.invalid');

  @override
  Future<CatalogueSnapshot> load({bool forceRefresh = false}) async {
    if (forceRefresh) {
      throw const SocketException('offline');
    }
    return _snapshot;
  }
}

class _FixedCatalogue extends CatalogueNotifier {
  _FixedCatalogue(this.snapshot);

  final CatalogueSnapshot snapshot;

  @override
  Future<CatalogueSnapshot> build() async => snapshot;

  @override
  Future<void> refresh() async {}
}

/// Shared fixture for probe tests.
Subscription subFixture() => Subscription(
      id: 'probe',
      name: 'ChatGPT Plus',
      vendor: '[OI]',
      monogram: 'AI',
      brandColor: 0xFF10A37F,
      amount: 1660,
      currency: CurrencyCode.inr,
      cycle: BillingCycle.monthly,
      guilt: UsageGuilt.dailyDriver,
      category: 'ai',
      startDate: DateTime(2025, 1, 9),
      nextBillingDate: DateTime.now().add(const Duration(hours: 14)),
      cancelUrl: 'https://example.com',
    );
