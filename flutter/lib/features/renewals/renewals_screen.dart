import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand_icons.dart';
import '../../core/clock.dart';
import '../../core/motion.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../state/providers.dart';
import '../../widgets/money_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sb_header.dart';
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
  const RenewalsScreen({super.key, this.onAddSubscription});

  /// Provided by the shell so the empty state is not a dead end.
  final VoidCallback? onAddSubscription;

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
      child: RefreshIndicator(
        color: context.sb.accent,
        backgroundColor: context.sb.surfaceHi,
        onRefresh: () async {
          ref.read(subscriptionsProvider.notifier).refresh();
          await ref.read(subscriptionsProvider.notifier).rescheduleAll();
          ref.invalidate(reminderHealthProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SbSpace.page,
            SbSpace.x2,
            SbSpace.page,
            96,
          ),
          children: [
            SbHeader(
              title: 'Renewals',
              subtitle: 'Upcoming charges',
              trailing: StatusBadge('$thisMonth THIS MONTH'),
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
                    color: remindersOn ? context.sb.safe : context.sb.warn,
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
                            color: context.sb.text,
                          ),
                        ),
                        Text(
                          '48 hours and 24 hours before every charge.',
                          style: SbType.micro.copyWith(
                            fontSize: 9,
                            color: context.sb.textMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: remindersOn,
                    onChanged: (value) async {
                      // setNotifications returns whether reminders are actually
                      // deliverable. Discarding it here meant Android could block
                      // the permission and the switch would just flip back with
                      // no explanation (Controls already handled this).
                      final ok = await ref
                          .read(settingsProvider.notifier)
                          .setNotifications(value);
                      if (!context.mounted) return;
                      if (value && !ok) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Your system is blocking notifications. Allow '
                                'SubBurn in system settings, then turn this on '
                                'again.',
                              ),
                            ),
                          );
                      }
                      // No rescheduleAll here: setNotifications(true) already
                      // re-arms every reminder internally — the duplicate call
                      // doubled every cancel+schedule platform round-trip.
                    },
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
                    Icon(
                      Icons.event_available_rounded,
                      size: 28,
                      color: context.sb.textMuted,
                    ),
                    const SizedBox(height: SbSpace.x2),
                    Text(
                      'No renewals to worry about.',
                      style:
                          SbType.body.copyWith(color: context.sb.textSecondary),
                    ),
                    const SizedBox(height: SbSpace.x1),
                    Text(
                      // `ordered` is a copy of `subs`, so inside this branch the
                      // ledger is always empty — the old ternary's second string
                      // was unreachable.
                      'Add a subscription and its charges appear here.',
                      textAlign: TextAlign.center,
                      style: SbType.micro.copyWith(
                        fontSize: 9,
                        color: context.sb.textMuted,
                        letterSpacing: 0,
                        height: 1.5,
                      ),
                    ),
                    if (subs.isEmpty && onAddSubscription != null) ...[
                      const SizedBox(height: SbSpace.x4),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Add a subscription',
                          icon: Icons.add_rounded,
                          onPressed: onAddSubscription,
                        ),
                      ),
                    ],
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
        SbPageRoute<void>(
          builder: (_) => SubDetailScreen(subscriptionId: subscription.id),
        ),
      ),
      child: Row(
        children: [
          ToolTile(
            mark: subscription.monogram,
            icon: BrandIcons.resolve(
              presetId: subscription.presetId,
              name: subscription.name,
              category: subscription.category,
            ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.sb.text,
                  ),
                ),
                Text(
                  '${formatChargeDate(subscription.nextBillingDate)} · ${formatCountdownLeft(remaining)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.micro.copyWith(
                    fontSize: 9,
                    color: urgent ? context.sb.warn : context.sb.textMuted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          // Shrinks as a block when the row is tight (320 dp at 200 % text):
          // an intrinsic money column used to push the row 16 px past the card.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
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
                      color: context.sb.textMuted,
                      letterSpacing: 0.06,
                    ),
                  ),
                ],
              ),
            ),
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
                  ? context.sb.safe
                  : context.sb.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
