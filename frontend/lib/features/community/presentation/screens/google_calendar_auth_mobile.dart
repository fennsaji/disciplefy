import 'package:google_sign_in/google_sign_in.dart';

const _calendarScope = 'https://www.googleapis.com/auth/calendar.events';

/// Requests a Google Calendar access token on Android/iOS/desktop.
///
/// Tries [authorizationForScopes] (silent, no UI) first — returns immediately
/// if the scope was already granted in a previous session. Only falls back to
/// [authorizeScopes] (interactive consent popup) when truly needed, i.e. the
/// first time or after the grant is revoked.
///
/// [userEmail] restricts the Calendar grant to the account the user is already
/// signed into the app with.  If the resolved Google account email differs from
/// [userEmail] the function returns null so the caller can surface an error
/// rather than silently using the wrong calendar.
Future<String?> requestCalendarAccessToken(
  String clientId, {
  String? userEmail,
}) async {
  try {
    final signIn = GoogleSignIn.instance;

    // Reuse existing signed-in session silently.
    GoogleSignInAccount? account;
    final silentFuture = signIn.attemptLightweightAuthentication();
    if (silentFuture != null) {
      account = await silentFuture;
    }
    account ??= await signIn.authenticate();

    // Reject if the authenticated Google account is not the one signed into
    // the app — prevents calendar access leaking to a different account.
    if (userEmail != null && account.email != userEmail) return null;

    final authClient = account.authorizationClient;

    // Silent path: returns immediately if calendar scope already granted.
    // No popup, no UI — completely transparent to the user.
    GoogleSignInClientAuthorization? authz =
        await authClient.authorizationForScopes([_calendarScope]);

    // Interactive fallback: only shown on first use or after grant is revoked.
    authz ??= await authClient.authorizeScopes([_calendarScope]);

    return authz.accessToken;
  } catch (_) {
    return null;
  }
}
