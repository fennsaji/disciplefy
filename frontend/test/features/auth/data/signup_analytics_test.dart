import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/signup_analytics.dart';

import '../../../helpers/mock_activation_analytics.dart';

User _user({required String createdAt, String? lastSignInAt}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: createdAt,
      lastSignInAt: lastSignInAt,
    );

void main() {
  late MockActivationAnalytics analytics;

  setUp(() => analytics = registerMockAnalytics());
  tearDown(() async => sl.reset());

  test('a sign-in that created the account is a sign-up', () {
    trackSignupIfNew(
        _user(
            createdAt: '2026-10-07T10:00:00Z',
            lastSignInAt: '2026-10-07T10:00:02Z'),
        'google');
    verify(() => analytics.track(NuxEvent.signupCompleted,
        {'method': 'google', 'from_guest': false})).called(1);
  });

  test('signing in to an older account is not a sign-up', () {
    trackSignupIfNew(
        _user(
            createdAt: '2026-01-01T10:00:00Z',
            lastSignInAt: '2026-10-07T10:00:00Z'),
        'apple');
    verifyNever(() => analytics.track(any(), any()));
  });

  test('unknown sign-in time is not a sign-up', () {
    expect(isNewAccount(_user(createdAt: '2026-10-07T10:00:00Z')), isFalse);
  });

  test('an unknown method is sent as other', () {
    trackSignupCompleted('a@b.c', fromGuest: true);
    verify(() => analytics.track(
            NuxEvent.signupCompleted, {'method': 'other', 'from_guest': true}))
        .called(1);
  });

  test('AuthBloc reports Google, Apple and email sign-ups', () {
    final source = File('lib/features/auth/presentation/bloc/auth_bloc.dart')
        .readAsStringSync();
    expect("trackSignupIfNew(user, 'google')".allMatches(source).length, 2);
    expect(source, contains("trackSignupIfNew(user, 'apple')"));
    expect(source, contains("trackSignupCompleted('email', fromGuest: false)"));
  });
}
