import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subburn/app.dart';
import 'package:subburn/core/theme/app_theme.dart';
import 'package:subburn/core/clock.dart';
import 'package:subburn/core/theme/theme_tokens.dart';
import 'package:subburn/data/models/billing_cycle.dart';
import 'package:subburn/data/models/currency.dart';
import 'package:subburn/data/models/preset_tool.dart';
import 'package:subburn/data/models/subscription.dart';
import 'package:subburn/data/models/usage_guilt.dart';
import 'package:subburn/data/repositories/subscription_repository.dart';
import 'package:subburn/features/controls/controls_screen.dart';
import 'package:subburn/features/dashboard/burn_dashboard_screen.dart';
import 'package:subburn/features/detail/sub_detail_screen.dart';
import 'package:subburn/features/quick_add/quick_add_sheet.dart';
import 'package:subburn/features/renewals/renewals_screen.dart';
import 'package:subburn/features/studio/viral_receipt_screen.dart';
import 'package:subburn/services/analytics_service.dart';
import 'package:subburn/services/catalogue_service.dart';
import 'package:subburn/services/notification_service.dart';
import 'package:subburn/state/providers.dart';

/// Renders every screen to a golden PNG at 393 × 852 @2x.
///
/// Run with `flutter test test/screens_preview_test.dart --update-goldens` to
/// refresh the images, and without the flag to catch visual regressions.
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

  // Material Icons ships with the Flutter SDK and is required for `Icons.*`
  // glyphs. The SDK path differs per machine (and on CI), so resolve it
  // instead of hard-coding one user's home directory.
  final iconsFile = _materialIconsFile();
  if (iconsFile != null) {
    final loader = FontLoader('MaterialIcons');
    final bytes = iconsFile.readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
    await loader.load();
  } else {
    // ignore: avoid_print
    print('MaterialIcons font not found; golden icons may render as tofu.');
  }
}

/// Locates `MaterialIcons-Regular.otf` inside the active Flutter SDK.
File? _materialIconsFile() {
  const relative = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?) root,
    // <flutter>/bin/cache/dart-sdk/bin/dart → <flutter>
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path,
  ];

  for (final root in roots) {
    final candidate = File('$root/$relative');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

CatalogueSnapshot _snapshot() {
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

class _FixedCatalogue extends CatalogueNotifier {
  _FixedCatalogue(this.snapshot);

  final CatalogueSnapshot snapshot;

  @override
  Future<CatalogueSnapshot> build() async => snapshot;

  @override
  Future<void> refresh() async {}
}

/// Golden-test fixture only. The shipped app never writes subscriptions the
/// user did not add.
Future<void> _fixtureLedger(SubscriptionRepository repo) async {
  final now = SbClock.now();
  final specs = <(String, String, String, int, bool, int, String)>[
    ('ChatGPT Plus', '[OI]', 'AI', 1660, true, 14, 'ai'),
    ('Claude Pro', 'Anthropic', 'CL', 1660, true, 23, 'ai'),
    ('Cursor Pro', 'Anysphere', 'CU', 830, false, 35, 'dev'),
    ('GitHub Copilot', 'GitHub', 'GH', 415, false, 96, 'dev'),
    ('Midjourney', 'Midjourney', 'MJ', 285, true, 200, 'ai'),
  ];
  var i = 0;
  for (final s in specs) {
    await repo.put(
      Subscription(
        id: 'preview_$i',
        name: s.$1,
        vendor: s.$2,
        monogram: s.$3,
        brandColor: _brand(s.$7),
        amount: s.$4.toDouble(),
        currency: CurrencyCode.inr,
        cycle: BillingCycle.monthly,
        guilt: s.$5 ? UsageGuilt.dailyDriver : UsageGuilt.barelyTouch,
        category: s.$7,
        startDate: DateTime(now.year, now.month - 10, now.day),
        nextBillingDate: now.add(Duration(hours: s.$6)),
        cancelUrl: 'https://example.com/cancel',
      ),
    );
    i++;
  }
}

int _brand(String category) => switch (category) {
      'dev' => 0xFFA78BFA,
      _ => 0xFF10A37F,
    };

Widget _harness({
  required Widget child,
  required SubscriptionRepository repo,
  required CatalogueSnapshot snapshot,
}) {
  return ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
      analyticsProvider.overrideWithValue(AnalyticsService(null)),
      notificationServiceProvider.overrideWithValue(NotificationService()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: SbColors.bg,
        body: child,
      ),
    ),
  );
}

void main() {
  late Directory dir;
  late SubscriptionRepository repo;
  late CatalogueSnapshot snapshot;

  setUpAll(() async {
    await _loadFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    // Freeze time so renewal countdowns in the goldens are deterministic.
    SbClock.freeze(DateTime(2026, 11, 9, 9, 41));
    dir = await Directory.systemTemp.createTemp('subburn_preview_');
    repo = await SubscriptionRepository.openTest(dir.path);
    snapshot = _snapshot();
    await _fixtureLedger(repo);
  });

  tearDownAll(() {
    SbClock.reset();
  });

  tearDownAll(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(child: child, repo: repo, snapshot: snapshot),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('dashboard · first run (empty)', (tester) async {
    final empty = SubscriptionRepository.inMemory();
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(empty),
          catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            backgroundColor: SbColors.bg,
            body: BurnDashboardScreen(onAddSubscription: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08-first-run.png'),
    );
  });

  testWidgets('dashboard · first run (empty)', (tester) async {
    final empty = SubscriptionRepository.inMemory();
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        child: BurnDashboardScreen(onAddSubscription: () {}),
        repo: empty,
        snapshot: snapshot,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08-first-run.png'),
    );
  });

  testWidgets('dashboard', (tester) async {
    await pump(
      tester,
      BurnDashboardScreen(
        onAddSubscription: () {},
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01-dashboard.png'),
    );
  });

  testWidgets('quick add', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: SbColors.bg,
              body: Center(
                child: TextButton(
                  onPressed: () => QuickAddSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final button = find.text('open');
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02-quick-add.png'),
    );
  });

  testWidgets('studio', (tester) async {
    await pump(tester, const ViralReceiptScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03-studio.png'),
    );
  });

  testWidgets('renewals', (tester) async {
    await pump(tester, const RenewalsScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05-renewals.png'),
    );
  });

  testWidgets('controls', (tester) async {
    await pump(tester, const ControlsScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06-controls.png'),
    );
  });

  testWidgets('detail', (tester) async {
    await pump(tester, const SubDetailScreen(subscriptionId: 'preview_0'));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04-detail.png'),
    );
  });

  testWidgets('dashboard at 320 dp / 130 % text', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/07-dashboard-320.png'),
    );
  });

  testWidgets('app shell', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
          analyticsProvider.overrideWithValue(AnalyticsService(null)),
          notificationServiceProvider.overrideWithValue(NotificationService()),
        ],
        child: const SubBurnApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(SubBurnApp),
      matchesGoldenFile('goldens/00-app.png'),
    );
  });
}
