import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';
import '../../core/theme/theme_tokens.dart';
import '../../data/models/currency.dart';
import '../../data/models/theme_preference.dart';
import '../../services/catalogue_service.dart';
import '../../state/providers.dart';
import '../../widgets/segment_pills.dart';
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
          Text('Controls', style: SbType.h2.copyWith(color: context.sb.text)),
          const SizedBox(height: SbSpace.x1),
          Text(
            'Local-first by design. No account, no sync, no server holding your list.',
            style: SbType.body.copyWith(color: context.sb.textSecondary),
          ),
          const SizedBox(height: SbSpace.x4),
          _Group(
            title: 'Appearance',
            children: [
              _SettingRow(
                title: 'Theme',
                subtitle:
                    'Device follows your phone\'s light or dark setting. '
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
                    'Local notifications at 48h and 24h. Inexact alarms only — no special access requested.',
                child: Switch.adaptive(
                  value: settings.notificationsEnabled,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setNotifications(value),
                ),
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
                        'Served from Cloudflare R2, cached for 7 days, with the '
                        'bundled copy as an offline fallback.',
                        style: SbType.micro.copyWith(
                          fontSize: 7.5,
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
                title: 'SubBurn',
                subtitle: _version.isEmpty
                    ? 'Built for people with too many tabs.'
                    : 'Version $_version · built for people with too many tabs.',
                child: TextButton(
                  onPressed: () => _showPrivacy(context),
                  child: const Text('PRIVACY'),
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
              fontSize: 7.5,
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
        CatalogueSource.cdn => 'live CDN',
        CatalogueSource.cache => '7-day cache',
        CatalogueSource.bundled => 'bundled offline copy',
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

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.sb.surfaceHi,
        title: const Text('Privacy', style: SbType.h3),
        content: SingleChildScrollView(
          child: Text(
            'SubBurn stores your subscriptions in a local database on this '
            'device. It does not create an account, and it does not upload your '
            'list.\n\n'
            'The app fetches a static preset catalogue and an exchange rate '
            'from a CDN. Those requests contain no subscription data.\n\n'
            'Firebase Crashlytics receives crash reports if the app fails, and '
            'analytics records two product events: "sub_added" and '
            '"roast_card_shared", with no names, prices or vendors.\n\n'
            'Push notifications are broadcast-only via OneSignal, keyed to a '
            'random install id.\n\n'
            'Deleting the app deletes everything SubBurn knows about you.',
            style: SbType.body.copyWith(
              color: context.sb.textSecondary,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              launchUrl(
                AppLinks.privacyPolicyUri,
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('READ ONLINE'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
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
            style: SbType.label.copyWith(color: context.sb.textMuted, fontSize: 9),
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
                    fontSize: 8,
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
