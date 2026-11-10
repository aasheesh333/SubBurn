import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subburn/data/models/currency.dart';
import 'package:subburn/data/repositories/subscription_repository.dart';
import 'package:subburn/features/dashboard/burn_dashboard_screen.dart';
import 'package:subburn/services/analytics_service.dart';
import 'package:subburn/services/notification_service.dart';
import 'package:subburn/state/providers.dart';

import 'audit_test.dart' as a;

void main() {
  testWidgets('usd currency symbol everywhere', (tester) async {
    final repo = SubscriptionRepository.inMemory(initial: [a.subFixture()]);
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      analyticsProvider.overrideWithValue(AnalyticsService(null)),
      notificationServiceProvider.overrideWithValue(NotificationService()),
    ]);
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setCurrency(CurrencyCode.usd);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: BurnDashboardScreen(onAddSubscription: () {})),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final all = tester.widgetList<Text>(find.byType(Text));
    final rupees = all
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => s.contains('\u20B9'))
        .toList();
    expect(rupees, isEmpty, reason: 'INR leaked into USD mode');
  });
}
