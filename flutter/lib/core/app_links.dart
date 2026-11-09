/// Public, non-secret URLs the app links to.
///
/// Two hosts on purpose:
/// * [privacyPolicy] is served from the R2 CDN because it is HTTPS, has no
///   JavaScript challenge, and resolves for Play's automated link checker.
/// * [privacyPolicyMirror] is the InfinityFree copy, which is handy when the
///   CDN is unreachable but sits behind a browser challenge.
abstract final class AppLinks {
  static const privacyPolicy =
      'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev/privacy.html';

  static const privacyPolicyMirror =
      'https://dhanuk.page.gd/SubBurn/privacy.html';

  static const website =
      'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev/index.html';

  static const supportEmail = 'aasheeshkatheriya@gmail.com';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicy);

  static Uri get websiteUri => Uri.parse(website);

  static Uri get supportEmailUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: const {'subject': 'SubBurn support'},
      );
}