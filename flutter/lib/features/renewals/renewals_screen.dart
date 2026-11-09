import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../state/providers.dart';
import '../../widgets/money_text.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/tool_tile.dart';
import '../detail/sub_detail_screen.dart';

/// The renewal agenda: everything that will charge, in date order.
///
/// This is not a duplicate of the dashboard list — that one is sorted by next
/// charge too, but this view answers "what hits my card this month" with dates
/// and amounts, and nothing else.
class RenewalsScreen extends ConsumerWidget {
  const RenewalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider);
    final settings = ref.watch(settingsProvider);
    final rates = ref.watch(ratesProvider);
    final remindersOn = settings.notificationsEnabled;

    final ordered = [...subs]
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final thisMonth = ordered.where((s) {
      final now = SbClock.now();
      return s.nextBillingDate.year == now.year &&
          s.nextBillingDate.month == now.month;
    }).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SbSpace.page,
          SbSpace.x2,
          SbSpace.page,
          96,
        ),
        children: [
          Row(
            children: [
              Text('Renewals', style: SbType.h2.copyWith(color: SbColors.text)),
              const Spacer(),
              StatusBadge('$thisMonth THIS MONTH'),
            ],
          ),
          const SizedBox(height: SbSpace.x1),
          Text(
            'Every charge on the horizon, in the order your card will feel it.',
            style: SbType.body.copyWith(color: SbColors.textSecondary),
          ),
          const SizedBox(height: SbSpace.x4),
          // Neutral surface: the green icon and switch carry the state. A full
          // green panel here fought the amber countdowns directly below it.
          SurfaceCard(
            child: Row(
              children: [
                Icon(
                  remindersOn
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 16,
                  color: remindersOn ? SbColors.safe : SbColors.warn,
                ),
                const SizedBox(width: SbSpace.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remindersOn
                            ? 'Reminders are on'
                            : 'Reminders are off',
                        style: SbType.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SbColors.text,
                        ),
                      ),
                      Text(
                        '48 hours and 24 hours before every charge.',
                        style: SbType.micro.copyWith(
                          fontSize: 8,
                          color: SbColors.textMuted,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: remindersOn,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setNotifications(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: SbSpace.x4),
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: SbSpace.x8),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 28,
                    color: SbColors.textMuted,
                  ),
                  const SizedBox(height: SbSpace.x2),
                  Text(
                    'No renewals to worry about.',
                    style: SbType.body.copyWith(color: SbColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final sub in ordered) ...[
              _RenewalRow(
                subscription: sub,
                currency: settings.displayCurrency,
                inrPerUsd: rates.inrPerUsd,
              ),
              const SizedBox(height: SbSpace.x2),
            ],
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget {
  const _RenewalRow({
    required this.subscription,
    required this.currency,
    required this.inrPerUsd,
  });

  final Subscription subscription;
  final CurrencyCode currency;
  final double inrPerUsd;

  @override
  Widget build(BuildContext context) {
    final remaining = subscription.timeUntilRenewal();
    final urgent = remaining.inHours < 48;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SbSpace.x3,
        vertical: SbSpace.x3,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubDetailScreen(subscriptionId: subscription.id),
        ),
      ),
      child: Row(
        children: [
          ToolTile(
            mark: subscription.monogram,
            brandColor: Color(subscription.brandColor),
            size: 32,
          ),
          const SizedBox(width: SbSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  style: SbType.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SbColors.text,
                  ),
                ),
                Text(
                  '${formatChargeDate(subscription.nextBillingDate)} · ${formatCountdownLeft(remaining)}',
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: urgent ? const Color(0xFFFBBF24) : SbColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                subscription.monthlyIn(currency, inrPerUsd),
                style: SbType.moneySm,
                currency: currency,
              ),
              Text(
                '/mo',
                style: SbType.micro.copyWith(
                  fontSize: 7,
                  color: SbColors.textMuted,
                  letterSpacing: 0.06,
                ),
              ),
            ],
          ),
          const SizedBox(width: SbSpace.x2),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              subscription.remindersEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 13,
              color: subscription.remindersEnabled
                  ? SbColors.safe
                  : SbColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
