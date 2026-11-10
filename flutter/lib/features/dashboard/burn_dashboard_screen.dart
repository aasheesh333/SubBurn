import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/motion.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/subscription.dart';
import '../../state/providers.dart';
import '../../widgets/burn_hero_card.dart';
import '../../widgets/money_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_badge.dart';
import '../../core/brand_icons.dart';
import '../../widgets/sb_header.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/tool_tile.dart';
import '../detail/sub_detail_screen.dart';

/// Screen 1 — the burn dashboard.
///
/// Answers one question in under a second: how much am I burning, and how much
/// of it is ghost spend. The hero number is the product; everything below is a
/// supporting argument.
class BurnDashboardScreen extends ConsumerStatefulWidget {
  const BurnDashboardScreen({
    super.key,
    required this.onAddSubscription,
  });

  final VoidCallback onAddSubscription;

  @override
  ConsumerState<BurnDashboardScreen> createState() =>
      _BurnDashboardScreenState();
}

class _BurnDashboardScreenState extends ConsumerState<BurnDashboardScreen> {
  /// Ghost-only filter, toggled by the callout's REVIEW action. Without it the
  /// callout was a label that looked tappable and did nothing.
  bool _ghostOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider).logScreenView('dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(burnSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final allSubscriptions = ref.watch(subscriptionsProvider);
    final subscriptions = _ghostOnly
        ? allSubscriptions.where((s) => s.isGhost).toList(growable: false)
        : allSubscriptions;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: context.sb.accent,
        backgroundColor: context.sb.surfaceHi,
        onRefresh: () => ref.read(catalogueProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SbSpace.page,
                SbSpace.x2,
                SbSpace.page,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: SbHeader(
                  title: '',
                  showLogo: true,
                  trailing: _CurrencyChip(
                    currency: settings.displayCurrency,
                  onToggleCurrency: () {
                    final next = settings.displayCurrency == CurrencyCode.inr
                        ? CurrencyCode.usd
                        : CurrencyCode.inr;
                      ref.read(settingsProvider.notifier).setCurrency(next);
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SbSpace.page,
                SbSpace.x4,
                SbSpace.page,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: BurnHeroCard(
                  monthlyTotal: summary.monthly,
                  activeAmount: summary.activeMonthly,
                  ghostAmount: summary.ghostMonthly,
                  toolCount: summary.count,
                  currency: settings.displayCurrency,
                  delta: _monthDelta(
                    subscriptions,
                    settings.displayCurrency,
                    ref.watch(ratesProvider).inrPerUsd,
                  ),
                ),
              ),
            ),
            if (subscriptions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onAdd: widget.onAddSubscription),
              )
            else ...[
              const SliverToBoxAdapter(child: SizedBox(height: SbSpace.x5)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: SbSpace.page),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Renewing soon',
                    badge: StatusBadge(
                      '${SbWindow.renewingHours}H WINDOW',
                      tone: BadgeTone.warn,
                      leadingDot: true,
                      pulse: summary.dueSoon.any(
                        (s) => s.timeUntilRenewal().inHours < 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: SbSpace.x2)),
              SliverToBoxAdapter(
                child: _RenewingRail(
                  subscriptions: _ghostOnly
                      ? summary.dueSoon
                          .where((s) => s.isGhost)
                          .toList(growable: false)
                      : summary.dueSoon,
                  currency: settings.displayCurrency,
                  inrPerUsd: ref.watch(ratesProvider).inrPerUsd,
                  onOpen: _openDetail,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: SbSpace.x4)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: SbSpace.page),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: _ghostOnly ? 'Ghost subscriptions' : 'Subscriptions',
                    badge: _ghostOnly
                        ? StatusBadge(
                            '${summary.ghostCount} GHOST',
                            tone: BadgeTone.warn,
                          )
                        : StatusBadge('${summary.count} TOOLS'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: SbSpace.x2)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: SbSpace.page),
                sliver: SliverList.separated(
                  itemCount: subscriptions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: SbSpace.x2),
                  itemBuilder: (context, index) {
                    final sub = subscriptions[index];
                    return SbEntrance(
                      index: index,
                      child: _SubscriptionRow(
                      key: ValueKey(sub.id),
                      subscription: sub,
                      currency: settings.displayCurrency,
                      inrPerUsd: ref.watch(ratesProvider).inrPerUsd,
                      onTap: () => _openDetail(sub),
                        onDelete: () => _delete(context, ref, sub),
                      ),
                    );
                  },
                ),
              ),
              if (summary.ghostCount > 0) ...[
                const SliverToBoxAdapter(child: SizedBox(height: SbSpace.x3)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: SbSpace.page),
                  sliver: SliverToBoxAdapter(
                    child: _GhostCallout(
                      percent: summary.ghostShare * 100,
                      count: summary.ghostCount,
                      yearly: summary.currency.format(summary.ghostYearly),
                      active: _ghostOnly,
                      onTap: () => setState(() => _ghostOnly = !_ghostOnly),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(Subscription subscription) {
    Navigator.of(context).push(
      SbPageRoute<void>(
        builder: (_) => SubDetailScreen(subscriptionId: subscription.id),
      ),
    );
  }

  /// Month-over-month delta is derived from the data we have: the part of the
  /// monthly burn that belongs to tools started inside the last 30 days. It is
  /// honest about what it can know, and hidden when it would be zero.
  static double? _monthDelta(
    List<Subscription> subs,
    CurrencyCode currency,
    double inrPerUsd,
  ) {
    final cutoff = SbClock.now().subtract(const Duration(days: 30));
    final recent = subs.where((s) => s.startDate.isAfter(cutoff)).toList();
    if (recent.isEmpty) return null;
    return recent.fold<double>(
      0,
      (sum, s) => sum + s.monthlyIn(currency, inrPerUsd),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(subscriptionsProvider.notifier).remove(subscription.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${subscription.name} removed'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              ref.read(subscriptionsProvider.notifier).restore(subscription);
            },
          ),
        ),
      );
  }
}

