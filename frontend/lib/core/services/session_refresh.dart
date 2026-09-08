import 'package:supabase_flutter/supabase_flutter.dart';

/// What a refresh attempt actually told us about the session.
///
/// The three outcomes exist because only one of them may sign the user out.
/// Collapsing them into a bool is what logged valid users out on a network
/// blip: the app could not reach Supabase, assumed the worst, and destroyed a
/// session that was still perfectly good.
enum SessionRefreshOutcome {
  /// A valid session was obtained.
  refreshed,

  /// Supabase answered and rejected the refresh token. The session is gone.
  rejected,

  /// We never got an answer — timeout, offline, dead socket, or the app asking
  /// before session restoration finished on cold start. Says nothing about
  /// whether the session is valid, so it must never trigger a sign-out.
  inconclusive,
}

/// Classifies a thrown refresh error.
///
/// Only Supabase *answering* and refusing the token ends a session. The catch
/// is that gotrue wraps network failures in [AuthRetryableFetchException],
/// which extends [AuthException] and — in the pinned version — does not
/// override `toString()`, so an offline refresh surfaces as
/// `AuthException(message: ClientException with SocketException…)`.
///
/// Treating every [AuthException] as a refusal is therefore the bug, not the
/// fix: it signed users out whenever the app woke with no network. gotrue
/// itself makes the same distinction — it keeps the session on a retryable
/// fetch error and clears it on any other [AuthException].
SessionRefreshOutcome classifySessionRefreshError(Object error) {
  // Network could not complete: offline, DNS, socket, or a 5xx from the auth
  // server. The session is untouched and may well still be valid.
  if (error is AuthRetryableFetchException) {
    return SessionRefreshOutcome.inconclusive;
  }

  // A genuine answer from Supabase refusing the refresh token.
  if (error is AuthException) return SessionRefreshOutcome.rejected;

  // Timeouts, platform channel errors, anything thrown before a reply.
  return SessionRefreshOutcome.inconclusive;
}
