/// Cross-promotion for the developer's other apps.
///
/// Hardcoded on purpose: the Play Store has no lightweight public API, and a
/// network-fetched promo list would be a tracking vector in an app whose
/// whole promise is local-first. Three apps, chosen by hand — the two
/// five-star titles and the finance sibling whose audience overlaps
/// SubBurn's — not the full eight-app catalogue.
library;

import 'package:flutter/foundation.dart';

class SiblingApp {
  const SiblingApp({
    required this.name,
    required this.tagline,
    required this.playUrl,
  });

  final String name;
  final String tagline;
  final String playUrl;
}

abstract final class DevStore {
  static const storeUrl =
      'https://play.google.com/store/apps/dev?id=4722370385057181718';

  static const List<SiblingApp> featured = [
    SiblingApp(
      name: 'DebtPayoff Pro',
      tagline: 'Debt tracker — the money sibling of SubBurn.',
      playUrl: 'https://play.google.com/store/apps/details?id=com.dhanuk.debtbro',
    ),
    SiblingApp(
      name: 'GovPhoto',
      tagline: 'Exam photo resizer, rated 5.0 on Play.',
      playUrl: 'https://play.google.com/store/apps/details?id=com.dhanuk.govphoto',
    ),
    SiblingApp(
      name: 'Lofiga',
      tagline: 'Lofi + slowed reverb streams, rated 5.0 on Play.',
      playUrl: 'https://play.google.com/store/apps/details?id=com.dhanuk.lofiga',
    ),
  ];

  /// Share copy keeps the link bare so messengers preview it cleanly.
  static String shareText(SiblingApp app) =>
      '${app.name} — ${app.tagline}\n${app.playUrl}';

  static const String publisher = 'Dhanuk Softwares';

  @visibleForTesting
  static int get featuredCount => featured.length;
}
