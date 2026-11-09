import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive/local_adapters.dart';
import '../data/models/currency.dart';
import '../data/models/preset_tool.dart';
import '../data/models/subscription.dart';
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
    await repo.put(subscription);
    await _scheduleReminder(subscription);
    ref.read(analyticsProvider).logSubAdded(subscription, fromPreset: fromPreset);
    state = repo.all();
  }

  Future<void> update(Subscription subscription) async {
    final repo = ref.read(repositoryProvider);
    await repo.put(subscription);
    await _scheduleReminder(subscription);
    state = repo.all();
  }

  Future<void> remove(String id) async {
    final repo = ref.read(repositoryProvider);
    final removed = repo.byId(id);
    await repo.delete(id);
    await ref.read(notificationServiceProvider).cancelFor(id);
    if (removed != null) {
      ref.read(analyticsProvider).logSubscriptionDeleted();
    }
    state = repo.all();
  }

  Future<void> clearAll() async {
    final repo = ref.read(repositoryProvider);
    await repo.clear();
    await ref.read(notificationServiceProvider).cancelAll();
    state = const [];
  }

  Future<void> restore(Subscription subscription) async {
    await ref.read(repositoryProvider).put(subscription);
    await _scheduleReminder(subscription);
    state = ref.read(repositoryProvider).all();
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

  Future<void> _scheduleReminder(Subscription subscription) async {
    final settings = ref.read(settingsProvider);
    if (!settings.notificationsEnabled) return;
    await ref.read(notificationServiceProvider).scheduleFor(
          subscription,
          enabled: true,
        );
  }
}

/// Device preferences. Local only; nothing here is synced.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(repositoryProvider).settings;

  Future<void> setCurrency(CurrencyCode currency) async {
    final repo = ref.read(repositoryProvider);
    final next = repo.settings.copyWith(displayCurrency: currency);
    await repo.saveSettings(next);
    state = next;
    await ref.read(analyticsProvider).setDisplayCurrency(currency.code);
  }

  Future<void> setNotifications(bool enabled) async {
    final repo = ref.read(repositoryProvider);
    final next = repo.settings.copyWith(notificationsEnabled: enabled);
    await repo.saveSettings(next);
    state = next;
    final service = ref.read(notificationServiceProvider);
    if (enabled) {
      await service.requestPermission();
      for (final sub in ref.read(subscriptionsProvider)) {
        await service.scheduleFor(sub, enabled: true);
      }
    } else {
      await service.cancelAll();
    }
  }

  /// One anonymous id per install, created lazily and reused forever.
  Future<String> ensureInstallId() async {
    final existing = ref.read(settingsProvider).installId;
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

/// Presets + FX rate. Refreshes at most once every 7 days; `refresh()` is the
/// pull-to-refresh path and bypasses the cache.
final catalogueProvider =
    AsyncNotifierProvider<CatalogueNotifier, CatalogueSnapshot>(
  CatalogueNotifier.new,
);

class CatalogueNotifier extends AsyncNotifier<CatalogueSnapshot> {
  @override
  Future<CatalogueSnapshot> build() async {
    await ref.read(settingsProvider.notifier).ensureInstallId();
    return ref.read(catalogueServiceProvider).load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(catalogueServiceProvider).load(forceRefresh: true),
    );
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

final renewingSoonProvider = Provider<List<Subscription>>(
  (ref) => ref.watch(burnSummaryProvider).dueSoon,
);
