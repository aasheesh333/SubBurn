import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';
import '../../core/theme/theme_tokens.dart';
import '../../widgets/logo_mark.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/sb_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/surface_card.dart';

/// The legal / store pages Play expects an app to expose.
///
/// Everything here is reachable from Controls, and every page works offline
/// except the two that open a hosted document. Keeping the in-app copy means a
/// user never needs a browser to understand what the app does with their data.
enum LegalDoc { about, privacy, terms, licenses }

class LegalPage extends ConsumerStatefulWidget {
  const LegalPage({super.key, required this.doc});

  final LegalDoc doc;

  String get title => switch (doc) {
        LegalDoc.about => 'About SubBurn',
        LegalDoc.privacy => 'Privacy',
        LegalDoc.terms => 'Terms of use',
        LegalDoc.licenses => 'Licences',
      };

  @override
  ConsumerState<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends ConsumerState<LegalPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      backgroundColor: context.sb.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SbSpace.page,
            SbSpace.x2,
            SbSpace.page,
            SbSpace.x6,
          ),
          children: [
            SbHeader(
              title: widget.title,
              onBack: () => Navigator.of(context).maybePop(),
              trailing: StatusBadge(
                widget.doc == LegalDoc.licenses ? 'OSS' : 'LEGAL',
              ),
            ),
            const SizedBox(height: SbSpace.x4),
            switch (widget.doc) {
              LegalDoc.about => _About(version: _version),
              LegalDoc.privacy => const _PrivacyBody(),
              LegalDoc.terms => const _TermsBody(),
              LegalDoc.licenses => _LicensesBody(version: _version),
            },
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SbSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style:
                SbType.label.copyWith(color: context.sb.textMuted, fontSize: 9),
          ),
          const SizedBox(height: SbSpace.x2),
          SurfaceCard(
            padding: const EdgeInsets.all(SbSpace.x4),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: SbType.body.copyWith(
          color: context.sb.textSecondary,
          height: 1.6,
        ),
      );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.sb.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: SbType.body.copyWith(
                      color: context.sb.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.url,
    this.icon = Icons.open_in_new_rounded,
  });

  final String label;
  final Uri url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(SbRadius.button),
      child: PressScale(
        child: Container(
          height: SbSize.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: SbSpace.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SbRadius.button),
            border: Border.all(color: context.sb.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: SbType.body.copyWith(
                    fontSize: 12,
                    color: context.sb.text,
                  ),
                ),
              ),
              Icon(icon, size: 13, color: context.sb.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Same 48 px slot as the old flame tile, now the launcher artwork.
            const SbLogoMark(size: 48),
            const SizedBox(width: SbSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SubBurn',
                      style: SbType.h3.copyWith(color: context.sb.text)),
                  Text(
                    version.isEmpty
                        ? AppLinks.publisher
                        : 'v$version · ${AppLinks.publisher}',
                    style: SbType.micro.copyWith(
                      fontSize: 9,
                      color: context.sb.textMuted,
                      letterSpacing: 0.04,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SbSpace.x4),
        const _Section(
          title: 'What it is',
          child: _Body(
            'SubBurn tracks the AI and SaaS subscriptions you pay for, shows '
            'which ones you actually use, and turns the yearly burn into a '
            'receipt you can share. Every figure comes from what you enter — the '
            'app never guesses a price.',
          ),
        ),
        const _Section(
          title: 'How it works',
          child: _Bullets([
            'Your subscriptions are stored only on this device, in a local database.',
            'Renewal reminders run through your phone\'s notification service.',
            'A preset catalogue and an exchange rate are fetched from our server and cached; the app also ships a copy so it works offline.',
            'The receipt is generated on-device and exported as a 1080 × 1920 PNG.',
          ]),
        ),
        _Section(
          title: 'Support',
          child: Column(
            children: [
              _LinkRow(
                label: AppLinks.supportEmail,
                url: AppLinks.supportEmailUri,
                icon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: SbSpace.x2),
              _LinkRow(label: 'Website', url: AppLinks.websiteUri),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          title: 'The short version',
          child: _Body(
            'Your subscriptions never leave your phone. There is no account, no '
            'cloud database, and no way for us to read your ledger. One small '
            'banner and an optional rewarded video are the only ads, and we '
            'never sell data — ever.',
          ),
        ),
        const _Section(
          title: 'What the app stores on your device',
          child: _Bullets([
            'Tool name, vendor, price, currency and billing cycle.',
            'Start date and next renewal date.',
            'Your usage-guilt choice and reminder preference.',
            'Display currency, theme and a random install identifier.',
          ]),
        ),
        const _Section(
          title: 'What leaves the device',
          child: _Bullets([
            'A plain request to our server for the preset catalogue and the USD→INR rate (cached).',
            'A few product events (subscription added or deleted, receipt shared, cancel link opened) with coarse buckets — no names, prices or vendors.',
            'Crash reports: stack trace, app version, device model. Never your ledger.',
            'A push token and the random install id, if you allow notifications.',
          ]),
        ),
        const _Section(
          title: 'What we never collect',
          child: _Bullets([
            'Name, email, phone number or contacts.',
            'Your subscription list, prices or spend figures.',
            'Location, photos, files, SMS, call logs or clipboard.',
            'Advertising identifiers unless you consent through Google\'s form.',
          ]),
        ),
        const _Section(
          title: 'Advertising',
          child: _Bullets([
            'One banner sits at the bottom of the screen, above the navigation '
                'bar, on the app\'s four main tabs.',
            'An app-open ad may appear on some launches and returns from the '
                'background — never on the first launch after install, and at '
                'most once every 2 hours.',
            'Rewarded videos are always opt-in: extra receipt themes or a '
                'plain thank-you for supporting the developer. Nothing is '
                'locked behind an ad, and the banner itself never goes away.',
            'No interstitial or timed full-screen ads, and none on the detail '
                'screen, in the add flow, or on the receipt itself.',
            'Change or withdraw ad consent any time in Controls → Ads → Manage.',
          ]),
        ),
        const _Section(
          title: 'Delete your data',
          child: _Body(
            'Delete a row, use Controls → Delete all subscriptions, or uninstall '
            'the app. Remaining server-side analytics age out automatically '
            '(14 months for analytics, 90 days for crashes).',
          ),
        ),
        _Section(
          title: 'Full policy',
          child: _LinkRow(
            label: 'Read the full privacy policy',
            url: AppLinks.privacyPolicyUri,
          ),
        ),
      ],
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          title: 'Licence to use',
          child: _Body(
            'SubBurn is licensed, not sold. You may install and use it on '
            'devices you control. You may not redistribute modified builds or '
            'resell access without written permission.',
          ),
        ),
        const _Section(
          title: 'Your data is your responsibility',
          child: _Body(
            'Prices, dates and usage states are entered by you and stored on this '
            'device. The app does not connect to your bank or to any vendor '
            'account, so keep your own records for tax or dispute purposes. '
            'Uninstalling the app deletes the ledger.',
          ),
        ),
        const _Section(
          title: 'Not financial advice',
          child: _Body(
            'Burn totals, projections, verdicts and the roast are entertainment '
            'and bookkeeping aids. They are not financial, tax or legal advice.',
          ),
        ),
        const _Section(
          title: 'Cancellation links',
          child: _Body(
            'The cancel button opens the vendor\'s own page. SubBurn cannot cancel '
            'a subscription for you and is not responsible for a vendor\'s '
            'cancellation flow, refunds or charges.',
          ),
        ),
        const _Section(
          title: 'Availability',
          child: _Body(
            'The app works offline. Server-fetched content (preset catalogue, '
            'exchange rate) and push messages may be unavailable at times; the app '
            'falls back to the copy bundled with it.',
          ),
        ),
        _Section(
          title: 'Full terms',
          child: _LinkRow(label: 'Read the full terms', url: AppLinks.termsUri),
        ),
      ],
    );
  }
}

