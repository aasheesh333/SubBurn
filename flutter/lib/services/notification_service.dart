import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/clock.dart';
import '../data/models/subscription.dart';

/// Why reminders can stop working, surfaced to the UI instead of a debug log.
enum ReminderStatus {
  /// Plugin not initialised yet (or failed to).
  notInitialized,

  /// OS permission not granted, or revoked in system settings.
  permissionDenied,

  /// App notifications are allowed, but this app's own channel was switched
  /// off (or silenced to zero importance) in system settings. Android reports
  /// the app-level permission as granted in that state, so without this the UI
  /// claimed "ACTIVE" while nothing could ever be delivered.
  channelBlocked,

  /// Ready to schedule.
  ready,
}

/// Local renewal reminders.
///
/// Two notifications per subscription — 48 h and 24 h before the charge — are
/// scheduled with [AndroidScheduleMode.inexactAllowWhileIdle]. Inexact alarms
/// need no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission, which is why
/// this app passes Play Console review without the "alarms & reminders" special
/// access declaration. A renewal reminder does not need second precision.
///
/// **Failure policy:** every OS call is individually guarded. Initialisation
/// records its own error instead of throwing, because a single throwing step
/// used to leave `_initialized == false` forever: nothing was scheduled, the
/// toggle still read "on", and the only trace was a debugPrint. The UI now reads
/// [status] and [lastError] and can say exactly what is wrong.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'subburn_renewals';
  static const _channelName = 'Renewal reminders';
  static const _channelDescription =
      'Alerts 48 hours and 24 hours before a subscription renews.';

  bool _initialized = false;
  bool _permissionGranted = false;

  /// True when the app-level permission is on but our channel is silenced.
  bool _channelBlocked = false;
  String? lastError;

  /// Called with the subscription id when the user taps a reminder.
  void Function(String subscriptionId)? onOpenSubscription;

  /// Stable id for the in-app test notification.

  bool get isInitialized => _initialized;

  ReminderStatus get status {
    if (!_initialized) return ReminderStatus.notInitialized;
    if (!_permissionGranted) return ReminderStatus.permissionDenied;
    if (_channelBlocked) return ReminderStatus.channelBlocked;
    return ReminderStatus.ready;
  }

  /// Initialises the plugin, retrying if a previous attempt failed.
  ///
  /// A single failure used to be permanent: `_initialized` stayed false, every
  /// later call returned early, and the only symptom was "not initialised on
  /// this device" in the UI. Now each call re-attempts while uninitialised, so a
  /// transient failure (or a fixed resource after an update) heals itself.
  Future<void> initialize(
      {void Function(String subscriptionId)? onOpen}) async {
    if (_initialized) return;
    if (onOpen != null) onOpenSubscription = onOpen;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Falls back to the packaged UTC zone; scheduling still works.
      debugPrint('Timezone lookup failed, using UTC: $error');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {
        // Nothing else to fall back to.
      }
    }

    const android = AndroidInitializationSettings('ic_stat_subburn');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      // `false` means the platform refused the settings, which in practice is a
      // missing small-icon drawable. Record it and stay uninitialised so the
      // next call retries rather than pretending everything is fine.
      if (ok == false) {
        lastError =
            'The system refused the notification setup. The app icon used for '
            'alerts could not be loaded.';
        debugPrint('initialize returned false');
        return;
      }
    } catch (error) {
      lastError = 'Notification setup failed: $error';
      debugPrint(lastError);
      return;
    }

    // Channel creation is separate: on Android 8+ a failure here must not take
    // the whole service down, and on iOS it is a no-op.
    try {
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
    } catch (error) {
      lastError = 'Notification channel failed: $error';
      debugPrint(lastError);
    }

    _initialized = true;
    await refreshPermission();
  }

  /// A tap on a reminder opens the subscription it is about. The payload is the
  /// subscription id written at schedule time.
  void _handleResponse(NotificationResponse response) {
    final id = response.payload;
    if (id == null || id.isEmpty) {
      // The self-test notification has no payload; just resume the app.
      return;
    }
    onOpenSubscription?.call(id);
  }

  /// Handles the tap that launched a terminated app.
  Future<void> handleLaunchNotification() async {
    if (!_initialized) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          onOpenSubscription?.call(payload);
        }
      }
    } catch (error) {
      debugPrint('launch details unavailable: $error');
    }
  }

  /// Re-reads the OS permission without prompting.
  ///
  /// A user who grants notifications later in system settings used to stay
  /// broken for the life of the install, because the flag was only ever written
  /// from the prompt result.
  Future<bool> refreshPermission() async {
    if (!_initialized) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        _permissionGranted = await android?.areNotificationsEnabled() ?? false;
        _channelBlocked = false;
        if (_permissionGranted) {
          // App-level permission being on is not enough: the user can silence
          // just this app's channel, and Android still reports the app as
          // enabled. Importance.none means nothing is ever delivered.
          try {
            final channels = await android?.getNotificationChannels();
            final ours = channels?.where((c) => c.id == _channelId);
            if (ours != null && ours.isNotEmpty) {
              _channelBlocked = ours.first.importance == Importance.none;
            }
          } catch (error) {
            debugPrint('Channel check failed: $error');
          }
        }
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final options = await ios?.checkPermissions();
        _permissionGranted = options?.isEnabled ?? false;
      } else {
        _permissionGranted = false;
      }
    } catch (error) {
      debugPrint('Permission check failed: $error');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// Asks the OS for permission. Returns false when declined.
  Future<bool> requestPermission() async {
    // Retry initialisation first: a failed start must not make the toggle
    // permanently unusable for the rest of the session.
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        _permissionGranted = granted ?? await refreshPermission();
        return _permissionGranted;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionGranted = granted ?? false;
        return _permissionGranted;
      }
    } catch (error) {
      lastError = 'Permission request failed: $error';
      debugPrint(lastError);
    }
    return false;
  }

  /// Schedules both reminders for [subscription], replacing any previous pair.
  Future<bool> scheduleFor(
    Subscription subscription, {
    required bool enabled,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) {
      lastError ??= 'Notifications could not start on this device.';
      return false;
    }
    if (!await refreshPermission()) {
      lastError = 'Notification permission is not granted.';
      return false;
    }
    await cancelFor(subscription.id);
    if (!enabled || !subscription.remindersEnabled) return true;

    final charge = subscription.currency.format(subscription.amount);
    final slots = <int, Duration>{
      0: const Duration(hours: SbWindow.reminderHours),
      1: const Duration(hours: SbWindow.finalNoticeHours),
    };

    var scheduled = 0;
    for (final entry in slots.entries) {
      final fireAt = subscription.nextBillingDate.subtract(entry.value);
      if (fireAt.isBefore(SbClock.now().add(const Duration(minutes: 1)))) {
        continue; // the window already opened; never fire a stale alarm
      }
      final window = entry.value.inHours;
      final body = window >= 48
          ? '$charge renews in 2 days. Cancel now if it is ghost spend.'
          : '$charge renews tomorrow. Last call before the charge.';

      try {
        await _plugin.zonedSchedule(
          id: _notificationId(subscription.id, entry.key),
          // Built from the absolute instant, not the wall clock: if the
          // timezone lookup failed we fall back to UTC, and `TZDateTime.from`
          // would then shift every alarm by the device offset (a 9:00 reminder
          // firing at 14:30 in IST). Epoch millis are zone-independent, and
          // Android's alarm manager only needs the instant.
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.local,
            fireAt.millisecondsSinceEpoch,
          ),
          notificationDetails: _details(body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: '${subscription.name} renews soon',
          body: body,
          payload: subscription.id,
        );
        scheduled++;
      } catch (error) {
        // One bad slot must not stop the other, and must not silently vanish.
        lastError = 'Scheduling ${subscription.name} failed: $error';
        debugPrint(lastError);
      }
    }
    return scheduled > 0;
  }

  NotificationDetails _details(String body) => NotificationDetails(
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
      );

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

  /// How many reminders are actually queued — the honest answer to "is it
  /// working?", shown in Controls.
  Future<int> pendingCount() async {
    if (!_initialized) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (error) {
      debugPrint('pendingNotificationRequests failed: $error');
      return 0;
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

  /// Opens this app's notification settings screen.
  ///
  /// The ALLOW button used to re-prompt, which Android silently refuses after
  /// the user has declined twice — a dead end with no way forward. This is the
  /// documented escape hatch.
  Future<bool> openNotificationSettings() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Prompt first: if the user has not permanently declined, this is the
        // least friction. If they have, Android no-ops and we fall through to
        // the settings screen, which also lists our channel toggle.
        final granted = await android.requestNotificationsPermission();
        if (granted == true) return true;
        return await android.openAppNotificationSettings() ?? false;
      }
    } catch (error) {
      debugPrint('openNotificationSettings failed: $error');
    }
    return false;
  }
}
