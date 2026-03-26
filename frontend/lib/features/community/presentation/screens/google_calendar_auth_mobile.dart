import 'package:flutter/foundation.dart';
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

    // google_sign_in 7.x on Android requires serverClientId (the web OAuth
    // client ID). initialize() must be called before the first use and is a
    // no-op if the instance is already initialized.
    await signIn.initialize(serverClientId: clientId);

    // Reuse existing signed-in session silently.
    GoogleSignInAccount? account;
    final silentFuture = signIn.attemptLightweightAuthentication();
    debugPrint(
        '[CalendarAuth] attemptLightweightAuthentication future: ${silentFuture != null}');
    if (silentFuture != null) {
      account = await silentFuture;
      debugPrint('[CalendarAuth] silent account: ${account?.email}');
    }

    if (account == null) {
      debugPrint('[CalendarAuth] calling authenticate()...');
      account = await signIn.authenticate();
      debugPrint('[CalendarAuth] authenticate() returned: ${account.email}');
    }

    // Reject if the authenticated Google account is not the one signed into
    // the app — prevents calendar access leaking to a different account.
    if (userEmail != null && account.email != userEmail) {
      debugPrint(
          '[CalendarAuth] email mismatch: account=${account.email}, app=$userEmail');
      return null;
    }

    final authClient = account.authorizationClient;

    debugPrint('[CalendarAuth] checking existing scope authorization...');
    GoogleSignInClientAuthorization? authz =
        await authClient.authorizationForScopes([_calendarScope]);
    debugPrint('[CalendarAuth] silent authz: ${authz != null}');

    if (authz == null) {
      debugPrint('[CalendarAuth] requesting scope interactively...');
      authz = await authClient.authorizeScopes([_calendarScope]);
      debugPrint('[CalendarAuth] interactive authz obtained');
    }

    debugPrint(
        '[CalendarAuth] success — token length: ${authz.accessToken.length}');
    return authz.accessToken;
  } catch (e, st) {
    debugPrint('[CalendarAuth] ERROR: $e\n$st');
    return null;
  }
}
