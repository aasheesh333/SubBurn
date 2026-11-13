import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';
import '../../core/dev_store.dart';
import '../../core/motion.dart';
import '../../core/theme/theme_tokens.dart';
import '../../data/models/currency.dart';
import '../../data/models/theme_preference.dart';
import '../../services/ads_bootstrap.dart';
import '../../services/ads_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/catalogue_service.dart';
import '../../state/providers.dart';
import '../legal/legal_page.dart';
import '../../widgets/segment_pills.dart';
import '../../widgets/sb_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/surface_card.dart';

/// Controls: the handful of switches that change how the numbers read.
/// Everything here acts immediately and is stored on the device.
class ControlsScreen extends ConsumerStatefulWidget {
  const ControlsScreen({super.key});

  @override
  ConsumerState<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends ConsumerState<ControlsScreen> {
  /// Read from the installed package, not typed into the source.
  String _version = '';

  @override
  void initState() {
    super.initState();
    // Fails on a platform without the plugin (tests, desktop). The About row
    // simply omits the version instead of throwing.
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _version = info.buildNumber.isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
      });
    }).catchError((Object error) {
      debugPrint('PackageInfo unavailable: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(catalogueProvider);
    final catalogue = snapshot.value?.catalogue;
    final refreshing = ref.watch(catalogueRefreshingProvider);
    final health = ref.watch(reminderHealthProvider);
    final ads = ref.watch(adsServiceProvider);

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
          SbHeader(
            title: 'Controls',
            subtitle: 'Local-first settings',
            trailing: StatusBadge(_version.isEmpty ? 'LOCAL' : 'v$_version'),
          ),
          const SizedBox(height: SbSpace.x4),
          _Group(
            title: 'Appearance',
            children: [
              _SettingRow(
                title: 'Theme',
                subtitle: 'Device follows your phone\'s light or dark setting. '
                    'A manual choice is remembered on this device.',
                child: SizedBox(
                  width: 190,
                  child: SegmentPills<ThemePreference>(
                    values: ThemePreference.values,
                    selected: settings.themePreference,
                    labelOf: (p) => p.label,
                    onChanged: (p) =>
                        ref.read(settingsProvider.notifier).setTheme(p),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'Display',
            children: [
              _SettingRow(
                title: 'Currency',
                subtitle:
                    'Amounts are stored as charged; totals convert at the live '
                    'USD→INR rate, refreshed daily.',
                child: SizedBox(
                  width: 168,
                  child: SegmentPills<CurrencyCode>(
                    values: CurrencyCode.values,
                    selected: settings.displayCurrency,
                    labelOf: (c) => c.code,
                    onChanged: (c) =>
                        ref.read(settingsProvider.notifier).setCurrency(c),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'Alerts',
            children: [
              _SettingRow(
                title: 'Renewal reminders',
                subtitle:
                    'Alerts 48 h and 24 h before a charge. Scheduled on this '
                    'device; no special alarm access requested.',
                child: Switch.adaptive(
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
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
                  },
                ),
              ),
              _ReminderDiagnostics(
                health: health,
                onGrant: () async {
                  // Two different fixes: the channel/notification toggle lives
                  // in system settings (a re-prompt is silently refused after
                  // two declines), while a plain permission prompt can still be
                  // answered inline.
                  await ref
                      .read(notificationServiceProvider)
                      .openNotificationSettings();
                  await ref
                      .read(settingsProvider.notifier)
                      .setNotifications(true);
                  await ref
                      .read(subscriptionsProvider.notifier)
                      .rescheduleAll();
                },
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'Preset catalogue',
            children: [
              _SettingRow(
                title: '${catalogue?.tools.length ?? 0} tools',
                subtitle: snapshot.value == null
                    ? 'Loading the catalogue…'
                    : 'Source: ${_sourceLabel(snapshot.value!.source)} · '
                        'refreshed ${_relative(snapshot.value!.catalogue.fetchedAt)}',
                child: (snapshot.isLoading || refreshing)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : TextButton(
                        onPressed: () =>
                            ref.read(catalogueProvider.notifier).refresh(),
                        child: const Text('REFRESH'),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SbSpace.x3,
                  SbSpace.x1,
                  SbSpace.x3,
                  SbSpace.x3,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 12,
                      color: context.sb.safe,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Fetched from our server and cached for 7 days. The '
                        'bundled copy covers you offline.',
                        style: SbType.micro.copyWith(
                          fontSize: 9,
                          color: context.sb.textMuted,
                          letterSpacing: 0,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'Ads',
            children: [
              _SettingRow(
                title: ads.enabled ? 'Ads enabled' : 'No ads',
                subtitle: ads.enabled
                    ? 'One banner above the navigation bar, an app-open ad on '
                        'some launches (capped at one per 3 hours), and '
                        'opt-in rewarded videos. No interstitials, no ads '
                        'while you are editing or sharing.'
                    : 'This build shows no advertising.',
                child: StatusBadge(
                  ads.enabled ? 'ON' : 'OFF',
                  tone: ads.enabled ? BadgeTone.warn : BadgeTone.safe,
                  leadingDot: true,
                ),
              ),
              if (ads.enabled)
                _SettingRow(
                  title: 'Ad privacy',
                  subtitle: 'Change or withdraw your ad consent at any time.',
                  child: TextButton(
                    onPressed: () async {
                      final shown = await AdsBootstrap.showPrivacyOptions();
                      // Outside the EEA/UK (and before consent info loads) no
                      // form applies — say so instead of being a dead button.
                      if (shown || !context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No ad-consent choice is required in your region, '
                              'so there is nothing to change.',
                            ),
                          ),
                        );
                    },
                    child: const Text('MANAGE'),
                  ),
                ),
              if (ads.canShowRewarded)
                _SettingRow(
                  title: 'Support the developer',
                  subtitle: 'One optional rewarded ad. No reward except our '
                      'gratitude — SubBurn stays fully free either way.',
                  child: TextButton(
                    onPressed: () => _watchRewarded(
                      context,
                      ref,
                      success: 'Thank you. That one genuinely helps.',
                    ),
                    child: const Text('WATCH'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'More from ${DevStore.publisher}',
            children: [
              for (final app in DevStore.featured)
                _SettingRow(
                  title: app.name,
                  subtitle: app.tagline,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Share ${app.name}',
                        child: IconButton(
                          tooltip: 'Share ${app.name}',
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: DevStore.shareText(app),
                              subject: app.name,
                            ),
                          ),
                          icon: Icon(
                            Icons.ios_share_rounded,
                            size: 16,
                            color: context.sb.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openSibling(context, app.playUrl),
                        child: const Text('VIEW'),
                      ),
                    ],
                  ),
                ),
              _SettingRow(
                title: 'All apps by ${DevStore.publisher}',
                subtitle: 'The full catalogue on the Play Store.',
                child: TextButton(
                  onPressed: () => _openSibling(context, DevStore.storeUrl),
                  child: const Text('OPEN'),
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'Your data',
            children: [
              const _SettingRow(
                title: 'Stored on this device',
                subtitle:
                    'Hive database, never uploaded. Deleting the app deletes the list.',
                child: StatusBadge('LOCAL', tone: BadgeTone.safe),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SbSpace.x3,
                  0,
                  SbSpace.x3,
                  SbSpace.x3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmClear(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.sb.danger,
                          side: BorderSide(
                            color: context.sb.danger.withValues(alpha: 0.4),
                          ),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SbRadius.button),
                          ),
                        ),
                        child: const Text('DELETE ALL SUBSCRIPTIONS'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          _Group(
            title: 'About',
            children: [
              _SettingRow(
                title: 'About SubBurn',
                subtitle: _version.isEmpty
                    ? 'Built for people with too many tabs.'
                    : 'Version $_version · ${AppLinks.publisher}',
                child: TextButton(
                  onPressed: () => _openLegal(context, LegalDoc.about),
                  child: const Text('OPEN'),
                ),
              ),
              _SettingRow(
                title: 'Privacy',
                subtitle: 'What is stored on device and what is sent',
                child: TextButton(
                  onPressed: () => _openLegal(context, LegalDoc.privacy),
                  child: const Text('READ'),
                ),
              ),
              _SettingRow(
                title: 'Terms of use',
                subtitle: 'Licence, cancellation links, no financial advice',
                child: TextButton(
                  onPressed: () => _openLegal(context, LegalDoc.terms),
                  child: const Text('READ'),
                ),
              ),
              _SettingRow(
                title: 'Licences',
                subtitle: 'Open-source packages, fonts and brand marks',
                child: TextButton(
                  onPressed: () => _openLegal(context, LegalDoc.licenses),
                  child: const Text('VIEW'),
                ),
              ),
              _SettingRow(
                title: 'Support',
                subtitle: AppLinks.supportEmail,
                child: TextButton(
                  onPressed: () => launchUrl(
                    AppLinks.supportEmailUri,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('EMAIL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: SbSpace.x3),
          Text(
            'The roast is generated on-device from your own numbers. It is a '
            'joke, not financial advice.',
            textAlign: TextAlign.center,
            style: SbType.micro.copyWith(
              fontSize: 9,
              color: context.sb.textMuted,
              letterSpacing: 0,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static String _sourceLabel(CatalogueSource source) => switch (source) {
        CatalogueSource.cdn => 'server',
        CatalogueSource.cache => 'cached copy',
        CatalogueSource.bundled => 'offline copy',
      };

  static String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.sb.surfaceHi,
        title: const Text('Delete all subscriptions?', style: SbType.h3),
        content: Text(
          'This clears the local database. Cancelling with vendors is up to you.',
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
      await ref.read(subscriptionsProvider.notifier).clearAll();
    }
  }

  static void _openLegal(BuildContext context, LegalDoc doc) {
    Navigator.of(context).push(
      SbPageRoute<void>(builder: (_) => LegalPage(doc: doc)),
    );
  }
}

/// Honest reminder state: is the OS allowed to deliver, and how many alarms are
/// actually queued. Without this the only symptom of a blocked permission was
/// "reminders don't work".
class _ReminderDiagnostics extends StatelessWidget {
  const _ReminderDiagnostics({
    required this.health,
    required this.onGrant,
  });

  final AsyncValue<ReminderHealth> health;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final value = health.value;
    final blocked = value?.blockedByOs ?? false;
    final channelOff = value?.blockedByChannel ?? false;
    final pending = value?.pending ?? 0;
    final status = value == null
        ? 'Checking…'
        : channelOff
            // App notifications are allowed, but this app's own channel was
            // silenced — Android reports the app as enabled in that state, so
            // the old copy claimed ACTIVE while nothing could be delivered.
            ? 'This app’s reminder channel is turned off in system settings'
            : blocked
                ? 'Notifications are blocked for SubBurn in system settings'
                : pending > 0
                    ? '$pending reminder${pending == 1 ? '' : 's'} queued'
                    : 'Ready · none queued yet';

    return Column(
      children: [
        _SettingRow(
          title: 'Status',
          subtitle: status,
          child: StatusBadge(
            blocked ? 'BLOCKED' : (pending > 0 ? 'ACTIVE' : 'IDLE'),
            tone: blocked
                ? BadgeTone.danger
                : (pending > 0 ? BadgeTone.safe : BadgeTone.neutral),
            leadingDot: true,
          ),
        ),
        // ALLOW is a fix-it action for a blocked OS permission, so it stays.
        // The old SEND TEST / RE-ARM buttons were development diagnostics and
        // have no place in a production build.
        if (blocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SbSpace.x3,
              0,
              SbSpace.x3,
              SbSpace.x3,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onGrant,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.sb.danger,
                  side: BorderSide(
                      color: context.sb.danger.withValues(alpha: 0.4)),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(channelOff ? 'TURN ON' : 'ALLOW'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: SbSpace.x2),
          child: Text(
            title.toUpperCase(),
            style:
                SbType.label.copyWith(color: context.sb.textMuted, fontSize: 9),
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, color: context.sb.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SbSpace.x3),
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
                    fontSize: 9,
                    color: context.sb.textMuted,
                    letterSpacing: 0,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SbSpace.x2),
          child,
        ],
      ),
    );
  }
}

/// Runs one opt-in rewarded ad and reports the outcome honestly.
///
/// Shared by every rewarded entry point (theme unlock has its own older call
/// site in the studio): the reward is applied only when the SDK confirms it
/// was earned, and a missing ad is reported rather than hidden.
Future<void> _watchRewarded(
  BuildContext context,
  WidgetRef ref, {
  required String success,
  VoidCallback? onReward,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(rewardedAdServiceProvider);
  await service.load();
  if (!context.mounted) return;
  final rewarded = await service.show(
    onReward: () {
      if (!context.mounted) return;
      onReward?.call();
    },
  );
  if (!context.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          rewarded ? success : 'No ad was available — nothing changed.',
        ),
      ),
    );
}

/// Opens a Play Store page. Failures get a snackbar instead of a silent
/// dead tap — the same contract as the cancel-link launcher.
Future<void> _openSibling(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
  } catch (error) {
    debugPrint('Play Store link failed: $error');
  }
  if (!launched && context.mounted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store page.')),
      );
  }
}
