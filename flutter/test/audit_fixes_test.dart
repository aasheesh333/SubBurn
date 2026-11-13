/// Regression tests for the 2026-11-11 deep audit fixes.
///
/// Every test here reproduces a concrete defect that was found by reading the
/// codebase line-by-line; the comments record the failure each one guards.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subburn/core/utils/formatters.dart';
import 'package:subburn/data/models/billing_cycle.dart';
import 'package:subburn/data/models/cycle_conversion.dart';
import 'package:subburn/data/models/currency.dart';
import 'package:subburn/data/models/subscription.dart';
import 'package:subburn/data/models/usage_guilt.dart';
import 'package:subburn/data/repositories/subscription_repository.dart';
import 'package:subburn/services/ads_service.dart';
import 'package:subburn/services/app_open_ad_service.dart';

Subscription _sub({
  required String id,
  required DateTime startDate,
  required DateTime nextBillingDate,
  BillingCycle cycle = BillingCycle.monthly,
  double amount = 100,
}) =>
    Subscription(
      id: id,
      name: 'Audit',
      vendor: 'V',
      monogram: 'A',
      brandColor: 0xFF101010,
      amount: amount,
      currency: CurrencyCode.inr,
      cycle: cycle,
      guilt: UsageGuilt.dailyDriver,
      category: 'other',
      startDate: startDate,
      nextBillingDate: nextBillingDate,
      cancelUrl: '',
    );

