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

  /// Strips any trailing slash so joining a path never yields a double slash.
  static String get _normalisedOrigin => publicWebUrl.endsWith('/')
      ? publicWebUrl.substring(0, publicWebUrl.length - 1)
      : publicWebUrl;
}
