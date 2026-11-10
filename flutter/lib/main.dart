import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'features/detail/sub_detail_screen.dart';
import 'data/repositories/subscription_repository.dart';
import 'services/catalogue_service.dart';
import 'services/firebase_bootstrap.dart';
import 'core/navigator_key.dart';
import 'services/ads_service.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'state/providers.dart';

/// Boot order matters:
///
/// 1. Firebase (defensive — the app runs without it).
/// 2. Local database, then the first-run seed.
/// 3. Notifications (plugins are cheap, but never block startup).
/// 4. Remote Config values → CDN base URL → OneSignal.
/// 5. `runApp`, with every service injected through Riverpod overrides.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The families are bundled under assets/google_fonts using Google Fonts'
  // asset naming convention, so this never hits the network.
  GoogleFonts.config.allowRuntimeFetching = false;

  runZonedGuarded<Future<void>>(
    () async {
      final firebase = await FirebaseRuntime.initialize();

      final repository = await SubscriptionRepository.open();

      final remoteConfig = firebase.remoteConfig;
      final catalogueService = CatalogueService(
        baseUrl: remoteConfig?.cdnBaseUrl ??
            'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev',
      );

      // Nothing is written to the ledger on install. The app opens on the
      // empty state and the user adds their own subscriptions.

      // One anonymous id per install, created before the first frame so no
      // provider has to mutate another during build.
      if (repository.settings.installId == null) {
        await repository.saveSettings(
          repository.settings.copyWith(
            installId: 'inst_${SubscriptionRepository.newId()}',
          ),
        );
      }

      final notifications = NotificationService();
      try {
        await notifications.initialize(
          // A reminder tap has to land on the subscription it describes, even
          // when the app was terminated. Pushing through the root navigator is
          // the only context-free way to do it.
          onOpen: (subscriptionId) {
            final navigator = rootNavigatorKey.currentState;
            if (navigator == null) return;
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => SubDetailScreen(subscriptionId: subscriptionId),
              ),
            );
          },
        );
        // Cold start from a tap: the callback above is already set, so this
        // replays the launch payload exactly once.
        await notifications.handleLaunchNotification();
      } catch (error) {
        debugPrint('Notifications unavailable: $error');
      }

      // Re-arming happens on the shell's first frame and on every resume:
      // doing it here raced with the UI and could not report failures.

      runApp(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            catalogueServiceProvider.overrideWithValue(catalogueService),
            analyticsProvider.overrideWithValue(firebase.analytics),
            notificationServiceProvider.overrideWithValue(notifications),
            adsServiceProvider.overrideWithValue(
              AdsService.fromRemoteConfig(
                firebase.initialized ? FirebaseRemoteConfig.instance : null,
              ),
            ),
          ],
          child: const SubBurnApp(),
        ),
      );

      // Non-blocking: push is a broadcast channel, never a startup dependency.
      unawaited(
        OneSignalService.initialize(
          appId: remoteConfig?.oneSignalAppId ?? '',
          installId: repository.settings.installId,
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught: $error\n$stack');
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        // Crashlytics was never initialised — the console is the last resort.
      }
    },
  );
}
