import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../hive/local_adapters.dart';
import '../models/billing_cycle.dart';
import '../models/currency.dart';
import '../models/preset_tool.dart';
import '../models/subscription.dart';
import '../models/usage_guilt.dart';

/// Local-first store. 100 % of user data lives here — Hive on the device, no
/// Firestore, no account, no sync. That is what keeps the backend free at any
/// user count.
class SubscriptionRepository {
  SubscriptionRepository._(this._subs, this._settings);

  static const boxName = 'subscriptions_v1';
  static const settingsBoxName = 'settings_v1';
  static const _settingsKey = 'app_settings';

  final Box<Subscription> _subs;
  final Box<AppSettings> _settings;

  static Future<SubscriptionRepository> open() async {
    await Hive.initFlutter();
    return _openBoxes();
  }

  /// Opens an isolated store backed by [path] — used by the test suite.
  static Future<SubscriptionRepository> openTest(String path) async {
    Hive.init(path);
    return _openBoxes();
  }

  static Future<SubscriptionRepository> _openBoxes() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SubscriptionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    final subs = await Hive.openBox<Subscription>(boxName);
    final settings = await Hive.openBox<AppSettings>(settingsBoxName);
    return SubscriptionRepository._(subs, settings);
  }

  List<Subscription> all() {
    final list = _subs.values.toList();
    list.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return list;
  }

  Subscription? byId(String id) => _subs.get(id);

  Future<void> put(Subscription subscription) =>
      _subs.put(subscription.id, subscription);

  Future<void> delete(String id) => _subs.delete(id);

  Future<void> clear() => _subs.clear();

  int get length => _subs.length;

  bool get isEmpty => _subs.isEmpty;

  AppSettings get settings => _settings.get(_settingsKey) ?? const AppSettings();

  Future<void> saveSettings(AppSettings value) =>
      _settings.put(_settingsKey, value);

  /// Plants five realistic rows on first launch so the dashboard, the roast
  /// and the share card all have something to say before the user has typed
  /// anything. Every row is a normal subscription — swipe to delete works, and
  /// `settings.seeded` guarantees this happens exactly once.
  Future<bool> seedIfNeeded(PresetCatalogue catalogue) async {
    final current = settings;
    if (current.seeded || _subs.isNotEmpty) {
      if (!current.seeded) {
        await saveSettings(current.copyWith(seeded: true));
      }
      return false;
    }

    final now = DateTime.now();
    const specs = <_SeedSpec>[
      _SeedSpec(
        presetName: 'ChatGPT Plus',
        amount: 1660,
        startMonthsAgo: 13,
        guilt: UsageGuilt.dailyDriver,
        hoursToRenewal: 14,
      ),
      _SeedSpec(
        presetName: 'Claude Pro',
        amount: 1660,
        startMonthsAgo: 8,
        guilt: UsageGuilt.dailyDriver,
        hoursToRenewal: 23,
      ),
      _SeedSpec(
        presetName: 'Cursor Pro',
        amount: 830,
        startMonthsAgo: 3,
        guilt: UsageGuilt.barelyTouch,
        hoursToRenewal: 35,
      ),
      _SeedSpec(
        presetName: 'GitHub Copilot',
        amount: 415,
        startMonthsAgo: 5,
        guilt: UsageGuilt.barelyTouch,
        hoursToRenewal: 120,
      ),
      _SeedSpec(
        presetName: 'Midjourney',
        amount: 285,
        startMonthsAgo: 11,
        guilt: UsageGuilt.dailyDriver,
        hoursToRenewal: 200,
      ),
    ];

    for (final spec in specs) {
      final preset = _findPreset(catalogue, spec.presetName);
      await put(
        Subscription(
          id: newId(),
          name: preset?.name ?? spec.presetName,
          vendor: preset?.vendor ?? 'SubBurn',
          monogram:
              preset?.monogram ?? spec.presetName.substring(0, 2).toUpperCase(),
          brandColor: preset?.brandColor ?? 0xFF9A9AA4,
          amount: spec.amount,
          currency: CurrencyCode.inr,
          cycle: BillingCycle.monthly,
          guilt: spec.guilt,
          category: preset?.category ?? 'ai',
          startDate: DateTime(now.year, now.month - spec.startMonthsAgo, now.day),
          nextBillingDate: now.add(Duration(hours: spec.hoursToRenewal)),
          cancelUrl: preset?.cancelUrl ?? '',
          presetId: preset?.id,
        ),
      );
    }

    await saveSettings(current.copyWith(seeded: true));
    return true;
  }

  static PresetTool? _findPreset(PresetCatalogue catalogue, String name) {
    for (final tool in catalogue.tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  static String newId() {
    final rand = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch;
    final noise = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'sub_${now.toRadixString(16)}_$noise';
  }

  Future<void> close() async {
    await _subs.close();
    await _settings.close();
  }
}

class _SeedSpec {
  const _SeedSpec({
    required this.presetName,
    required this.amount,
    required this.startMonthsAgo,
    required this.guilt,
    required this.hoursToRenewal,
  });

  final String presetName;
  final double amount;
  final int startMonthsAgo;
  final UsageGuilt guilt;
  final int hoursToRenewal;
}
