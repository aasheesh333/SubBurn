import 'dart:async';
import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../hive/local_adapters.dart';
import '../models/subscription.dart';

/// Local-first store. 100 % of user data lives here — on the device, no
/// Firestore, no account, no sync. That is what keeps the backend free at any
/// user count.
///
/// The store starts empty, always. This is a money tracker: a fabricated
/// subscription would show the user a burn figure they never incurred, and in
/// a finance product invented data is indistinguishable from a bug.
///
/// Two backends, one contract:
/// * [open] / [openTest] use Hive boxes (production, on-disk).
/// * [inMemory] uses plain maps (widget tests, previews) — no file I/O, so
///   widget tests do not stall in Flutter's fake-async zone.
class SubscriptionRepository {
  SubscriptionRepository._hive(this._subs, this._settings)
      : _memSubs = null,
        _memSettings = null;

  SubscriptionRepository._memory(this._memSubs, this._memSettings)
      : _subs = null,
        _settings = null;

  static const boxName = 'subscriptions_v1';
  static const settingsBoxName = 'settings_v1';
  static const _settingsKey = 'app_settings';

  final Box<Subscription>? _subs;
  final Box<AppSettings>? _settings;
  final Map<String, Subscription>? _memSubs;
  final Map<String, AppSettings>? _memSettings;

  bool get isInMemory => _memSubs != null;

  static Future<SubscriptionRepository> open() async {
    await Hive.initFlutter();
    return _openBoxes();
  }

  /// Isolated on-disk store, for integration tests that care about persistence.
  static Future<SubscriptionRepository> openTest(String path) async {
    Hive.init(path);
    return _openBoxes();
  }

  /// Volatile store for widget tests and design previews.
  factory SubscriptionRepository.inMemory({
    Iterable<Subscription> seed = const [],
    AppSettings settings = const AppSettings(),
  }) {
    final repo = SubscriptionRepository._memory(
      {for (final s in seed) s.id: s},
      {_settingsKey: settings},
    );
    return repo;
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
    return SubscriptionRepository._hive(subs, settings);
  }

  List<Subscription> all({bool rollOverdue = true}) {
    final list = _memSubs?.values.toList() ?? _subs!.values.toList();
    if (rollOverdue) {
      for (var i = 0; i < list.length; i++) {
        final sub = list[i];
        if (!sub.isOverdue) continue;
        final corrected = sub.rolledForward();
        list[i] = corrected;
        // Persist the correction; failures here must not break reading.
        unawaited(put(corrected));
      }
    }
    list.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return list;
  }

  Subscription? byId(String id) {
    final mem = _memSubs;
    if (mem != null) return mem[id];
    return _subs?.get(id);
  }

  /// Reads one subscription, normalising an overdue renewal date.
  Subscription? byIdRolled(String id) {
    final existing = byId(id);
    if (existing == null || !existing.isOverdue) return existing;
    final corrected = existing.rolledForward();
    unawaited(put(corrected));
    return corrected;
  }

  Future<void> put(Subscription subscription) async {
    final mem = _memSubs;
    if (mem != null) {
      mem[subscription.id] = subscription;
      return;
    }
    await _subs!.put(subscription.id, subscription);
  }

  Future<void> delete(String id) async {
    final mem = _memSubs;
    if (mem != null) {
      mem.remove(id);
      return;
    }
    await _subs!.delete(id);
  }

  Future<void> clear() async {
    final mem = _memSubs;
    if (mem != null) {
      mem.clear();
      return;
    }
    await _subs!.clear();
  }

  int get length => _memSubs?.length ?? _subs!.length;

  bool get isEmpty => length == 0;

  AppSettings get settings =>
      _memSettings?[_settingsKey] ??
      _settings?.get(_settingsKey) ??
      const AppSettings();

  Future<void> saveSettings(AppSettings value) async {
    final mem = _memSettings;
    if (mem != null) {
      mem[_settingsKey] = value;
      return;
    }
    await _settings!.put(_settingsKey, value);
  }

  static String newId() {
    final rand = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch;
    final noise = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'sub_${now.toRadixString(16)}_$noise';
  }

  Future<void> close() async {
    if (isInMemory) return;
    await _subs?.close();
    await _settings?.close();
  }
}
