import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subburn/core/theme/app_theme.dart';
import 'package:subburn/data/models/billing_cycle.dart';
import 'package:subburn/data/models/currency.dart';
import 'package:subburn/data/models/preset_tool.dart';
import 'package:subburn/data/models/subscription.dart';
import 'package:subburn/data/models/usage_guilt.dart';
import 'package:subburn/data/repositories/subscription_repository.dart';
import 'package:subburn/features/controls/controls_screen.dart';
import 'package:subburn/features/dashboard/burn_dashboard_screen.dart';
import 'package:subburn/features/detail/edit_subscription_sheet.dart';
import 'package:subburn/features/detail/sub_detail_screen.dart';
import 'package:subburn/features/legal/legal_page.dart';
import 'package:subburn/features/quick_add/quick_add_sheet.dart';
import 'package:subburn/features/renewals/renewals_screen.dart';
import 'package:subburn/features/shell/home_shell.dart';
import 'package:subburn/features/studio/viral_receipt_screen.dart';
import 'package:subburn/services/analytics_service.dart';
import 'package:subburn/services/catalogue_service.dart';
import 'package:subburn/services/notification_service.dart';
import 'package:subburn/state/providers.dart';

/// Overflow sweep: every screen, three widths, deliberately hostile data.
///
/// Widget tests only fail loudly on overflow when the frame is pumped, so this
/// renders each screen at 320 / 393 / 412 dp with long names, large amounts,
/// every billing cycle and ghosts — the shapes that actually break layouts — and
/// asserts that no RenderFlex overflowed and nothing threw.
class _Catalogue extends CatalogueNotifier {
  _Catalogue(this.snapshot);

  final CatalogueSnapshot snapshot;

  @override
  Future<CatalogueSnapshot> build() async => snapshot;

  @override
  Future<void> refresh() async {}
}

Subscription _sub(int i, {BillingCycle? cycle}) {
  const names = [
    'Adobe Creative Cloud Photography Plan',
    'ChatGPT Plus',
    'Google Workspace Enterprise Plus',
    'Microsoft 365 Family',
    'Midjourney',
    'Notion',
  ];
  const vendors = [
    'ADOBE SYSTEMS INCORPORATED',
    'OPENAI',
    'GOOGLE CLOUD INDIA PRIVATE LIMITED',
    'MICROSOFT',
    'MIDJOURNEY',
    'NOTION LABS',
  ];
  return Subscription(
    id: 's$i',
    name: names[i % names.length],
    vendor: vendors[i % vendors.length],
    monogram: 'XY',
    brandColor: 0xFF10A37F,
    amount: [1660.0, 99999.0, 415.0, 12480.0, 285.0, 830.0][i % 6],
    currency: i.isEven ? CurrencyCode.inr : CurrencyCode.usd,
    cycle: cycle ?? BillingCycle.values[i % 3],
    guilt: i % 3 == 0 ? UsageGuilt.barelyTouch : UsageGuilt.dailyDriver,
    category: ['ai', 'dev', 'design', 'work', 'video', 'streaming'][i % 6],
    startDate: DateTime(2024, 3, 31),
    nextBillingDate: DateTime.now().add(Duration(hours: 3 + i * 11)),
    cancelUrl: 'https://example.com/cancel',
  );
}

