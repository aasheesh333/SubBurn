import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../data/models/subscription.dart';

/// Thin, crash-proof wrapper around Firebase Analytics.
///
/// Analytics is a nice-to-have. Every call is wrapped so a disabled or
/// misconfigured Firebase project can never take a user action down with it.
/// Only two product events matter: `sub_added` and `roast_card_shared`.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics? _analytics;

  bool get enabled => _analytics != null;

  Future<void> logSubAdded(Subscription subscription,
      {required bool fromPreset}) {
    return _log('sub_added', <String, Object>{
      'category': subscription.category,
      'cycle': subscription.cycle.name,
      'currency': subscription.currency.code,
      'guilt': subscription.guilt.name,
      'from_preset': fromPreset,
      // Bucketed so the value is a dimension, not a fingerprint.
      'price_bucket': _priceBucket(subscription.amount),
    });
  }

  Future<void> logRoastCardShared({
    required String tier,
    required num yearlyBurn,
    required String method,
  }) {
    return _log('roast_card_shared', <String, Object>{
      'tier': tier,
      'yearly_burn_bucket': _burnBucket(yearlyBurn),
      'method': method,
    });
  }

  Future<void> logSubscriptionDeleted() => _log('sub_deleted');

  /// [category] is a coarse bucket ('ai', 'streaming', …). The raw vendor name
  /// must never be sent: the privacy policy promises analytics carry no names,
  /// prices or vendors.
  Future<void> logCancelLinkOpened(
      {required String category, required bool resolved}) {
    return _log('cancel_link_opened', <String, Object>{
      'category': category,
      'resolved': resolved,
    });
  }

  Future<void> logScreenView(String screen) {
    final analytics = _analytics;
    if (analytics == null) return Future.value();
    return analytics
        .logScreenView(screenName: screen, screenClass: screen)
        .catchError((Object error) {
      debugPrint('analytics.logScreenView failed: $error');
    });
  }

  Future<void> setDisplayCurrency(String currency) {
    final analytics = _analytics;
    if (analytics == null) return Future.value();
    return analytics
        .setUserProperty(name: 'display_currency', value: currency)
        .catchError((Object error) {
      debugPrint('analytics.setUserProperty failed: $error');
    });
  }

  Future<void> _log(String name, [Map<String, Object>? parameters]) {
    final analytics = _analytics;
    if (analytics == null) return Future.value();
    return analytics.logEvent(name: name, parameters: parameters).catchError(
      (Object error) {
        debugPrint('analytics.$name failed: $error');
      },
    );
  }

  static String _priceBucket(num amount) {
    if (amount <= 0) return 'free';
    if (amount < 500) return '0-499';
    if (amount < 1000) return '500-999';
    if (amount < 2000) return '1000-1999';
    if (amount < 5000) return '2000-4999';
    return '5000+';
  }

  static String _burnBucket(num yearly) {
    if (yearly < 12000) return '<12k';
    if (yearly < 36000) return '12k-36k';
    if (yearly < 72000) return '36k-72k';
    if (yearly < 120000) return '72k-120k';
    return '120k+';
  }
}
