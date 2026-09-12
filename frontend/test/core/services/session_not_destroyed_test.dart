@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A session is only ended when the server refuses it.
///
/// Opening a shared link and then navigating back logged people out. The app
/// had three independent "this session looks bad, destroy it" paths, and none
/// of them could tell a refused session from one that had simply not finished
/// restoring:
///
///  1. HttpService's 401 handler signed the user out whenever no session object
///     was in memory — with no refresh attempted. On a resume or cold start
///     that is restoration still in flight, which is exactly the state a deep
///     link lands in.
///  2. The usage-stats repository forced a logout on any raw 401, for a
///     non-essential statistics call.
///  3. AuthNotifier synced the Hive session expiry on tokenRefreshed and
///     signedIn but not on initialSession, so after a cold start the router
///     guard read a stale expiry, believed the session had died, and tried to
///     refresh an already-rotated token.
///
/// These read the source because the rule is structural: the distinction
/// between "refused" and "could not confirm" must stay in the code.
void main() {
  final http = File('lib/core/services/http_service.dart').readAsStringSync();
  final usageStats = File(
    'lib/features/subscription/data/repositories/usage_stats_repository_impl.dart',
  ).readAsStringSync();
  final notifier =
      File('lib/core/router/auth_notifier.dart').readAsStringSync();

  test('a missing session is refreshed before it is ever destroyed', () {
    // The branch reached when ApiAuthHelper.isAuthenticated is false must ask
    // for a refresh, not sign out on the spot.
    final noSessionBranch =
        http.substring(http.indexOf('} else if (retryCount >= _maxRetries)'));

    expect(noSessionBranch.contains('await _refreshToken()'), true,
        reason: 'no session in memory is not proof of a signed-out user');
    expect(
      noSessionBranch.indexOf('SessionRefreshOutcome.inconclusive') <
          noSessionBranch.indexOf('_handleAuthenticationFailure'),
      true,
      reason: 'an unconfirmed refresh must be handled before any logout',
    );
  });

  test('retries running out does not end the session', () {
    expect(
      http.contains(r'401 persisted after $_maxRetries retries'),
      true,
      reason: 'a 401 we cannot get past is not proof the session is dead',
    );
  });

  test('usage statistics can no longer log anyone out', () {
    expect(usageStats.contains('signalAuthFailure'), false,
        reason: 'a non-essential stats call must not end the session');
  });

  test('the restored session updates the stored expiry', () {
    expect(notifier.contains('AuthChangeEvent.initialSession'), true,
        reason: 'without it the guard reads a stale expiry after a cold start');
  });

  test('_refreshToken never trusts a local "still valid" shortcut', () {
    // _refreshToken() is only ever called reactively, right after the server
    // has returned 401 for a request made with the current token — so the
    // server has already proven that token invalid *right now*, no matter
    // what the locally cached expiresAt claims (clock skew, an out-of-band
    // revocation, a stale cached session). A shortcut that skipped the real
    // refreshSession() call whenever local expiry looked fine meant such a
    // session could never be classified `rejected`, so it could never be
    // logged out: every request kept 401ing forever, sign-in was unreachable
    // (the router never saw the session as invalid) and sign-out's own
    // network call hit the same dead end.
    expect(http.contains('Token is still valid, no refresh needed'), false,
        reason: 'a 401 already proved the local expiry cannot be trusted');
    expect(http.contains('await supabase.auth'), true,
        reason: 'a real refresh must always be attempted here');
    expect(http.contains('.refreshSession()'), true,
        reason: 'a real refresh must always be attempted here');
  });
}
