import 'package:hive_ce/hive.dart';

import '../models/billing_cycle.dart';
import '../models/currency.dart';
import '../models/theme_preference.dart';
import '../models/subscription.dart';
import '../models/usage_guilt.dart';

/// Hand-written Hive adapter for [Subscription].
///
/// Written by hand rather than generated so the on-disk field order is part of
/// the reviewed source. That order must never change — insert new fields at the
/// end only. The reader loops over the field count *stored in the data*, so
/// old records read fine with new adapters (missing keys default) and new
/// records survive a downgrade (unknown keys are ignored). There is no
/// migration mechanism; never reorder or reuse a field index.
class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 1;

  @override
  Subscription read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };

    return Subscription(
      id: fields[0] as String,
      name: fields[1] as String,
      vendor: (fields[2] as String?) ?? '',
      monogram: (fields[3] as String?) ?? '??',
      brandColor: (fields[4] as int?) ?? 0xFF9A9AA4,
      amount: (fields[5] as num).toDouble(),
      currency: CurrencyCode.fromStorage(fields[6] as String),
      cycle: BillingCycle.fromStorage(fields[7] as String),
      guilt: UsageGuilt.fromStorage(fields[8] as String),
      startDate: DateTime.fromMillisecondsSinceEpoch(fields[9] as int),
      nextBillingDate: DateTime.fromMillisecondsSinceEpoch(fields[10] as int),
      remindersEnabled: (fields[11] as bool?) ?? true,
      cancelUrl: (fields[12] as String?) ?? '',
      category: (fields[13] as String?) ?? 'other',
      presetId: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.vendor)
      ..writeByte(3)
      ..write(obj.monogram)
      ..writeByte(4)
      ..write(obj.brandColor)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.currency.name)
      ..writeByte(7)
      ..write(obj.cycle.name)
      ..writeByte(8)
      ..write(obj.guilt.name)
      ..writeByte(9)
      ..write(obj.startDate.millisecondsSinceEpoch)
      ..writeByte(10)
      ..write(obj.nextBillingDate.millisecondsSinceEpoch)
      ..writeByte(11)
      ..write(obj.remindersEnabled)
      ..writeByte(12)
      ..write(obj.cancelUrl)
      ..writeByte(13)
      ..write(obj.category)
      ..writeByte(14)
      ..write(obj.presetId);
  }
}

/// Persisted user preferences. Kept in Hive next to the subscriptions so a
/// single box open covers the whole local-first store.
class AppSettings {
  const AppSettings({
    this.displayCurrency = CurrencyCode.inr,
    this.themePreference = ThemePreference.system,
    // Off until the user asks. Defaulting to "on" showed a green switch on a
    // fresh install where no permission had ever been requested.
    this.notificationsEnabled = false,
    this.notificationsPermissionAsked = false,
    this.receiptThemesUnlocked = false,
    this.installId,
    this.bannerPauseUntil = 0,
    this.appOpenLastShownAt = 0,
    this.launchCount = 0,
  });

  final CurrencyCode displayCurrency;

  /// Defaults to [ThemePreference.system] so a new install matches the phone.
  final ThemePreference themePreference;

  final bool notificationsEnabled;

  /// Whether the OS notification prompt has already been answered. We ask
  /// once, on the first save, and never again.
  final bool notificationsPermissionAsked;

  /// True once the user has watched a rewarded ad for the extra receipt
  /// themes. A real, permanent unlock — not a consumable.
  final bool receiptThemesUnlocked;

  /// Stable anonymous id used for OneSignal and support, never linked to a
  /// person.
  final String? installId;

  /// Epoch-ms until which the dashboard banner stays hidden — the reward for
  /// watching one rewarded ad ("hide the banner for 24 h"). 0 = not paused.
  /// A rewarded opt-in that *removes* advertising: the user always has a
  /// path to fewer ads, never only to more.
  final int bannerPauseUntil;

  /// Epoch-ms of the last app-open ad show, for the 3-hour frequency cap.
  final int appOpenLastShownAt;

  /// Process launches counted on this install. App-open ads skip the first
  /// launch after install (Google's guidance, and basic decency).
  final int launchCount;

  bool get bannerPaused =>
      bannerPauseUntil > DateTime.now().millisecondsSinceEpoch;

  AppSettings copyWith({
    CurrencyCode? displayCurrency,
    ThemePreference? themePreference,
    bool? notificationsEnabled,
    bool? notificationsPermissionAsked,
    bool? receiptThemesUnlocked,
    String? installId,
    int? bannerPauseUntil,
    int? appOpenLastShownAt,
    int? launchCount,
  }) {
    return AppSettings(
      displayCurrency: displayCurrency ?? this.displayCurrency,
      themePreference: themePreference ?? this.themePreference,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationsPermissionAsked:
          notificationsPermissionAsked ?? this.notificationsPermissionAsked,
      receiptThemesUnlocked:
          receiptThemesUnlocked ?? this.receiptThemesUnlocked,
      installId: installId ?? this.installId,
      bannerPauseUntil: bannerPauseUntil ?? this.bannerPauseUntil,
      appOpenLastShownAt: appOpenLastShownAt ?? this.appOpenLastShownAt,
      launchCount: launchCount ?? this.launchCount,
    );
  }
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      displayCurrency: CurrencyCode.fromStorage(
        (fields[0] as String?) ?? 'inr',
      ),
      notificationsEnabled: (fields[1] as bool?) ?? false,
      notificationsPermissionAsked: (fields[2] as bool?) ?? false,
      installId: fields[3] as String?,
      themePreference: ThemePreference.fromStorage(fields[4] as String?),
      receiptThemesUnlocked: (fields[5] as bool?) ?? false,
      bannerPauseUntil: (fields[6] as int?) ?? 0,
      appOpenLastShownAt: (fields[7] as int?) ?? 0,
      launchCount: (fields[8] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.displayCurrency.name)
      ..writeByte(1)
      ..write(obj.notificationsEnabled)
      ..writeByte(2)
      ..write(obj.notificationsPermissionAsked)
      ..writeByte(3)
      ..write(obj.installId)
      ..writeByte(4)
      ..write(obj.themePreference.name)
      ..writeByte(5)
      ..write(obj.receiptThemesUnlocked)
      ..writeByte(6)
      ..write(obj.bannerPauseUntil)
      ..writeByte(7)
      ..write(obj.appOpenLastShownAt)
      ..writeByte(8)
      ..write(obj.launchCount);
  }
}
