import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'catalogue_service.dart';

/// Firebase Messaging handler for data messages delivered while the app is
/// terminated. Must be a top-level function and annotated for tree-shaking.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No personal data is processed in the background: OneSignal owns display.
  debugPrint('background push: ${message.messageId}');
}

/// Everything Firebase, initialised defensively.
///
/// The app is local-first: if Firebase cannot start (no network on first run,
/// a missing config file in a fork, an emulator without Google Play) the app
/// still opens, and every dependent service degrades to a no-op.
class FirebaseRuntime {
  FirebaseRuntime({
    required this.analytics,
    required this.remoteConfig,
    required this.crashlyticsEnabled,
    required this.initialized,
  });

  final AnalyticsService analytics;
  final RemoteConfigService? remoteConfig;
  final bool crashlyticsEnabled;
  final bool initialized;

  static FirebaseRuntime offline() => FirebaseRuntime(
        analytics: AnalyticsService(null),
        remoteConfig: null,
        crashlyticsEnabled: false,
        initialized: false,
      );

  static Future<FirebaseRuntime> initialize() async {
    try {
      await Firebase.initializeApp();

      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(!kDebugMode);

      final remoteConfig = RemoteConfigService(FirebaseRemoteConfig.instance);
      await remoteConfig.initialize();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.subscribeToTopic('subburn_global');
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      return FirebaseRuntime(
        analytics: AnalyticsService(analytics),
        remoteConfig: remoteConfig,
        crashlyticsEnabled: true,
        initialized: true,
      );
    } catch (error, stack) {
      debugPrint('Firebase unavailable, continuing local-first: $error');
      debugPrint('$stack');
      return FirebaseRuntime.offline();
    }
  }
}
