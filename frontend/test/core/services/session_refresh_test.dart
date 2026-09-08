import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/session_refresh.dart';

/// Users were being signed out after force-closing the app and reopening it.
/// The cause was a bool: every refresh failure — including "the phone had no
/// network yet" — was read as "the session is dead", and the HTTP layer called
/// signOut(). Only Supabase refusing the token may end a session.
void main() {
  test('Supabase refusing the token ends the session', () {
    expect(
      classifySessionRefreshError(
          AuthApiException('Invalid Refresh Token', statusCode: '400')),
      SessionRefreshOutcome.rejected,
    );
  });

  test('an offline refresh keeps the session, despite being an AuthException',
      () {
    // This is the one that logged people out. gotrue wraps a dead socket in
    // AuthRetryableFetchException, which extends AuthException and (in the
    // pinned version) does not override toString — so it surfaced in the logs
    // as `AuthException(message: ClientException with SocketException…)` and
    // every `error is AuthException` check read it as a refusal.
    final offline = AuthRetryableFetchException(
      message: 'ClientException with SocketException: Connection refused',
    );

    expect(offline, isA<AuthException>());
    expect(classifySessionRefreshError(offline),
        SessionRefreshOutcome.inconclusive);
  });

  test('a 5xx from the auth server is retryable, not a logout', () {
    expect(
      classifySessionRefreshError(AuthRetryableFetchException(
          message: 'bad gateway', statusCode: '502')),
      SessionRefreshOutcome.inconclusive,
    );
  });

  test('a timeout says nothing about the session', () {
    expect(
      classifySessionRefreshError(
          TimeoutException('refreshSession', const Duration(seconds: 5))),
      SessionRefreshOutcome.inconclusive,
    );
  });

  test('a dead socket says nothing about the session', () {
    // What a cold start hits when the radio has not reconnected yet.
    expect(
      classifySessionRefreshError(
          const SocketExceptionStub('Failed host lookup: supabase.co')),
      SessionRefreshOutcome.inconclusive,
    );
  });

  test('an unexpected error is never treated as a logout', () {
    expect(
      classifySessionRefreshError(StateError('platform channel unavailable')),
      SessionRefreshOutcome.inconclusive,
    );
  });
}

/// Stand-in for dart:io's SocketException, which the test binding cannot throw
/// for real without a network stack.
class SocketExceptionStub implements Exception {
  final String message;
  const SocketExceptionStub(this.message);
}

class TimeoutException implements Exception {
  final String message;
  final Duration duration;
  TimeoutException(this.message, this.duration);
}