/// Currency chip: the dashboard's only header affordance.
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.currency, required this.onToggleCurrency});

  final CurrencyCode currency;
  final VoidCallback onToggleCurrency;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Display currency: ${currency.code}. Tap to switch.',
      child: InkWell(
        onTap: onToggleCurrency,
        borderRadius: BorderRadius.circular(SbRadius.pill),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SbRadius.pill),
            color: context.sb.surface,
            border: Border.all(color: context.sb.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LiveDot(),
              const SizedBox(width: 5),
              Text(
                '${currency.code} · BURN',
                style: SbType.micro.copyWith(
                  fontSize: 8,
                  color: context.sb.textSecondary,
                  letterSpacing: 0.08,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                size: 11,
                color: context.sb.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: context.sb.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.sb.accent.withValues(alpha: 0.35),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badge});

  final String title;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SbType.section.copyWith(color: context.sb.text),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: SbSpace.x2),
          badge!,
        ],
      ],
    );
  }
}

class _RenewingRail extends StatelessWidget {
  const _RenewingRail({
    required this.subscriptions,
    required this.currency,
    required this.inrPerUsd,
    required this.onOpen,
  });

  final List<Subscription> subscriptions;
  final CurrencyCode currency;
  final double inrPerUsd;
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SbSpace.page),
        child: SurfaceCard(
          height: 64,
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: context.sb.safe,
              ),
              const SizedBox(width: SbSpace.x2),
              Expanded(
                child: Text(
                  'Nothing renews in the next ${SbWindow.renewingHours} hours.',
                  style: SbType.caption.copyWith(color: context.sb.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      // Figma draws the rail at 104 px. That is a text-size-dependent box, so
      // it grows with the OS text scale instead of clipping its cards.
      height: 104 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 56,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.86, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // The mask fades the trailing card, but text must still be cut by the
          // card, not by the viewport. Extra trailing padding keeps the last
          // visible card clear of the fade.
          padding: const EdgeInsets.only(
            left: SbSpace.page,
            right: SbSpace.page + 48,
          ),
          itemCount: subscriptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: SbSpace.x2),
          itemBuilder: (context, index) => SbEntrance(
            index: index,
            child: _RenewalCard(
              subscription: subscriptions[index],
              currency: currency,
              inrPerUsd: inrPerUsd,
              onTap: () => onOpen(subscriptions[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({
    required this.subscription,
    required this.currency,
    required this.inrPerUsd,
    required this.onTap,
  });

  final Subscription subscription;
  final CurrencyCode currency;
  final double inrPerUsd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = subscription.timeUntilRenewal();
    final urgent = remaining.inHours < 24;

    return SizedBox(
      width: 148,
      child: SurfaceCard(
        // 9 instead of 11: three stacked bands (tile, price, badge) plus text
        // rounding need 4 px of slack inside the Figma 104 px rail, and a
        // 0.03 px overflow still trips the debug assert.
        padding: const EdgeInsets.all(9),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                  size: 28,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SbType.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          color: context.sb.text,
                        ),
                      ),
                      Text(
                        'Renews ${formatRenewalDay(subscription.nextBillingDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: SbType.micro.copyWith(
                          fontSize: 7.5,
                          color: context.sb.textMuted,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              currency.format(subscription.monthlyIn(currency, inrPerUsd)),
              style: SbType.moneyMd.copyWith(color: context.sb.text),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                formatCountdownLeft(remaining),
                tone: urgent ? BadgeTone.warn : BadgeTone.neutral,
                leadingDot: true,
                pulse: urgent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    super.key,
    required this.subscription,
    required this.currency,
    required this.inrPerUsd,
    required this.onTap,
    required this.onDelete,
  });

  final Subscription subscription;
  final CurrencyCode currency;
  final double inrPerUsd;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${subscription.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: SbSpace.x5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SbRadius.inner),
          color: context.sb.danger.withValues(alpha: 0.12),
          border: Border.all(color: context.sb.danger.withValues(alpha: 0.34)),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: context.sb.danger,
          size: 18,
        ),
      ),
      child: Semantics(
        button: true,
        label:
            '${subscription.name}, ${subscription.currency.format(subscription.amount)} per ${subscription.cycle.label.toLowerCase()}, '
            '${subscription.guilt.label}. Opens detail.',
        child: SurfaceCard(
          // Figma: SubRow is 44 px high with an 8 px gap (tile pitch 52).
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: SbSpace.x3),
          dashed: subscription.isGhost,
          onTap: onTap,
          child: Row(
            children: [
              Opacity(
                opacity: subscription.isGhost ? 0.62 : 1,
                child: ToolTile(
                  mark: subscription.monogram,
                  icon: BrandIcons.resolve(
                  presetId: subscription.presetId,
                  name: subscription.name,
                  category: subscription.category,
                ),
                  platform: subscription.name,
                  brandColor: Color(subscription.brandColor),
                  size: 30,
                ),
              ),
              const SizedBox(width: SbSpace.x2 + 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SbType.body.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.sb.text,
                      ),
                    ),
                    Text(
                      subscription.vendor.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SbType.micro.copyWith(
                        fontSize: 7.5,
                        color: context.sb.textMuted,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SbSpace.x2),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    subscription.monthlyIn(currency, inrPerUsd),
                    style: SbType.moneySm.copyWith(fontSize: 12.5),
                    color: context.sb.text,
                    currency: currency,
                  ),
                  Text(
                    subscription.isGhost ? 'GHOST' : 'DAILY USE',
                    style: SbType.micro.copyWith(
                      fontSize: 7.5,
                      letterSpacing: 0.06,
                      color: subscription.isGhost
                          ? context.sb.warn
                          : context.sb.safe,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostCallout extends StatelessWidget {
  const _GhostCallout({
    required this.percent,
    required this.count,
    required this.yearly,
    required this.active,
    required this.onTap,
  });

  final double percent;
  final int count;
  final String yearly;

  /// True while the list is filtered to ghost rows.
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final whole = (percent - percent.roundToDouble()).abs() < 0.05;
    final label = whole ? percent.round().toString() : percent.toStringAsFixed(1);

    return SurfaceCard(
      // Figma: Callout/Ghost is 56 px at 1x. It grows with the text scale so
      // the two-line copy never clips at 130 %.
      height: 56 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 34,
      padding: const EdgeInsets.symmetric(horizontal: SbSpace.x3),
      tint: context.sb.warn,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: context.sb.warn.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 14,
              color: context.sb.warn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label% of your burn is ghost subs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.sb.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count tools · $yearly/yr you do not use',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: context.sb.textMuted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Text(
            active ? 'SHOW ALL' : 'REVIEW',
            style: SbType.micro.copyWith(
              fontSize: 8.5,
              color: context.sb.warn,
              letterSpacing: 0.05,
            ),
          ),
          Icon(
            active
                ? Icons.filter_alt_off_rounded
                : Icons.chevron_right_rounded,
            size: 14,
            color: context.sb.warn,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SbSpace.page,
        SbSpace.x6,
        SbSpace.page,
        SbSpace.x4,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  context.sb.accent.withValues(alpha: 0.22),
                  context.sb.accent.withValues(alpha: 0),
                ],
              ),
              border: Border.all(color: context.sb.border),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: context.sb.accentWarm,
              size: 28,
            ),
          ),
          const SizedBox(height: SbSpace.x4),
          Text(
            'Nothing burning yet',
            style: SbType.h3.copyWith(color: context.sb.text),
          ),
          const SizedBox(height: SbSpace.x1),
          Text(
            'Add your first AI or SaaS subscription and SubBurn will show you '
            'what it costs per year — and what it costs in regret.',
            textAlign: TextAlign.center,
            style: SbType.body.copyWith(color: context.sb.textSecondary),
          ),
          const SizedBox(height: SbSpace.x5),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Add a subscription',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ),
          const SizedBox(height: SbSpace.x3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 11,
                color: context.sb.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Stored on this device. No account needed.',
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    color: context.sb.textMuted,
                    letterSpacing: 0.02,
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
