import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/subscription.dart';

/// Local renewal reminders.
///
/// Two notifications per subscription — 48 h and 24 h before the charge — are
/// scheduled with [AndroidScheduleMode.inexactAllowWhileIdle]. Inexact alarms
/// need no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission, which is why
/// this app passes Play Console review without the "alarms & reminders" special
/// access declaration. A renewal reminder does not need second precision.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'subburn_renewals';
  static const _channelName = 'Renewal reminders';
  static const _channelDescription =
      'Alerts 48 hours and 24 hours before a subscription renews.';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Falls back to the packaged UTC zone; scheduling still works.
      debugPrint('Timezone lookup failed, using UTC: $error');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('ic_stat_subburn');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// Asks the OS for permission. Returns false when declined — callers must
  /// keep working, because reminders are a convenience, not a requirement.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  /// Schedules both reminders for [subscription], replacing any previous pair.
  Future<void> scheduleFor(
    Subscription subscription, {
    required bool enabled,
  }) async {
    // A plugin that never initialised (desktop test host, a failed timezone
    // lookup, a device where the channel was rejected) must not be able to
    // break saving or deleting a subscription.
    if (!_initialized) return;
    await cancelFor(subscription.id);
    if (!enabled || !subscription.remindersEnabled) return;

    final charge = subscription.currency.format(
      subscription.amount,
    );
    final slots = <int, Duration>{
      0: const Duration(hours: SbWindow.reminderHours),
      1: const Duration(hours: SbWindow.finalNoticeHours),
    };

    for (final entry in slots.entries) {
      final fireAt = subscription.nextBillingDate.subtract(entry.value);
      if (fireAt.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
        continue; // the window already opened; never fire a stale alarm
      }
      final window = entry.value.inHours;
      final body = window >= 48
          ? '$charge renews in 2 days. Cancel now if it is ghost spend.'
          : '$charge renews tomorrow. Last call before the charge.';

      await _plugin.zonedSchedule(
        id: _notificationId(subscription.id, entry.key),
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'ic_stat_subburn',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            color: const Color(0xFFFF4500),
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '${subscription.name} renews soon',
        body: body,
        payload: subscription.id,
      );
    }
  }

  Future<void> cancelFor(String subscriptionId) async {
    if (!_initialized) return;
    try {
      for (var slot = 0; slot < 2; slot++) {
        await _plugin.cancel(id: _notificationId(subscriptionId, slot));
      }
    } catch (error) {
      debugPrint('cancelFor($subscriptionId) failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('cancelAll failed: $error');
    }
  }

  /// Stable FNV-1a hash so reminder ids survive app restarts and never collide
  /// with Android's 32-bit notification id space.
  int _notificationId(String subscriptionId, int slot) {
    var hash = 0x811C9DC5;
    for (final unit in subscriptionId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    final base = (hash % 200000000) * 10;
    return base + slot;
  }
}
