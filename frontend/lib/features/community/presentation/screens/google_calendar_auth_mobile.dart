import 'package:google_sign_in/google_sign_in.dart';

const _calendarScope = 'https://www.googleapis.com/auth/calendar.events';

/// Requests a Google Calendar access token on Android/iOS/desktop.
///
/// Tries [authorizationForScopes] (silent, no UI) first — returns immediately
/// if the scope was already granted in a previous session. Only falls back to
/// [authorizeScopes] (interactive consent popup) when truly needed, i.e. the
/// first time or after the grant is revoked.
///
/// [userEmail] is used as a login hint to pre-select the correct account, but
/// a mismatch is no longer a hard failure — the user may have a different
/// Google account on the device yet still want to create a Meet link.
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
