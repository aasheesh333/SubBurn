import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subburn/subburn.dart';

/// Loads the real bundled fonts so the receipt renders as it ships, not with
/// the test environment's 1 px Ahem placeholder.
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

Widget _app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: SbColors.bg,
        body: Center(child: child),
      ),
    );

Subscription _sub({
  String id = 'sub_test',
  String name = 'ChatGPT Plus',
  double amount = 1660,
  CurrencyCode currency = CurrencyCode.inr,
  BillingCycle cycle = BillingCycle.monthly,
  UsageGuilt guilt = UsageGuilt.dailyDriver,
  String category = 'ai',
  DateTime? start,
  DateTime? next,
}) {
  final now = DateTime(2026, 11, 9, 12);
  return Subscription(
    id: id,
    name: name,
    vendor: '[OI]',
    monogram: 'AI',
    brandColor: 0xFF10A37F,
    amount: amount,
    currency: currency,
    cycle: cycle,
    guilt: guilt,
    category: category,
    startDate: start ?? DateTime(2025, 10, 9),
    nextBillingDate: next ?? now.add(const Duration(hours: 14)),
    cancelUrl: 'https://example.com/cancel',
  );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('money formatting', () {
    test('uses Indian digit grouping', () {
      expect(formatInr(4850), '₹4,850');
      expect(formatInr(58200), '₹58,200');
      expect(formatInr(124000), '₹1,24,000');
      expect(CurrencyCode.inr.format(124000), '₹1,24,000');
      expect(CurrencyCode.usd.format(4850), r'$4,850');
      expect(CurrencyCode.inr.format(12345678), '₹1,23,45,678');
    });

    test('preserves decimals instead of rounding money away', () {
      // A $9.99 subscription was stored correctly and displayed as $10 on every
      // screen, which is a wrong number in a money app.
      expect(CurrencyCode.usd.format(9.99), r'$9.99');
      expect(CurrencyCode.usd.format(12.5), r'$12.50');
      expect(CurrencyCode.usd.format(1660), r'$1,660');
      expect(CurrencyCode.inr.format(0.5), '₹0.50');
      expect(CurrencyCode.usd.format(1234.567), r'$1,234.57');
    });

    test('parses typed prices', () {
      expect(parseAmount('1,660'), 1660);
      expect(parseAmount('₹ 415'), 415);
      expect(parseAmount('20.50'), 20.5);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount(''), isNull);
    });

    test('formats countdowns', () {
      expect(
          formatCountdown(const Duration(hours: 14, minutes: 22)), '14h 22m');
      expect(formatCountdown(const Duration(days: 1, hours: 11)), '1d 11h');
      expect(formatCountdown(const Duration(minutes: 7)), '7m');
      expect(formatCountdown(const Duration(minutes: -1)), 'now');
    });
  });

  group('billing normalisation', () {
    test('monthly is identity', () {
      expect(_sub(amount: 1660).monthlyIn(CurrencyCode.inr, 83), 1660);
    });

    test('yearly divides by 12 using the real annual charge', () {
      final yearly = _sub(amount: 16600, cycle: BillingCycle.yearly);
      expect(yearly.monthlyIn(CurrencyCode.inr, 83), closeTo(1383.33, 0.01));
      expect(yearly.yearlyIn(CurrencyCode.inr, 83), closeTo(16600, 0.01));
    });

    test('weekly multiplies by 52/12', () {
      final weekly = _sub(amount: 100, cycle: BillingCycle.weekly);
      expect(weekly.monthlyIn(CurrencyCode.inr, 83), closeTo(433.33, 0.01));
    });

    test('converts USD at the supplied rate', () {
      final usd = _sub(amount: 20, currency: CurrencyCode.usd);
      expect(usd.monthlyIn(CurrencyCode.inr, 83), 1660);
      expect(usd.monthlyIn(CurrencyCode.usd, 83), 20);
    });

    test('lifetime spend is prorated, never overstated', () {
      final sub =
          _sub(start: DateTime.now().subtract(const Duration(days: 30)));
      final lifetime = sub.lifetimeIn(CurrencyCode.inr, 83);
      expect(lifetime, closeTo(1660, 40));
    });
  });

  group('burn summary', () {
    final subs = [
      _sub(id: 'a', amount: 1660, guilt: UsageGuilt.dailyDriver),
      _sub(id: 'b', amount: 1660, guilt: UsageGuilt.dailyDriver),
      _sub(id: 'c', amount: 830, guilt: UsageGuilt.barelyTouch),
      _sub(id: 'd', amount: 415, guilt: UsageGuilt.barelyTouch),
      _sub(id: 'e', amount: 285, guilt: UsageGuilt.dailyDriver),
    ];

    test('ghost share is 25.7 %, matching the rupee figure', () {
      final summary = BurnSummary.from(
        subs,
        currency: CurrencyCode.inr,
        inrPerUsd: 83,
        now: DateTime(2026, 11, 9, 12),
      );
      expect(summary.monthly, 4850);
      expect(summary.ghostMonthly, 1245);
      expect(summary.ghostShare * 100, closeTo(25.67, 0.01));
      expect(summary.yearly, 58200);
      expect(summary.ghostYearly, 14940);
      expect(summary.count, 5);
      expect(summary.ghostCount, 2);
      // The percentage is not rounded while the money is exact: 26 % of 4850
      // would be 1261, which is how v1 shipped an inconsistent receipt.
      expect(summary.ghostShare * summary.monthly, closeTo(1245, 0.01));
    });

    test('a zero ledger never produces NaN', () {
      final empty = BurnSummary.from(
        const [],
        currency: CurrencyCode.inr,
        inrPerUsd: 83,
      );
      expect(empty.ghostShare, 0);
      expect(empty.activeShare, 0);
      expect(empty.monthlyLabel, '₹0');
    });

    test('renewals inside the 48 h window are surfaced, in order', () {
      final summary = BurnSummary.from(
        [
          _sub(id: 'soon', next: DateTime.now().add(const Duration(hours: 5))),
          _sub(id: 'later', next: DateTime.now().add(const Duration(days: 9))),
        ],
        currency: CurrencyCode.inr,
        inrPerUsd: 83,
      );
      expect(summary.dueSoon.map((s) => s.id), ['soon']);
      expect(SbWindow.renewingHours, 48);
    });
  });

  group('roast engine', () {
    const engine = RoastEngine();

    RoastInput input(double yearly) => RoastInput(
          yearlyInr: yearly,
          monthlyInr: yearly / 12,
          ghostShare: 0.257,
          aiShare: 0.86,
          toolCount: 5,
          currency: CurrencyCode.inr,
        );

    test('is deterministic for the same ledger', () {
      final a = engine.generate(input(58200));
      final b = engine.generate(input(58200));
      expect(a.tier, b.tier);
      expect(a.line, b.line);
      expect(a.templateId, b.templateId);
      expect(a.verdict, b.verdict);
    });

    test('picks the Silicon Valley Paypig band at ₹58,200', () {
      final roast = engine.generate(input(58200));
      expect(roast.band, RoastBand.siliconValleyPaypig);
      expect(roast.tier, 'SILICON VALLEY PAYPIG');
      expect(roast.intensity, 4);
      expect(roast.line, isNotEmpty);
      expect(roast.verdict, isNotEmpty);
    });

    test('never leaks template placeholders', () {
      for (final yearly in [0.0, 4200.0, 12000.0, 32000.0, 58200.0, 250000.0]) {
        final roast = engine.generate(input(yearly));
        expect(roast.line, isNot(contains('{')));
        expect(roast.verdict, isNot(contains('{')));
        expect(roast.line, isNotEmpty);
      }
    });

    test('bands escalate with burn', () {
      expect(engine.generate(input(1000)).band, RoastBand.freeTierRefugee);
      expect(engine.generate(input(10000)).band, RoastBand.subscriptionCurious);
      expect(engine.generate(input(20000)).band, RoastBand.subscriptionHoarder);
      expect(engine.generate(input(40000)).band, RoastBand.siliconValleyPaypig);
      expect(engine.generate(input(90000)).band, RoastBand.aiIndustryPatron);
    });
  });

  group('receipt export', () {
    const lines = [
      ReceiptLine(name: 'ChatGPT Plus', monthly: 1660),
      ReceiptLine(name: 'Claude Pro', monthly: 1660),
      ReceiptLine(name: 'Cursor Pro', monthly: 830),
      ReceiptLine(name: 'GitHub Copilot', monthly: 415),
      ReceiptLine(name: 'Midjourney', monthly: 285),
    ];

    testWidgets('fits its 360×640 export box', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          const SubBurnReceiptCard(
            lines: lines,
            roastTier: 'Silicon Valley Paypig',
            roastLine:
                'Paying ₹58,200/yr to generate memes and fix center divs.',
            ghostShare: 0.2567,
            ghostAmount: 14940,
            receiptNo: 'No. 00412',
            roastIntensity: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SubBurnReceiptCard)),
        const Size(360, 640),
      );

      final card = tester.getRect(find.byType(SubBurnReceiptCard));
      for (final element in find.byType(Text).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(card.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(card.right + 0.5));
      }
    });

    testWidgets('renders 25.7 %, not a rounded 26 %', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          const SubBurnReceiptCard(
            lines: lines,
            roastTier: 'Silicon Valley Paypig',
            roastLine: 'Paying ₹58,200/yr to generate memes.',
            ghostShare: 0.2567,
            ghostAmount: 14940,
            receiptNo: 'No. 00412',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('25.7%'), findsOneWidget);
    });

    testWidgets('exports a 1080×1920 PNG from one boundary', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: key,
            child: const SubBurnReceiptCard(
              lines: lines,
              roastTier: 'Silicon Valley Paypig',
              roastLine:
                  'Paying ₹58,200/yr to generate memes and fix center divs.',
              ghostShare: 0.2567,
              ghostAmount: 14940,
              receiptNo: 'No. 00412',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image =
          await tester.runAsync(() => boundary.toImage(pixelRatio: 3));
      expect(image!.width, 1080);
      expect(image.height, 1920);
      image.dispose();
    });
  });

  group('local database', () {
    late Directory dir;
    late SubscriptionRepository repo;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('subburn_hive_');
      repo = await SubscriptionRepository.openTest(dir.path);
    });

    setUp(() async {
      await repo.clear();
    });

    tearDownAll(() async {
      await repo.close();
      await dir.delete(recursive: true);
    });

    test('round-trips every field through the Hive adapter', () async {
      final sub = _sub(
        id: 'roundtrip',
        amount: 830,
        cycle: BillingCycle.yearly,
        guilt: UsageGuilt.barelyTouch,
        category: 'dev',
      );
      await repo.put(sub);

      final restored = repo.byId('roundtrip')!;
      expect(restored.name, sub.name);
      expect(restored.amount, 830);
      expect(restored.cycle, BillingCycle.yearly);
      expect(restored.guilt, UsageGuilt.barelyTouch);
      expect(restored.category, 'dev');
      expect(restored.category, 'dev');
      expect(
        restored.nextBillingDate.millisecondsSinceEpoch,
        sub.nextBillingDate.millisecondsSinceEpoch,
      );
    });

    test('deletes and reports length', () async {
      final sub = _sub(id: 'temp');
      await repo.put(sub);
      expect(repo.length, 1);
      await repo.delete('temp');
      expect(repo.length, 0);
      expect(repo.isEmpty, isTrue);
    });

    test('settings default to INR and persist changes', () async {
      expect(repo.settings.displayCurrency, CurrencyCode.inr);
      await repo.saveSettings(
        repo.settings.copyWith(
          displayCurrency: CurrencyCode.usd,
          installId: 'inst_test',
        ),
      );
      expect(repo.settings.displayCurrency, CurrencyCode.usd);
      expect(repo.settings.installId, 'inst_test');
    });
  });

  group('catalogue', () {
    test('bundled presets parse, are unique and have cancel links', () {
      final raw = File('assets/json/presets_v1.json').readAsStringSync();
      final catalogue = PresetCatalogue.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fromCache: true,
      );

      expect(catalogue.tools.length, greaterThanOrEqualTo(100));
      expect(catalogue.tools.map((t) => t.id).toSet().length,
          catalogue.tools.length);
      for (final tool in catalogue.tools) {
        expect(tool.cancelUrl.startsWith('https://'), isTrue,
            reason: '${tool.name} has no cancel URL');
        expect(tool.name, isNotEmpty);
        expect(tool.defaultPrice, greaterThanOrEqualTo(0));
      }
      expect(catalogue.popular.length, greaterThan(0));
    });

    test('search is case-insensitive and covers vendor and category', () {
      final raw = File('assets/json/presets_v1.json').readAsStringSync();
      final catalogue = PresetCatalogue.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fromCache: true,
      );
      expect(catalogue.search('chatgpt').first.name, 'ChatGPT Plus');
      expect(catalogue.search('netflix').first.name, 'Netflix Standard');
      expect(catalogue.search('streaming'), isNotEmpty);
      expect(catalogue.search('zzzz-nothing'), isEmpty);
    });
  });

  group('widgets', () {
    testWidgets('segment pills expose selection to semantics', (tester) async {
      var value = 'Monthly';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 361,
              child: SegmentPills<String>(
                values: const ['Monthly', 'Yearly'],
                selected: value,
                onChanged: (v) => setState(() => value = v),
                labelOf: (v) => v,
                trailingOf: (v) => v == 'Yearly' ? '−17%' : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(value, 'Yearly');
    });

    testWidgets('hero card renders the exact ghost share', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 361,
            child: BurnHeroCard(
              monthlyTotal: 4850,
              activeAmount: 3605,
              ghostAmount: 1245,
              toolCount: 5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('25.7%'), findsOneWidget);
      expect(find.textContaining('74.3%'), findsOneWidget);
    });

    testWidgets('primary button keeps a 44 px tap target', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 361,
            child:
                PrimaryButton(label: 'Add to burn tracker', onPressed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PrimaryButton)).height,
        greaterThanOrEqualTo(SbSize.minTapTarget),
      );
    });
  });
}
