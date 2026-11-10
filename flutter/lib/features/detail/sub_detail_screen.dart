import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand_icons.dart';
import '../../core/clock.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../data/models/usage_guilt.dart';
import '../../state/providers.dart';
import '../../widgets/money_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/sb_header.dart';
import 'edit_subscription_sheet.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/tool_tile.dart';

/// Screen 4 — renewal alert and kill-switch.
///
/// The cancel button is deliberately not the loudest element. Shame converts
/// worse than arithmetic: "keep ₹19,920/yr" does more work than a red button.
class SubDetailScreen extends ConsumerStatefulWidget {
  const SubDetailScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<SubDetailScreen> createState() => _SubDetailScreenState();
}

class _SubDetailScreenState extends ConsumerState<SubDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider).logScreenView('subscription_detail');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final subscriptionId = widget.subscriptionId;
    final subs = ref.watch(subscriptionsProvider);
    Subscription? subscription;
    for (final s in subs) {
      if (s.id == subscriptionId) {
        subscription = s;
        break;
      }
    }

    if (subscription == null) {
      return Scaffold(
        backgroundColor: context.sb.bg,
        body: Center(
          child: Text(
            'This subscription is gone.',
            style: TextStyle(color: context.sb.textSecondary),
          ),
        ),
      );
    }

    final settings = ref.watch(settingsProvider);
    final rates = ref.watch(ratesProvider);
    final currency = settings.displayCurrency;

    return Scaffold(
      backgroundColor: context.sb.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SbSpace.page,
                  SbSpace.x2,
                  SbSpace.page,
                  SbSpace.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SbHeader(
                      title: 'Subscription',
                      subtitle: subscription.name,
                      onBack: () => Navigator.of(context).maybePop(),
                      trailing: _DetailMenu(
                        onEdit: () => EditSubscriptionSheet.show(
                          context,
                          subscription!,
                        ),
                        onDelete: () =>
                            _confirmDelete(context, ref, subscription!),
                      ),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _IdentityCard(
                      subscription: subscription,
                      onEdit: () => EditSubscriptionSheet.show(
                        context,
                        subscription!,
                      ),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _RenewalAlert(subscription: subscription),
                    const SizedBox(height: SbSpace.x2),
                    _SpendCard(
                      subscription: subscription,
                      currency: currency,
                      inrPerUsd: rates.inrPerUsd,
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _RowCard(
                      title: 'Next charge',
                      subtitle:
                          '${formatChargeDate(subscription.nextBillingDate)} · tap to correct',
                      trailing: const StatusBadge('EDIT', tone: BadgeTone.neutral),
                      onTap: () => _pickNextCharge(context, ref, subscription!),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _RowCard(
                      title: 'Subscription start',
                      subtitle:
                          '${formatChargeDate(subscription.startDate)} · drives lifetime spend',
                      trailing: const StatusBadge('EDIT', tone: BadgeTone.neutral),
                      onTap: () => _pickStartDate(context, ref, subscription!),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _RowCard(
                      title: 'Usage guilt',
                      subtitle: subscription.isGhost
                          ? 'Marked as barely used. Counted as ghost spend.'
                          : 'Marked as daily driver. Counted as active use.',
                      trailing: StatusBadge(
                        subscription.guilt.label.toUpperCase(),
                        tone: subscription.isGhost
                            ? BadgeTone.warn
                            : BadgeTone.safe,
                        leadingDot: true,
                      ),
                      onTap: () {
                        final next = subscription!.isGhost
                            ? UsageGuilt.dailyDriver
                            : UsageGuilt.barelyTouch;
                        ref.read(subscriptionsProvider.notifier).update(
                              subscription.copyWith(guilt: next),
                            );
                      },
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _RowCard(
                      title: 'Renewal reminder',
                      subtitle:
                          'Local push · 48h and 24h before the charge',
                      trailing: Switch.adaptive(
                        value: subscription.remindersEnabled &&
                            settings.notificationsEnabled,
                        onChanged: (value) async {
                          if (value && !settings.notificationsEnabled) {
                            await ref
                                .read(settingsProvider.notifier)
                                .setNotifications(true);
                          }
                          await ref
                              .read(subscriptionsProvider.notifier)
                              .setReminders(subscription!.id, value);
                        },
                      ),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _CancelTimeline(
                      subscription: subscription,
                      currency: currency,
                      inrPerUsd: rates.inrPerUsd,
                    ),
                  ],
                ),
              ),
            ),
            _BottomDock(
              subscription: subscription,
              onCancel: () => _openCancel(context, ref, subscription!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickNextCharge(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: subscription.nextBillingDate.isAfter(SbClock.now())
          ? subscription.nextBillingDate
          : subscription.cycle.nextAfter(subscription.startDate),
      firstDate: SbClock.now().add(const Duration(days: 1)),
      lastDate: SbClock.now().add(const Duration(days: 365 * 3)),
      helpText: 'Next charge date',
    );
    if (picked == null) return;
    await ref
        .read(subscriptionsProvider.notifier)
        .update(subscription.copyWith(nextBillingDate: picked));
  }

  Future<void> _pickStartDate(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: subscription.startDate,
      firstDate: DateTime(2000),
      lastDate: SbClock.now(),
      helpText: 'When did this subscription start?',
    );
    if (picked == null) return;
    // A start date after the stored next charge would invert the timeline and
    // make lifetime spend negative; withStartDate rolls the charge forward.
    await ref
        .read(subscriptionsProvider.notifier)
        .update(subscription.withStartDate(picked));
  }

  Future<void> _openCancel(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = subscription.cancelUrl.trim();
    final uri = Uri.tryParse(raw);
    final resolved = uri != null && uri.hasScheme && uri.host.isNotEmpty;

    await ref.read(analyticsProvider).logCancelLinkOpened(
          vendor: subscription.vendor,
          resolved: resolved,
        );

    if (!resolved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No direct cancel link saved for this one. Open the vendor’s '
              'billing page from your account settings.',
            ),
          ),
        );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the cancel page.')),
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.sb.surfaceHi,
        title: Text('Delete ${subscription.name}?', style: SbType.h3),
        content: Text(
          'This removes it from your burn on this device. It does not cancel '
          'the subscription with the vendor.',
          style: SbType.body.copyWith(color: context.sb.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(subscriptionsProvider.notifier).remove(subscription.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

/// Overflow menu in the detail header.
class _DetailMenu extends StatelessWidget {
  const _DetailMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: context.sb.surfaceHi,
      tooltip: 'More actions',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: context.sb.textSecondary,
      ),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Text(
            'Edit subscription',
            style: TextStyle(color: context.sb.text, fontSize: 13),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete subscription',
            style: TextStyle(color: context.sb.danger, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.subscription, required this.onEdit});

  final Subscription subscription;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(SbSpace.x3),
      onTap: onEdit,
      child: Row(
        children: [
          ToolTile(
            mark: subscription.monogram,
            icon: BrandIcons.resolve(
                  presetId: subscription.presetId,
                  name: subscription.name,
                  category: subscription.category,
                ),
            platform: subscription.name,
            brandColor: Color(subscription.brandColor),
            size: 42,
          ),
          const SizedBox(width: SbSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  style: SbType.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.sb.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${subscription.vendor} · ${subscription.cycle.label.toLowerCase()} · ${formatSince(subscription.startDate)}',
                  style: SbType.micro.copyWith(
                    fontSize: 8.5,
                    color: context.sb.textMuted,
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            subscription.isGhost ? 'GHOST' : 'ACTIVE',
            tone: subscription.isGhost ? BadgeTone.warn : BadgeTone.safe,
            leadingDot: true,
          ),
        ],
      ),
    );
  }
}

class _RenewalAlert extends StatelessWidget {
  const _RenewalAlert({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final remaining = subscription.timeUntilRenewal();
    final progress = subscription.noticeWindowProgress();
    final urgent = remaining.inHours < 48;

    return SurfaceCard(
      padding: const EdgeInsets.all(SbSpace.x4),
      tint: urgent ? context.sb.warn : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RENEWS IN',
                  style: SbType.label.copyWith(
                    color: urgent ? context.sb.warn : context.sb.textMuted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                MoneyText.raw(
                  formatCountdown(remaining),
                  style: SbType.moneyLg.copyWith(fontSize: 30),
                  color: urgent ? context.sb.warn : context.sb.text,
                ),
                const SizedBox(height: 4),
                Text(
                  '${subscription.currency.format(subscription.amount)} charged on '
                  '${formatChargeDate(subscription.nextBillingDate)}',
                  style: SbType.caption.copyWith(
                    fontSize: 9,
                    color: context.sb.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 62,
            height: 62,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: urgent ? context.sb.warn : context.sb.safe,
                trackColor: context.sb.border,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: SbType.micro.copyWith(
                        fontSize: 11,
                        color: context.sb.text,
                      ),
                    ),
                    Text(
                      'left',
                      style: SbType.micro.copyWith(
                        fontSize: 6.5,
                        color: context.sb.textMuted,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({
    required this.subscription,
    required this.currency,
    required this.inrPerUsd,
  });

  final Subscription subscription;
  final CurrencyCode currency;
  final double inrPerUsd;

  @override
  Widget build(BuildContext context) {
    final lifetime = subscription.lifetimeIn(currency, inrPerUsd);
    final monthly = subscription.monthlyIn(currency, inrPerUsd);
    final charges = subscription.chargeCount();

    return SurfaceCard(
      padding: const EdgeInsets.all(SbSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL SPENT SINCE SIGNUP',
            style: SbType.label.copyWith(
              color: context.sb.textMuted,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: SbSpace.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: MoneyText(
                    lifetime,
                    style: SbType.moneyLg,
                    currency: currency,
                    semanticLabel:
                        '${currency.format(lifetime)} spent since signup',
                  ),
                ),
              ),
              const SizedBox(width: SbSpace.x2),
              Text(
                charges == 1 ? '1 charge' : '$charges charges',
                style: SbType.micro.copyWith(
                  fontSize: 9,
                  color: context.sb.textMuted,
                  letterSpacing: 0.02,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'avg ${currency.format(monthly)}/mo · billed '
            '${subscription.currency.format(subscription.amount)} per '
            '${subscription.periodNoun}',
            style: SbType.caption.copyWith(
              fontSize: 9,
              color: context.sb.textSecondary,
            ),
          ),
          const SizedBox(height: SbSpace.x3),
          _SpendBars(
            charges: charges,
            color: subscription.isGhost ? context.sb.warn : context.sb.accent,
          ),
        ],
      ),
    );
  }
}

class _SpendBars extends StatelessWidget {
  const _SpendBars({required this.charges, required this.color});

  final int charges;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bars = charges.clamp(1, 14);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars; i++) ...[
            Expanded(
              child: Container(
                height: 12 + (i / bars) * 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color.withValues(alpha: i == bars - 1 ? 1 : 0.34),
                      color.withValues(alpha: i == bars - 1 ? 1 : 0.18),
                    ],
                  ),
                ),
              ),
            ),
            if (i != bars - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SbSpace.x3,
        vertical: SbSpace.x3,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SbType.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.sb.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: context.sb.textMuted,
                    letterSpacing: 0,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SbSpace.x2),
          trailing,
        ],
      ),
    );
  }
}

class _CancelTimeline extends StatelessWidget {
  const _CancelTimeline({
    required this.subscription,
    required this.currency,
    required this.inrPerUsd,
  });

  final Subscription subscription;
  final CurrencyCode currency;
  final double inrPerUsd;

  @override
  Widget build(BuildContext context) {
    final keep = subscription.yearlyIn(currency, inrPerUsd);
    final nextCharge = subscription.nextBillingDate;
    final afterCharge = subscription.cycle.advance(nextCharge);
    final today = SbClock.now();

    // Deliberately restrained: a full green panel made "cancel" the loudest
    // element on the screen, and shame converts worse than arithmetic. The
    // kept-rupees figure is the hero; the tint is a whisper.
    return SurfaceCard(
      padding: const EdgeInsets.all(SbSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IF YOU CANCEL TODAY',
                      style: SbType.label.copyWith(
                        color: context.sb.safe,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // One flexible Text.rich instead of three peers: only the
                    // first run in a Row can shrink, so the amount plus " / yr"
                    // pushed the row past the card at 320 dp.
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Keep '),
                          TextSpan(
                            text: currency.format(keep),
                            style: SbType.moneyMd.copyWith(
                              fontSize: 17,
                              color: context.sb.safe,
                            ),
                          ),
                          const TextSpan(text: ' / yr'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SbType.body.copyWith(
                        fontSize: 12,
                        color: context.sb.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge('CANCEL ANYTIME', tone: BadgeTone.safe),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          const _TimelinePoint(
            done: true,
            title: 'Now',
            detail: 'Reminder cancelled, card untouched',
          ),
          _TimelinePoint(
            title: formatChargeDate(nextCharge),
            detail:
                'No ${subscription.currency.format(subscription.amount)} charge. Nothing renews.',
          ),
          _TimelinePoint(
            title: formatChargeDate(afterCharge),
            detail: 'First month you keep the money',
            last: true,
            muted: today.isAfter(afterCharge),
          ),
        ],
      ),
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.title,
    required this.detail,
    this.done = false,
    this.last = false,
    this.muted = false,
  });

  final String title;
  final String detail;
  final bool done;
  final bool last;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? context.sb.safe : context.sb.borderHi,
                border: Border.all(
                  color: done ? context.sb.safe : context.sb.borderHi,
                ),
              ),
            ),
            if (!last)
              Container(
                width: 1,
                height: 30,
                color: context.sb.border,
              ),
          ],
        ),
        const SizedBox(width: SbSpace.x2),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : SbSpace.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SbType.micro.copyWith(
                    fontSize: 8.5,
                    color: muted ? context.sb.textMuted : context.sb.text,
                    letterSpacing: 0.05,
                  ),
                ),
                Text(
                  detail,
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: context.sb.textMuted,
                    letterSpacing: 0,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({required this.subscription, required this.onCancel});

  final Subscription subscription;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        SbSpace.page,
        SbSpace.x3,
        SbSpace.page,
        SbSpace.x2 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.sb.bg,
        border: Border(top: BorderSide(color: context.sb.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: subscription.cancelUrl.isEmpty
                  ? 'Cancel in vendor settings'
                  : 'Cancel with ${subscription.vendor}',
              icon: Icons.open_in_new_rounded,
              variant: ButtonVariant.danger,
              onPressed: onCancel,
            ),
          ),
          const SizedBox(height: SbSpace.x2),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 10,
                color: context.sb.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Opens the vendor’s official cancellation page. '
                  'SubBurn never touches your credentials.',
                  style: SbType.micro.copyWith(
                    fontSize: 7.5,
                    color: context.sb.textMuted,
                    letterSpacing: 0,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
