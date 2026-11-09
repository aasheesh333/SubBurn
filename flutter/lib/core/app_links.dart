/// Public, non-secret URLs the app links to.
///
/// InfinityFree is the canonical host; the R2 CDN holds a byte-identical
/// mirror so the policy still resolves if the free host is ever suspended.
abstract final class AppLinks {
  static const privacyPolicy =
      'https://dhanuk.page.gd/SubBurn/privacy.html';

  static const privacyPolicyMirror =
      'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev/privacy.html';

  static const website = 'https://dhanuk.page.gd/SubBurn/';

  static const supportEmail = 'aasheeshkatheriya@gmail.com';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicy);

  static Uri get websiteUri => Uri.parse(website);

  static Uri get supportEmailUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: const {'subject': 'SubBurn support'},
      );
}