import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive/local_adapters.dart';
import '../data/models/currency.dart';
import '../data/models/preset_tool.dart';
import '../data/models/subscription.dart';
import '../data/models/theme_preference.dart';
import '../data/repositories/subscription_repository.dart';
import '../services/analytics_service.dart';
import '../services/catalogue_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';

/// Concrete dependencies are injected in `main()` with `ProviderScope`
/// overrides, so tests and the app share one graph with no service locator.
final repositoryProvider = Provider<SubscriptionRepository>(
  (ref) => throw StateError('repositoryProvider must be overridden'),
);

final catalogueServiceProvider = Provider<CatalogueService>(
  (ref) => throw StateError('catalogueServiceProvider must be overridden'),
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(null),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final shareServiceProvider = Provider<ShareService>((ref) => const ShareService());

/// The live subscription list. Every mutation writes Hive first, then updates
/// state from the store, so the UI can never show something that was not saved.
final subscriptionsProvider =
    NotifierProvider<SubscriptionsNotifier, List<Subscription>>(
  SubscriptionsNotifier.new,
);

class SubscriptionsNotifier extends Notifier<List<Subscription>> {
  @override
  List<Subscription> build() => ref.watch(repositoryProvider).all();

  Future<void> add(Subscription subscription, {bool fromPreset = false}) async {
    final repo = ref.read(repositoryProvider);
    await _ensureNotificationPermission();
    // Optimistic first, then persist: the UI never waits on disk, and a
    // Dismissible is never left in the tree after its row is gone.
    state = _sorted([...state, subscription]);
    await repo.put(subscription);
    await _scheduleReminder(subscription);
    ref.read(analyticsProvider).logSubAdded(subscription, fromPreset: fromPreset);
    state = repo.all();
  }

  Future<void> update(Subscription subscription) async {
    final repo = ref.read(repositoryProvider);
    state = _sorted([
      for (final s in state) s.id == subscription.id ? subscription : s,
    ]);
    await repo.put(subscription);
    await _scheduleReminder(subscription);
  }

  Future<void> remove(String id) async {
    final repo = ref.read(repositoryProvider);
    final removed = repo.byId(id) ?? _findInState(id);
    // Synchronous removal is a correctness requirement, not an optimisation:
    // Dismissible asserts if a dismissed child is still present on the next
    // build, and awaiting Hive first guaranteed exactly that window.
    state = state.where((s) => s.id != id).toList(growable: false);
    await repo.delete(id);
    await ref.read(notificationServiceProvider).cancelFor(id);
    if (removed != null) {
      ref.read(analyticsProvider).logSubscriptionDeleted();
    }
  }

  Subscription? _findInState(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<Subscription> _sorted(List<Subscription> list) {
    final copy = [...list]
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return List.unmodifiable(copy);
  }

  Future<void> clearAll() async {
    final repo = ref.read(repositoryProvider);
    await repo.clear();
    await ref.read(notificationServiceProvider).cancelAll();
    state = const [];
  }

  Future<void> restore(Subscription subscription) async {
    state = _sorted([...state, subscription]);
    await ref.read(repositoryProvider).put(subscription);
    await _scheduleReminder(subscription);
  }

  Future<void> setReminders(String id, bool enabled) async {
    final repo = ref.read(repositoryProvider);
    final existing = repo.byId(id);
    if (existing == null) return;
    final updated = existing.copyWith(remindersEnabled: enabled);
    await repo.put(updated);
    await _scheduleReminder(updated);
    state = repo.all();
  }

  void refresh() {
    state = ref.read(repositoryProvider).all();
  }

  /// Android 13+ needs a runtime grant. Asking on the first save (when the
  /// user has just said "remind me about money") beats asking at boot, and a
  /// denial is recorded so we never ask twice or pretend reminders work.
  /// Asks for the notification permission exactly once, from the moment the
  /// user has just saved a subscription ("remind me about this").
  Future<void> _ensureNotificationPermission() async {
    final settings = ref.read(settingsProvider);
    if (settings.notificationsPermissionAsked) return;
    final service = ref.read(notificationServiceProvider);
    if (!service.isInitialized) return; // cannot prompt yet; try next time
    await ref.read(settingsProvider.notifier).requestNotificationPermission();
  }

  /// Re-arms every enabled subscription. Called after the user grants
  /// permission, when the app returns to the foreground, and at startup — a
  /// reboot or an OS cleanup drops scheduled alarms, and a subscription whose
  /// billing date rolled forward needs a fresh pair.
  Future<int> rescheduleAll() async {
    final service = ref.read(notificationServiceProvider);
    if (!await service.refreshPermission()) return 0;
    var armed = 0;
    for (final sub in ref.read(subscriptionsProvider)) {
      if (!sub.remindersEnabled) continue;
      if (await service.scheduleFor(sub, enabled: true)) armed++;
    }
    ref.invalidate(reminderHealthProvider);
    return armed;
  }

  Future<void> _scheduleReminder(Subscription subscription) async {
    final settings = ref.read(settingsProvider);
    final service = ref.read(notificationServiceProvider);
    if (!settings.notificationsEnabled) return;
    await service.scheduleFor(subscription, enabled: true);
    ref.invalidate(reminderHealthProvider);
  }
}

/// Device preferences. Local only; nothing here is synced.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(repositoryProvider).settings;

  Future<void> setTheme(ThemePreference preference) async {
    final repo = ref.read(repositoryProvider);
    final next = repo.settings.copyWith(themePreference: preference);
    await repo.saveSettings(next);
    state = next;
  }

  Future<void> setCurrency(CurrencyCode currency) async {
    final repo = ref.read(repositoryProvider);
    final next = repo.settings.copyWith(displayCurrency: currency);
    await repo.saveSettings(next);
    state = next;
    await ref.read(analyticsProvider).setDisplayCurrency(currency.code);
  }

  /// Prompts the OS once and stores the outcome. Unlike [setNotifications] this
  /// never changes the user's intent — it only records whether the phone allows
  /// delivery, so the UI can explain a blocked state.
  Future<bool> requestNotificationPermission() async {
    final repo = ref.read(repositoryProvider);
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();
    final next = repo.settings.copyWith(
      notificationsEnabled: granted,
      notificationsPermissionAsked: true,
    );
    await repo.saveSettings(next);
    state = next;
    ref.invalidate(reminderHealthProvider);
    return granted;
  }

  /// Turns reminders on or off.
  ///
  /// Returns whether reminders are actually deliverable. Permission is part of
  /// "on": a switch that reads on while the OS blocks every notification is a
  /// lie, and that is exactly what shipped before.
  Future<bool> setNotifications(bool enabled) async {
    final repo = ref.read(repositoryProvider);
    final service = ref.read(notificationServiceProvider);

    if (enabled) {
      // Ask, then read back the real OS state rather than trusting the prompt.
      await service.requestPermission();
      final granted = await service.refreshPermission();
      final next = repo.settings.copyWith(
        notificationsEnabled: granted,
        notificationsPermissionAsked: true,
      );
      await repo.saveSettings(next);
      state = next;
      if (!granted) {
        ref.invalidate(reminderHealthProvider);
        return false;
      }
      await ref.read(subscriptionsProvider.notifier).rescheduleAll();
      ref.invalidate(reminderHealthProvider);
      return true;
    }

    final next = repo.settings.copyWith(notificationsEnabled: false);
    await repo.saveSettings(next);
    state = next;
    await service.cancelAll();
    ref.invalidate(reminderHealthProvider);
    return false;
  }


  /// One anonymous id per install, created lazily and reused forever.
  Future<String> ensureInstallId() async {
    // `ref.read(settingsProvider)` here would be a provider depending on
    // itself — Riverpod asserts on that. The notifier already owns the value.
    final existing = state.installId;
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'inst_${SubscriptionRepository.newId()}';
    await setInstallId(id);
    return id;
  }

  Future<void> setInstallId(String installId) async {
    final repo = ref.read(repositoryProvider);
    final next = repo.settings.copyWith(installId: installId);
    await repo.saveSettings(next);
    state = next;
  }
}

/// True while a manual refresh is in flight. Kept separate from the
/// [AsyncValue] so a refresh never blanks the FX rate: totals would otherwise
/// flicker to the fallback rate for the duration of the request.
final catalogueRefreshingProvider =
    NotifierProvider<CatalogueRefreshingNotifier, bool>(
  CatalogueRefreshingNotifier.new,
);

class CatalogueRefreshingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Presets + FX rate. Refreshes at most once every 7 days; `refresh()` is the
/// pull-to-refresh path and bypasses the cache.
final catalogueProvider =
    AsyncNotifierProvider<CatalogueNotifier, CatalogueSnapshot>(
  CatalogueNotifier.new,
);

class CatalogueNotifier extends AsyncNotifier<CatalogueSnapshot> {
  @override
  Future<CatalogueSnapshot> build() {
    // Nothing here may write to another provider: Riverpod forbids mutating
    // state from inside a build, and doing so threw at runtime. The install id
    // is created once in main() before the first frame.
    return ref.read(catalogueServiceProvider).load();
  }

  Future<void> refresh() async {
    final refreshing = ref.read(catalogueRefreshingProvider.notifier);
    refreshing.set(true);
    try {
      final next = await AsyncValue.guard(
        () => ref.read(catalogueServiceProvider).load(forceRefresh: true),
      );
      // On failure keep the previous snapshot; a failed refresh must not
      // change any number on screen.
      if (next.hasValue) state = next;
    } finally {
      refreshing.set(false);
    }
  }
}

final ratesProvider = Provider<ExchangeRates>((ref) {
  final snapshot = ref.watch(catalogueProvider).value;
  return snapshot?.rates ?? ExchangeRates.fallback;
});

/// The single source of every number on screen.
final burnSummaryProvider = Provider<BurnSummary>((ref) {
  final subs = ref.watch(subscriptionsProvider);
  final settings = ref.watch(settingsProvider);
  final rates = ref.watch(ratesProvider);
  return BurnSummary.from(
    subs,
    currency: settings.displayCurrency,
    inrPerUsd: rates.inrPerUsd,
  );
});

/// What the controls screen shows about reminders: whether the OS will deliver
/// them, and how many are actually queued. This is the difference between "the
/// toggle is on" and "the phone will buzz".
class ReminderHealth {
  const ReminderHealth({
    required this.wantsReminders,
    required this.status,
    required this.pending,
    required this.lastError,
  });

  final bool wantsReminders;
  final ReminderStatus status;
  final int pending;
  final String? lastError;

  bool get isWorking =>
      wantsReminders && status == ReminderStatus.ready && pending > 0;

  /// True when the user asked for reminders but the OS is blocking them.
  bool get blockedByOs =>
      wantsReminders && status == ReminderStatus.permissionDenied;
}

final reminderHealthProvider = FutureProvider<ReminderHealth>((ref) async {
  final settings = ref.watch(settingsProvider);
  final service = ref.watch(notificationServiceProvider);
  await service.refreshPermission();
  return ReminderHealth(
    wantsReminders: settings.notificationsEnabled,
    status: service.status,
    pending: await service.pendingCount(),
    lastError: service.lastError,
  );
});

final renewingSoonProvider = Provider<List<Subscription>>(
  (ref) => ref.watch(burnSummaryProvider).dueSoon,
);