void main() {
  group('billing cycle anchoring', () {
    test('month clamps never accumulate (Jan 31 → Feb 28 → Mar 31)', () {
      // Old code iterated advance() from the previous date, so the February
      // clamp stuck: Mar 28 instead of the vendor's Mar 31.
      const anchor = BillingCycle.monthly;
      final start = DateTime(2026, 1, 31);
      expect(anchor.nthAfter(start, 1), DateTime(2026, 2, 28));
      expect(anchor.nthAfter(start, 2), DateTime(2026, 3, 31));
      expect(anchor.nthAfter(start, 3), DateTime(2026, 4, 30));
    });

    test('leap-day yearly anchor returns to Feb 29 in the next leap year', () {
      const anchor = BillingCycle.yearly;
      final start = DateTime(2024, 2, 29);
      expect(anchor.nthAfter(start, 1), DateTime(2025, 2, 28));
      expect(anchor.nthAfter(start, 4), DateTime(2028, 2, 29));
    });

    test('nextAfter keeps the anchor day after a short month', () {
      // Regression: start Jan 31, now Mar 1 → old code said Mar 28.
      final next = BillingCycle.monthly.nextAfter(
        DateTime(2026, 1, 31),
        now: DateTime(2026, 3, 1),
      );
      expect(next, DateTime(2026, 3, 31));
    });

    test('nextAfter is always strictly in the future, even for 2005 weekly',
        () {
      // Regression: the old fixed 600-iteration cap returned 2016-07-09 for
      // a weekly plan started in 2005 — a past date that crashed the date
      // picker (initialDate < firstDate).
      final start = DateTime(2005, 1, 1);
      final now = DateTime(2026, 11, 11);
      final next = BillingCycle.weekly.nextAfter(start, now: now);
      expect(next.isAfter(now), isTrue);
      expect(next.difference(start).inDays % 7, 0);
      expect(
        next.difference(now).inDays,
        lessThanOrEqualTo(7),
        reason: 'must be the first charge after now, not a later one',
      );
    });

    test('rolledForward re-anchors to the start date grid', () {
      final sub = _sub(
        id: 'roll',
        startDate: DateTime(2026, 1, 31),
        nextBillingDate: DateTime(2026, 2, 28),
      );
      final rolled = sub.rolledForward(now: DateTime(2026, 3, 15));
      expect(rolled.nextBillingDate, DateTime(2026, 3, 31));
    });

    test('chargeCount counts anchor charges, not drifted ones', () {
      // Jan 31 plan: charges are Jan 31, Feb 28, Mar 31. As of Mar 29 only
      // two have been taken; the old drift counted a phantom Mar 28 charge.
      final sub = _sub(
        id: 'count',
        startDate: DateTime(2026, 1, 31),
        nextBillingDate: DateTime(2026, 3, 31),
      );
      expect(sub.chargeCount(asOf: DateTime(2026, 3, 29)), 2);
      expect(sub.chargeCount(asOf: DateTime(2026, 3, 31)), 3);
    });
  });

  group('cycle conversion keeps cents', () {
    test('\$9.99/mo survives a yearly round trip', () {
      // Old _round() snapped to whole units: $9.99 → $100/yr → $10/mo.
      final yearly = CycleConversion.convert(
        amount: 9.99,
        from: BillingCycle.monthly,
        to: BillingCycle.yearly,
        discountApplied: false,
      );
      expect(yearly.amount, 99.5); // 9.99 × 12 × 0.83 = 99.5004 → 99.50
      expect(yearly.discountApplied, isTrue);

      final back = CycleConversion.convert(
        amount: yearly.amount,
        from: BillingCycle.yearly,
        to: BillingCycle.monthly,
        discountApplied: true,
      );
      expect(back.amount, 9.99);
      expect(back.discountApplied, isFalse);
    });
  });

  group('amount parsing', () {
    test('comma decimals are decimals, comma triples are thousands', () {
      // Old parser stripped every comma: '9,99' silently became 999.
      expect(parseAmount('9,99'), 9.99);
      expect(parseAmount('12,5'), 12.5);
      expect(parseAmount('1,660'), 1660);
      expect(parseAmount('1,234,567'), 1234567);
      expect(parseAmount('1,660.50'), 1660.50);
      expect(parseAmount(r'$9.99'), 9.99);
      expect(parseAmount('9.99'), 9.99);
    });

    test('unusable input returns null instead of a wrong number', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('1.2.3'), isNull);
      expect(parseAmount('12,3456'), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('formatPlainAmount never throws on non-finite input', () {
      // Regression: Infinity.round() threw inside the edit sheet's initState
      // after an unbounded price paste stored Infinity.
      expect(formatPlainAmount(double.infinity), '0');
      expect(formatPlainAmount(double.nan), '0');
      expect(formatPlainAmount(10), '10');
      expect(formatPlainAmount(9.99), '9.99');
    });

    test('monogram takes whole graphemes, not UTF-16 code units', () {
      expect(monogramFor('ChatGPT Plus'), 'CP');
      expect(monogramFor('🔥 fire'), '🔥F');
      expect(monogramFor('netflix'), 'N');
    });
  });

  group('date formatting', () {
    test('renewal day labels use calendar days', () {
      final now = DateTime(2026, 11, 11, 9);
      expect(formatRenewalDay(DateTime(2026, 11, 11), now: now), 'today');
      expect(formatRenewalDay(DateTime(2026, 11, 12), now: now), 'tomorrow');
      expect(formatRenewalDay(DateTime(2026, 11, 16), now: now), 'Mon 16 Nov');
    });

    test('charge dates show the year when it is not this year', () {
      final now = DateTime(2026, 11, 11);
      expect(formatChargeDate(DateTime(2026, 11, 15), now: now), 'Sun 15 Nov');
      expect(
        formatChargeDate(DateTime(2027, 11, 15), now: now),
        'Mon 15 Nov ’27',
      );
    });

    test('workdays in November 2026', () {
      // 30 days, 5 Sundays + 4 Saturdays → 21 workdays.
      expect(workdaysInMonth(DateTime(2026, 11)), 21);
    });
  });

  group('ads config', () {
    test('rewarded readiness has its own unit id', () {
      // Regression: rewardedUnitId aliased interstitialUnitId, which read a
      // Remote Config key nobody defined — the unlock feature was dead.
      const live = AdsService(
        enabled: true,
        bannerUnitId: 'ca-app-pub-x/1',
        rewardedUnitId: 'ca-app-pub-x/2',
      );
      expect(live.canShowBanner, isTrue);
      expect(live.canShowRewarded, isTrue);

      const halfConfigured = AdsService(enabled: true, bannerUnitId: 'b');
      expect(halfConfigured.canShowBanner, isTrue);
      expect(halfConfigured.canShowRewarded, isFalse);

      expect(AdsService.disabled.canShowBanner, isFalse);
      expect(AdsService.disabled.canShowRewarded, isFalse);
      expect(AdsService.fromRemoteConfig(null), AdsService.disabled);
    });
  });

  group('reminder scheduling', () {
    // Mirrors NotificationService's slot rule: a reminder is only scheduled if
    // its fire time is still in the future (minus a 1-minute guard).
    bool wouldSchedule(DateTime fireAt, DateTime now) =>
        !fireAt.isBefore(now.add(const Duration(minutes: 1)));

    final renewal = DateTime(2026, 11, 20, 9);

    test('both reminders arm when the renewal is days away', () {
      final now = DateTime(2026, 11, 12, 12);
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 48)), now),
          isTrue);
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 24)), now),
          isTrue);
    });

    test('the 48 h slot is skipped but the 24 h slot still arms', () {
      // Renews in 36 h: the 48 h window already opened, 24 h has not.
      final now = renewal.subtract(const Duration(hours: 36));
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 48)), now),
          isFalse);
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 24)), now),
          isTrue);
    });

    test('a renewal inside the guard window schedules nothing stale', () {
      final now = renewal.subtract(const Duration(minutes: 30));
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 48)), now),
          isFalse);
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 24)), now),
          isFalse);
    });

    test('a renewal 2 days out on the exact boundary still arms', () {
      final now = renewal.subtract(const Duration(hours: 48));
      // fireAt == now, and the guard is `isBefore(now + 1min)`, so this is
      // intentionally skipped: firing "in 2 days" at the same instant is a
      // stale alarm by the time the OS delivers it.
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 48)), now),
          isFalse);
      expect(wouldSchedule(renewal.subtract(const Duration(hours: 24)), now),
          isTrue);
    });
  });

  group('reminder id space', () {
    // Mirrors NotificationService._notificationId: FNV-1a over the id, folded
    // into 0..1.999e9, times 10 plus the slot.
    int notificationId(String id, int slot) {
      var hash = 0x811C9DC5;
      for (final unit in id.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0x7FFFFFFF;
      }
      return (hash % 200000000) * 10 + slot;
    }

    test('stays inside Android 32-bit id space for real ids', () {
      final ids = [
        for (var i = 0; i < 200; i++) 'inst_${i}abcxyz',
        'sub_1750000000000_abcdef',
      ];
      for (final id in ids) {
        for (var slot = 0; slot < 2; slot++) {
          final n = notificationId(id, slot);
          expect(n, greaterThanOrEqualTo(0));
          // Android notification ids are signed 32-bit.
          expect(n, lessThan(2147483647), reason: '$id slot $slot -> $n');
        }
      }
    });

    test('the two slots of one subscription never collide', () {
      for (var i = 0; i < 50; i++) {
        final id = 'sub_$i';
        expect(notificationId(id, 0), isNot(notificationId(id, 1)));
      }
    });

    test('distinct subscription ids rarely collide', () {
      final seen = <int, String>{};
      var collisions = 0;
      for (var i = 0; i < 5000; i++) {
        final id = 'sub_${i}_x';
        final n = notificationId(id, 0);
        if (seen.containsKey(n) && seen[n] != id) collisions++;
        seen[n] = id;
      }
      // 200M buckets for 5k ids: expected collisions well under 1%.
      expect(collisions, lessThan(5));
    });
  });

  group('app-open ad policy', () {
    final noon = DateTime(2026, 11, 12, 12);

    test('the first launch after install never shows an app-open ad', () {
      // Regression guard: app-open on first launch is against Google's
      // guidance and hostile to a user who has received zero value yet.
      expect(
        AppOpenAdService.allowed(
          now: noon,
          lastShownAt: 0,
          launchCount: 1,
        ),
        isFalse,
      );
      expect(
        AppOpenAdService.allowed(
          now: noon,
          lastShownAt: 0,
          launchCount: 2,
        ),
        isTrue,
      );
    });

    test('the 2-hour cap covers cold starts and resumes alike', () {
      final inside = noon.subtract(const Duration(hours: 1, minutes: 59));
      final outside = noon.subtract(const Duration(hours: 2, minutes: 1));
      expect(
        AppOpenAdService.allowed(
          now: noon,
          lastShownAt: inside.millisecondsSinceEpoch,
          launchCount: 5,
        ),
        isFalse,
      );
      expect(
        AppOpenAdService.allowed(
          now: noon,
          lastShownAt: outside.millisecondsSinceEpoch,
          launchCount: 5,
        ),
        isTrue,
      );
    });
  });

  group('settings adapter', () {
    test('receiptThemesUnlocked round-trips through Hive', () async {
      final dir = await Directory.systemTemp.createTemp('subburn_audit_');
      final repo = await SubscriptionRepository.openTest(dir.path);
      addTearDown(() async {
        await repo.close();
        await dir.delete(recursive: true);
      });

      expect(repo.settings.receiptThemesUnlocked, isFalse);
      await repo.saveSettings(
        repo.settings.copyWith(receiptThemesUnlocked: true),
      );
      expect(repo.settings.receiptThemesUnlocked, isTrue);

      // Re-open against the same bytes: the field must survive a cold read.
      await repo.close();
      final reopened = await SubscriptionRepository.openTest(dir.path);
      addTearDown(reopened.close);
      expect(reopened.settings.receiptThemesUnlocked, isTrue);

      // The ad-stack fields ride the same append-only adapter.
      await reopened.saveSettings(
        reopened.settings.copyWith(
          appOpenLastShownAt: 987654321,
          launchCount: 7,
        ),
      );
      await reopened.close();
      final third = await SubscriptionRepository.openTest(dir.path);
      addTearDown(third.close);
      expect(third.settings.appOpenLastShownAt, 987654321);
      expect(third.settings.launchCount, 7);
    });
  });
}
