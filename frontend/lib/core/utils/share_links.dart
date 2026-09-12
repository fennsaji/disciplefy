/// Builds public, shareable links into the app.
///
/// These URLs are handed to people outside the app, so they must always point
/// at the public web app — never at `AppConfig.appUrl`, which is `localhost`
/// during development and would produce a link nobody else can open.
///
/// The paths mirror `AppRoutes`, so opening a link lands on the matching route.
/// Routes behind the auth guard are handled automatically: an unauthenticated
/// visitor is sent to `/login?redirect=<path>` and returned to the deep link
/// once signed in.
class ShareLinks {
  const ShareLinks._();

  /// Public origin of the web app. Overridable at build time for staging via
  /// `--dart-define=PUBLIC_WEB_URL=https://staging.example.com`.
  static const String publicWebUrl = String.fromEnvironment(
    'PUBLIC_WEB_URL',
    defaultValue: 'https://app.disciplefy.in',
  );

  /// Origin for links handed to people outside the app.
  ///
  /// Shared links point here rather than at [publicWebUrl] because the web app
  /// renders client-side: chat apps found no Open Graph tags there, so a
  /// shared post had no preview card, and their in-app browsers never hand a
  /// URL to the installed app. This host serves a small server-rendered page
  /// that carries both — and then offers to open the app.
  static const String shareOrigin = String.fromEnvironment(
    'SHARE_ORIGIN',
    defaultValue: 'https://go.disciplefy.in',
  );

  /// The "get the app" link for share text. One page listing Android, iOS
  /// and web, so the text no longer has to guess the recipient's platform —
  /// a Play Store link shared from Android was useless to an iPhone reader.
  static const String appDownloadUrl = 'https://links.disciplefy.in';

  /// Link to a learning path detail page.
  ///
  /// [source] is carried through so opens from a shared link can be told apart
  /// from in-app navigation in analytics.
  static String learningPath(String pathId, {String source = 'share'}) {
    final origin = _normalisedOrigin;
    final id = Uri.encodeComponent(pathId);
    return '$origin/learning-path/$id?source=${Uri.encodeComponent(source)}';
  }

  /// Share text for a learning path, ready to hand to the OS share sheet.
  static String learningPathMessage(String title, String pathId) =>
      '$title — a guided Bible study path on Disciplefy\n\n'
      '${learningPath(pathId)}';

  /// Link to a fellowship post, for sharing outside the app.
  static String fellowshipPost(String fellowshipId, String postId) {
    final origin = shareOrigin.endsWith('/')
        ? shareOrigin.substring(0, shareOrigin.length - 1)
        : shareOrigin;
    return '$origin/fellowship/${Uri.encodeComponent(fellowshipId)}'
        '/post/${Uri.encodeComponent(postId)}';
  }

  /// Link that invites someone into a fellowship.
  static String fellowshipInvite(String token) {
    final origin = shareOrigin.endsWith('/')
        ? shareOrigin.substring(0, shareOrigin.length - 1)
        : shareOrigin;
    return '$origin/fellowship/join/${Uri.encodeComponent(token)}';
  }

  /// Link shared from the daily verse card. There is no per-verse content to
  /// deep-link into (the card always shows "today's" verse), so this just
  /// opens the app to Home.
  static String get dailyVerse {
    final origin = shareOrigin.endsWith('/')
        ? shareOrigin.substring(0, shareOrigin.length - 1)
        : shareOrigin;
    return '$origin/daily-verse';
  }

  /// Link to a specific study guide. Guides are private to their owner, so
  /// opening this deep-links straight to the guide once signed in — the
  /// global auth redirect sends anyone else through login first.
  static String studyGuide(String guideId) {
    final origin = shareOrigin.endsWith('/')
        ? shareOrigin.substring(0, shareOrigin.length - 1)
        : shareOrigin;
    return '$origin/study-guide/${Uri.encodeComponent(guideId)}';
  }

  /// Strips any trailing slash so joining a path never yields a double slash.
  static String get _normalisedOrigin => publicWebUrl.endsWith('/')
      ? publicWebUrl.substring(0, publicWebUrl.length - 1)
      : publicWebUrl;
}
