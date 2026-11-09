import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'data/models/preset_tool.dart';
import 'data/repositories/subscription_repository.dart';
import 'services/catalogue_service.dart';
import 'services/firebase_bootstrap.dart';
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

      // Seed before the first frame so the dashboard never flashes empty for
      // an existing user; a brand-new install gets five realistic rows once.
      PresetCatalogue bundled;
      try {
        bundled = await catalogueService.loadBundledCatalogue();
      } catch (error) {
        debugPrint('Bundled catalogue missing: $error');
        bundled = PresetCatalogue.empty;
      }
      await repository.seedIfNeeded(bundled);

      final notifications = NotificationService();
      try {
        await notifications.initialize();
      } catch (error) {
        debugPrint('Notifications unavailable: $error');
      }

      runApp(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            catalogueServiceProvider.overrideWithValue(catalogueService),
            analyticsProvider.overrideWithValue(firebase.analytics),
            notificationServiceProvider.overrideWithValue(notifications),
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
