import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import 'package:subburn/services/ads_bootstrap.dart';
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

  // Font Awesome (brand + solid) comes from the pub cache; without it the
  // catalogue tiles render as tofu boxes.
  final faRoot = Directory(
    '${Platform.environment['HOME'] ?? '/root'}/.pub-cache/hosted/pub.dev/'
    'font_awesome_flutter-11.0.0/lib/fonts',
  );
  // Family names must match what FaIconData declares, package prefix and all.
  const faFamilies = {
    'packages/font_awesome_flutter/FontAwesomeBrands':
        'Font-Awesome-7-Brands-Regular-400.otf',
    'packages/font_awesome_flutter/FontAwesomeSolid':
        'Font-Awesome-7-Free-Solid-900.otf',
    'packages/font_awesome_flutter/FontAwesomeRegular':
        'Font-Awesome-7-Free-Regular-400.otf',
  };
  for (final entry in faFamilies.entries) {
    final file = File('${faRoot.path}/${entry.value}');
    if (!file.existsSync()) continue;
    final loader = FontLoader(entry.key);
    final bytes = file.readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
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
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

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

/// Pumps past every entrance animation.
///
/// A fixed 400 ms pump landed exactly on the boundary of the stagger window
/// (index * 32 ms, capped at 5) plus the 240 ms fade, so goldens sometimes
/// captured rows at opacity 0. The app-shell golden showed both lists empty
/// because of it — a store screenshot that lied about the app.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  // Decode the brand asset before capturing: Image.asset resolves
  // asynchronously and a golden captured mid-decode records an empty tile.
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    await precacheImage(
      const AssetImage('assets/brand/app_icon.png'),
      context,
    );
  });
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Widget _harness({
  required Widget child,
  required SubscriptionRepository repo,
  required CatalogueSnapshot snapshot,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      catalogueProvider.overrideWith(() => _FixedCatalogue(snapshot)),
      analyticsProvider.overrideWithValue(AnalyticsService(null)),
      notificationServiceProvider.overrideWithValue(NotificationService()),
      reminderHealthProvider.overrideWith((ref) async => const ReminderHealth(
            wantsReminders: true,
            status: ReminderStatus.ready,
            pending: 4,
            lastError: null,
          )),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // The builder runs *inside* MaterialApp, so context.sb resolves to the
      // active theme. A Builder outside MaterialApp fell back to the dark
      // palette, which is why a "light" golden still had a black page.
      builder: (context, inner) => MediaQuery(
        // Goldens must capture the settled frame, not a mid-animation one.
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: ColoredBox(
          color: context.sb.bg,
          child: inner ?? const SizedBox.shrink(),
        ),
      ),
      home: Scaffold(backgroundColor: Colors.transparent, body: child),
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
    // No ad SDK in tests: it needs platform channels and a real network.
    AdsBootstrap.disabled = true;
    // Freeze time so renewal countdowns in the goldens are deterministic.
    SbClock.freeze(DateTime(2026, 11, 9, 9, 41));
    PackageInfo.setMockInitialValues(
      appName: 'SubBurn',
      packageName: 'com.dhanuk.subburn',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
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

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        child: child,
        repo: repo,
        snapshot: snapshot,
        themeMode: themeMode,
      ),
    );
    await _settle(tester);
  }

  testWidgets('renewals · light', (tester) async {
    await pump(tester, const RenewalsScreen(), themeMode: ThemeMode.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/13-renewals-light.png'),
    );
  });

  testWidgets('quick add · light', (tester) async {
    await pump(tester, const QuickAddSheet(), themeMode: ThemeMode.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/14-quick-add-light.png'),
    );
  });

  testWidgets('dashboard · light', (tester) async {
    await pump(
      tester,
      BurnDashboardScreen(onAddSubscription: () {}),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/09-dashboard-light.png'),
    );
  });

  testWidgets('studio · light', (tester) async {
    await pump(
      tester,
      const ViralReceiptScreen(),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/10-studio-light.png'),
    );
  });

  testWidgets('detail · light', (tester) async {
    await pump(
      tester,
      const SubDetailScreen(subscriptionId: 'preview_0'),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/12-detail-light.png'),
    );
  });

  testWidgets('controls · light', (tester) async {
    await pump(tester, const ControlsScreen(), themeMode: ThemeMode.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/11-controls-light.png'),
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
          reminderHealthProvider
              .overrideWith((ref) async => const ReminderHealth(
                    wantsReminders: true,
                    status: ReminderStatus.ready,
                    pending: 4,
                    lastError: null,
                  )),
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
          reminderHealthProvider
              .overrideWith((ref) async => const ReminderHealth(
                    wantsReminders: true,
                    status: ReminderStatus.ready,
                    pending: 4,
                    lastError: null,
                  )),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              backgroundColor: SbColors.bg,
              body: BurnDashboardScreen(onAddSubscription: () {}),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
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
          reminderHealthProvider
              .overrideWith((ref) async => const ReminderHealth(
                    wantsReminders: true,
                    status: ReminderStatus.ready,
                    pending: 4,
                    lastError: null,
                  )),
        ],
        child: const SubBurnApp(),
      ),
    );
    await _settle(tester);
    await expectLater(
      find.byType(SubBurnApp),
      matchesGoldenFile('goldens/00-app.png'),
    );
  });
}
