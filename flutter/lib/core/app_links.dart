/// Public, non-secret URLs and contact points the app links to.
///
/// InfinityFree is the canonical host; the R2 CDN holds a byte-identical
/// mirror so a page still resolves if the free host is ever suspended.
abstract final class AppLinks {
  static const supportEmail = 'support@dhanuksoftwares.com';

  static const privacyPolicy =
      'https://dhanuk.page.gd/SubBurn/privacy.html';

  static const privacyPolicyMirror =
      'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev/privacy.html';

  static const terms = 'https://dhanuk.page.gd/SubBurn/terms.html';

  static const website = 'https://dhanuk.page.gd/SubBurn/';

  static const publisher = 'Dhanuk Softwares';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicy);

  static Uri get termsUri => Uri.parse(terms);

  static Uri get websiteUri => Uri.parse(website);

  static Uri get supportEmailUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: const {'subject': 'SubBurn support'},
      );
}