class _LicensesBody extends StatelessWidget {
  const _LicensesBody({required this.version});

  /// Real build version. The licence page used to print the publisher name
  /// where the version belongs.
  final String version;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          title: 'Open source',
          child: _Body(
            'SubBurn is built with Flutter and a number of open-source packages. '
            'The complete licence texts for every bundled dependency are listed '
            'in the standard licence page below, generated from the build.',
          ),
        ),
        const _Section(
          title: 'Fonts',
          child: _Body(
            'Plus Jakarta Sans (SIL Open Font License 1.1) for UI text and '
            'JetBrains Mono (SIL Open Font License 1.1) for numerals. The '
            'monospace subset adds a ₹ glyph drawn from Noto Sans Mono '
            '(SIL Open Font License 1.1).',
          ),
        ),
        const _Section(
          title: 'Brand marks',
          child: _Body(
            'Platform icons come from Font Awesome Free (brand icons, CC BY 4.0) '
            'and remain the trademarks of their owners. SubBurn is not affiliated '
            'with, endorsed by, or sponsored by any vendor shown in the catalogue.',
          ),
        ),
        const _Section(
          title: 'This app',
          child: _Body(
            'Application code © Dhanuk Softwares. All rights reserved.',
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'SubBurn',
              applicationVersion:
                  version.isEmpty ? 'Dhanuk Softwares' : version,
              applicationLegalese: '© Dhanuk Softwares',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.sb.text,
              side: BorderSide(color: context.sb.border),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('OPEN SOURCE LICENCES'),
          ),
        ),
      ],
    );
  }
}