void main() {
  late SubscriptionRepository repo;
  late CatalogueSnapshot snapshot;

  setUpAll(() async {
    snapshot = await _snapshotFromAssets();
  });

  setUp(() {
    repo = SubscriptionRepository.inMemory(
      initial: [for (var i = 0; i < 7; i++) _sub(i)],
    );
  });

  /// Captures the full error text so a failure names the exact widget and file
  /// instead of only "a RenderFlex overflowed".
  final captured = <String>[];

  Future<void> render(
    WidgetTester tester,
    Widget child,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    captured.clear();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      captured.add(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _Catalogue(snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.dark,
            // Screens are designed to live inside HomeShell's Scaffold; a
            // Switch/InkWell without a Material ancestor throws and cascades
            // into a bogus 99 000 px overflow.
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: child,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 90));
    }
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: 'threw while rendering ${child.runtimeType} at ${size.width}dp '
          'text ${textScale}x\n${captured.join('\n---\n')}',
    );
  }

  const sizes = [
    Size(320, 640),
    Size(393, 852),
    Size(412, 915),
  ];

  group('no overflow at any supported width', () {
    testWidgets('dashboard', (tester) async {
      for (final size in sizes) {
        await render(
          tester,
          BurnDashboardScreen(onAddSubscription: () {}),
          size,
        );
      }
    });

    testWidgets('dashboard with 130 % text', (tester) async {
      for (final size in const [Size(320, 640), Size(393, 852)]) {
        await render(
          tester,
          BurnDashboardScreen(onAddSubscription: () {}),
          size,
          textScale: 1.3,
        );
      }
    });

    testWidgets('renewals', (tester) async {
      for (final size in sizes) {
        await render(tester, const RenewalsScreen(), size);
      }
    });

    testWidgets('controls', (tester) async {
      for (final size in sizes) {
        await render(tester, const ControlsScreen(), size);
      }
    });

    testWidgets('detail', (tester) async {
      for (final size in sizes) {
        await render(
          tester,
          const SubDetailScreen(subscriptionId: 's0'),
          size,
        );
      }
    });

    testWidgets('detail with the longest vendor name', (tester) async {
      await render(
        tester,
        const SubDetailScreen(subscriptionId: 's2'),
        const Size(320, 640),
        textScale: 1.3,
      );
    });

    testWidgets('studio', (tester) async {
      for (final size in sizes) {
        await render(tester, const ViralReceiptScreen(), size);
      }
    });

    testWidgets('quick add', (tester) async {
      for (final size in sizes) {
        await render(
          tester,
          const QuickAddSheet(),
          size,
        );
      }
    });

    testWidgets('edit sheet', (tester) async {
      await render(
        tester,
        EditSubscriptionSheet(subscription: _sub(0)),
        const Size(320, 640),
        textScale: 1.3,
      );
    });

    testWidgets('legal pages', (tester) async {
      for (final doc in LegalDoc.values) {
        await render(
          tester,
          LegalPage(doc: doc),
          const Size(320, 640),
        );
      }
    });

    // WCAG 1.4.4: text must scale to 200 % without loss of content. The sweep
    // only covered 130 % before, which is where the old clamp sat.
    testWidgets('dashboard at 200 % text', (tester) async {
      await render(
        tester,
        BurnDashboardScreen(onAddSubscription: () {}),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('detail at 200 % text', (tester) async {
      await render(
        tester,
        const SubDetailScreen(subscriptionId: 's0'),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('controls at 200 % text', (tester) async {
      await render(
        tester,
        const ControlsScreen(),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('legal at 200 % text', (tester) async {
      await render(
        tester,
        const LegalPage(doc: LegalDoc.privacy),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('empty ledger', (tester) async {
      repo = SubscriptionRepository.inMemory();
      await render(
        tester,
        BurnDashboardScreen(onAddSubscription: () {}),
        const Size(320, 640),
      );
    });

    testWidgets('receipt with only ghosts', (tester) async {
      repo = SubscriptionRepository.inMemory(
        initial: [for (var i = 0; i < 3; i++) _sub(i * 3)],
      );
      await render(tester, const ViralReceiptScreen(), const Size(320, 640));
    });
  });

  // States the first sweep never pumped: search results, the shell's own
  // bottom bar, 200 % on the remaining screens, and the confirm dialogs.
  // Each of these broke (or was predicted to break) at 320 dp / 200 % text.
  group('previously uncovered states', () {
    Future<void> settleAndAssert(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'threw after interaction\n${captured.join('\n---\n')}',
      );
      expect(
        captured.where((e) => e.contains('overflowed')).toList(),
        isEmpty,
        reason: 'overflowed after interaction',
      );
    }

    testWidgets('quick add with search results at 320 dp / 200 %',
        (tester) async {
      await render(
        tester,
        const QuickAddSheet(),
        const Size(320, 640),
        textScale: 2,
      );
      await tester.enterText(find.byType(TextField).first, 'a');
      await settleAndAssert(tester);
    });

    testWidgets('shell bottom bar at 320 dp / 200 %', (tester) async {
      await render(tester, const HomeShell(), const Size(320, 640),
          textScale: 2);
    });

    testWidgets('renewals at 320 dp / 200 %', (tester) async {
      await render(
        tester,
        RenewalsScreen(onAddSubscription: () {}),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('renewals empty with CTA at 320 dp / 200 %', (tester) async {
      repo = SubscriptionRepository.inMemory();
      await render(
        tester,
        RenewalsScreen(onAddSubscription: () {}),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('studio at 320 dp / 200 %', (tester) async {
      await render(
        tester,
        const ViralReceiptScreen(),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('edit sheet at 320 dp / 200 %', (tester) async {
      await render(
        tester,
        EditSubscriptionSheet(subscription: _sub(0)),
        const Size(320, 640),
        textScale: 2,
      );
    });

    testWidgets('every legal doc at 320 dp / 200 %', (tester) async {
      for (final doc in LegalDoc.values) {
        await render(
          tester,
          LegalPage(doc: doc),
          const Size(320, 640),
          textScale: 2,
        );
      }
    });

    testWidgets('delete dialog with a 60-char name at 320 dp / 200 %',
        (tester) async {
      final long = Subscription(
        id: 'long',
        name: 'Adobe Creative Cloud Photography Plan Enterprise Edition',
        vendor: 'ADOBE SYSTEMS INCORPORATED',
        monogram: 'AC',
        brandColor: 0xFF10A37F,
        amount: 1660,
        currency: CurrencyCode.inr,
        cycle: BillingCycle.monthly,
        guilt: UsageGuilt.dailyDriver,
        category: 'design',
        startDate: DateTime(2024, 3, 31),
        nextBillingDate: DateTime.now().add(const Duration(hours: 30)),
        cancelUrl: 'https://example.com/cancel',
      );
      expect(long.name.length, greaterThanOrEqualTo(55));
      repo = SubscriptionRepository.inMemory(initial: [long]);
      await render(
        tester,
        const SubDetailScreen(subscriptionId: 'long'),
        const Size(320, 640),
        textScale: 2,
      );
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await settleAndAssert(tester);
      await tester.tap(find.text('Delete subscription'));
      await settleAndAssert(tester);
    });

    testWidgets('duplicate dialog at 320 dp / 200 %', (tester) async {
      await render(
        tester,
        const QuickAddSheet(),
        const Size(320, 640),
        textScale: 2,
      );
      await tester.enterText(find.byType(TextField).at(1), 'ChatGPT Plus');
      await tester.enterText(find.byType(TextField).at(2), '1660');
      await tester.tap(find.text('Add to burn tracker'));
      await settleAndAssert(tester);
    });
  });
}

Future<CatalogueSnapshot> _snapshotFromAssets() async {
  final raw = await rootBundle.loadString('assets/json/presets_v1.json');
  return CatalogueSnapshot(
    catalogue: PresetCatalogue.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      fromCache: true,
    ),
    rates: ExchangeRates.fallback,
    source: CatalogueSource.bundled,
  );
}
