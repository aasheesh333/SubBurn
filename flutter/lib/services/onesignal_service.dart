import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal push, used only for broadcast product news — never for private
/// subscription data. The device is identified by a random install id, so no
/// account, email or phone number ever reaches OneSignal.
abstract final class OneSignalService {
  static bool _ready = false;

  static bool get isReady => _ready;

  /// Initialises the SDK when an app id is available.
  ///
  /// The id comes from Remote Config first and a compile-time define second,
  /// so switching it on is a console change, not a release.
  static Future<void> initialize({
    required String appId,
    String? installId,
  }) async {
    final resolved = appId.trim();
    if (resolved.isEmpty) {
      debugPrint('OneSignal skipped: no app id configured');
      return;
    }
    try {
      await OneSignal.initialize(resolved);
      if (installId != null && installId.isNotEmpty) {
        await OneSignal.login(installId);
      }
      await OneSignal.Notifications.requestPermission(true);
      _ready = true;
    } catch (error) {
      // Never block startup on a third-party SDK.
      debugPrint('OneSignal init failed: $error');
    }
  }

  /// Re-links the device to its install id after a restore.
  static Future<void> identify(String installId) async {
    if (!_ready) return;
    await OneSignal.login(installId);
  }

  static Future<void> optIn(bool value) async {
    if (!_ready) return;
    await OneSignal.Notifications.requestPermission(value);
  }
}
