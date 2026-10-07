import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/services/guest_marker.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mock_activation_analytics.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockOAuthService extends Mock implements OAuthService {}

class MemoryStash extends GuestTokenStash {
  PendingGuestMerge? value;

  @override
  Future<PendingGuestMerge?> read() async => value;

  @override
  Future<void> write(PendingGuestMerge pending) async => value = pending;

  @override
  Future<void> clear() async => value = null;
}

User fakeUser({
  required bool anon,
  String id = 'guest-id',
  String? emailConfirmedAt,
}) =>
    User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-07T00:00:00Z',
      isAnonymous: anon,
      emailConfirmedAt: emailConfirmedAt,
    );

Session fakeSession({
  required bool anon,
  String token = 'token',
  String userId = 'guest-id',
}) =>
    Session(
      accessToken: token,
      tokenType: 'bearer',
      user: fakeUser(anon: anon, id: userId),
    );

/// An unsigned JWT whose `exp` is [fromNow] away.
String jwtExpiringIn(Duration fromNow) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
}

void main() {
  late MockGoTrueClient auth;
  late MockFunctionsClient functions;
  late MockOAuthService oauth;
  late MemoryStash stash;
  late GuestSessionService service;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OAuthProvider.google);
  });

  setUp(() {
    auth = MockGoTrueClient();
    functions = MockFunctionsClient();
    oauth = MockOAuthService();
    stash = MemoryStash();
    service =
        GuestSessionService(auth, functions, oauth, isWeb: false, stash: stash);
  });

  group('startGuest', () {
    test('signs in anonymously once', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signInAnonymously()).thenAnswer(
          (_) async => AuthResponse(session: fakeSession(anon: true)));

      await service.startGuest();

      verify(() => auth.signInAnonymously()).called(1);
    });

    test('concurrent calls share one anonymous sign-in', () async {
      final completer = Completer<AuthResponse>();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signInAnonymously()).thenAnswer((_) => completer.future);

      final a = service.startGuest();
      final b = service.startGuest();
      completer.complete(AuthResponse(session: fakeSession(anon: true)));
      await Future.wait([a, b]);

      verify(() => auth.signInAnonymously()).called(1);
    });

    test('is a no-op when a session exists', () async {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));

      await service.startGuest();

      verifyNever(() => auth.signInAnonymously());
    });

    test('throws when no session comes back', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signInAnonymously())
          .thenAnswer((_) async => AuthResponse());

      expect(service.startGuest(), throwsA(isA<AuthException>()));
    });
  });

  group('isGuest / hasSession', () {
    test('isGuest follows the Supabase isAnonymous flag', () {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      expect(service.isGuest, isTrue);

      when(() => auth.currentUser).thenReturn(fakeUser(anon: false));
      expect(service.isGuest, isFalse);

      when(() => auth.currentUser).thenReturn(null);
      expect(service.isGuest, isFalse);
    });

    test('hasSession is true for any session', () {
      when(() => auth.currentSession).thenReturn(null);
      expect(service.hasSession, isFalse);
      when(() => auth.currentSession).thenReturn(fakeSession(anon: true));
      expect(service.hasSession, isTrue);
    });
  });

  group('linkGoogle (mobile)', () {
    setUp(() {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: 'guest.jwt'));
      when(() => oauth.obtainGoogleIdToken()).thenAnswer(
          (_) async => (idToken: 'id', accessToken: 'at', nonce: null));
    });

    test('links the identity to the guest', () async {
      when(() => auth.linkIdentityWithIdToken(
                provider: OAuthProvider.google,
                idToken: 'id',
                accessToken: 'at',
              ))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));

      expect(await service.linkGoogle(), LinkOutcome.linked);
      verifyNever(() => auth.signInWithIdToken(
          provider: any(named: 'provider'), idToken: any(named: 'idToken')));
      verifyNever(
          () => functions.invoke(any(), headers: any(named: 'headers')));
    });

    test('Google link conflict falls back to sign-in + merge', () async {
      when(() => auth.linkIdentityWithIdToken(
                provider: OAuthProvider.google,
                idToken: 'id',
                accessToken: 'at',
              ))
          .thenThrow(const AuthException(
              'Identity is already linked to another user',
              code: 'identity_already_exists'));
      when(() => auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'id',
            accessToken: 'at',
          )).thenAnswer((_) async {
        // Signing in replaces the current session with the account's.
        when(() => auth.currentSession).thenReturn(
            fakeSession(anon: false, token: 'account.jwt', userId: 'acct'));
        when(() => auth.currentUser)
            .thenReturn(fakeUser(anon: false, id: 'acct'));
        return AuthResponse(
            session: fakeSession(anon: false, token: 'account.jwt'));
      });
      when(() => functions.invoke('user-profile?action=merge_guest',
              headers: {'x-guest-token': 'guest.jwt'}))
          .thenAnswer((_) async => FunctionResponse(data: {
                'success': true,
                'data': {'topics': 1}
              }, status: 200));

      expect(await service.linkGoogle(), LinkOutcome.mergedIntoExisting);

      // Guest token captured before the sign-in, merge after it.
      verifyInOrder([
        () => auth.linkIdentityWithIdToken(
              provider: OAuthProvider.google,
              idToken: 'id',
              accessToken: 'at',
            ),
        () => auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: 'id',
              accessToken: 'at',
            ),
        () => functions.invoke('user-profile?action=merge_guest',
            headers: {'x-guest-token': 'guest.jwt'}),
      ]);
      expect(stash.value, isNull);
    });

    test('a guest token about to expire is refreshed before signing in',
        () async {
      final expiring = jwtExpiringIn(const Duration(seconds: 30));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: expiring));
      when(() => auth.refreshSession()).thenAnswer((_) async =>
          AuthResponse(session: fakeSession(anon: true, token: 'fresh.jwt')));
      when(() => auth.linkIdentityWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('conflict',
              statusCode: '422', code: 'identity_already_exists'));
      when(() => auth.signInWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));
      when(() => functions.invoke(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => FunctionResponse(status: 200));

      expect(await service.linkGoogle(), LinkOutcome.mergedIntoExisting);

      verifyInOrder([
        () => auth.refreshSession(),
        () => auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: 'id',
              accessToken: 'at',
            ),
        () => functions.invoke('user-profile?action=merge_guest',
            headers: {'x-guest-token': 'fresh.jwt'}),
      ]);
    });

    test('merge failure keeps the user signed in and stashes a retry',
        () async {
      when(() => auth.linkIdentityWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('Identity is already linked'));
      when(() => auth.signInWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));
      when(() => functions.invoke(any(), headers: any(named: 'headers')))
          .thenThrow(const FunctionException(status: 500));

      expect(await service.linkGoogle(), LinkOutcome.mergeFailed);

      verifyNever(() => auth.signOut());
      expect(stash.value?.guestToken, 'guest.jwt');
      expect(stash.value?.guestUserId, 'guest-id');
    });

    test('a rejected guest token (4xx) is not kept for retry', () async {
      when(() => auth.linkIdentityWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('x', code: 'identity_already_exists'));
      when(() => auth.signInWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));
      when(() => functions.invoke(any(), headers: any(named: 'headers')))
          .thenThrow(const FunctionException(status: 400));

      expect(await service.linkGoogle(), LinkOutcome.mergeFailed);
      expect(stash.value, isNull);
      verifyNever(() => auth.signOut());
    });

    test('other link errors propagate without signing in', () async {
      when(() => auth.linkIdentityWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('Manual linking is disabled',
              code: 'manual_linking_disabled'));

      await expectLater(service.linkGoogle(), throwsA(isA<AuthException>()));
      verifyNever(() => auth.signInWithIdToken(
          provider: any(named: 'provider'), idToken: any(named: 'idToken')));
    });

    test('a failed sign-in after a conflict leaves the guest untouched',
        () async {
      when(() => auth.linkIdentityWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('x', code: 'identity_already_exists'));
      when(() => auth.signInWithIdToken(
              provider: any(named: 'provider'),
              idToken: any(named: 'idToken'),
              accessToken: any(named: 'accessToken'),
              nonce: any(named: 'nonce')))
          .thenThrow(const AuthException('network'));

      await expectLater(service.linkGoogle(), throwsA(isA<AuthException>()));
      verifyNever(
          () => functions.invoke(any(), headers: any(named: 'headers')));
    });

    test('cancelling the Google sheet returns cancelled', () async {
      when(() => oauth.obtainGoogleIdToken()).thenThrow(
          const GoogleSignInException(
              code: GoogleSignInExceptionCode.canceled));

      expect(await service.linkGoogle(), LinkOutcome.cancelled);
      verifyNever(() => auth.linkIdentityWithIdToken(
          provider: any(named: 'provider'), idToken: any(named: 'idToken')));
    });

    test('linking without a guest session is refused', () async {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: false));
      expect(service.linkGoogle(), throwsStateError);
    });
  });

  group('linkApple (mobile)', () {
    test('passes the raw nonce to Supabase', () async {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => oauth.obtainAppleIdToken()).thenAnswer(
          (_) async => (idToken: 'apple', accessToken: null, nonce: 'raw'));
      when(() => auth.linkIdentityWithIdToken(
              provider: OAuthProvider.apple, idToken: 'apple', nonce: 'raw'))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));

      expect(await service.linkApple(), LinkOutcome.linked);
    });

    test('cancelling the Apple sheet returns cancelled', () async {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => oauth.obtainAppleIdToken()).thenThrow(
          const SignInWithAppleAuthorizationException(
              code: AuthorizationErrorCode.canceled, message: ''));

      expect(await service.linkApple(), LinkOutcome.cancelled);
    });
  });

  group('linkEmail', () {
    late StreamController<AuthState> authEvents;

    setUp(() {
      authEvents = StreamController<AuthState>.broadcast();
      when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents.stream);
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: 'guest.jwt'));
    });

    tearDown(() async {
      service.dispose();
      await authEvents.close();
    });

    test('returns emailConfirmationSent while the email is unconfirmed',
        () async {
      when(() => auth.updateUser(any())).thenAnswer(
          (_) async => UserResponse.fromJson(fakeUser(anon: true).toJson()));

      final outcome = await service.linkEmail(
          email: 'a@b.c', password: 'Secret123', fullName: 'Ann');

      expect(outcome, LinkOutcome.emailConfirmationSent);
      final attrs = verify(() => auth.updateUser(captureAny())).captured.single
          as UserAttributes;
      expect(attrs.email, 'a@b.c');
      expect(attrs.data, {'full_name': 'Ann'});
      expect(attrs.password, isNull);
    });

    test('sets the password once the email is confirmed', () async {
      when(() => auth.updateUser(any())).thenAnswer(
          (_) async => UserResponse.fromJson(fakeUser(anon: true).toJson()));
      await service.linkEmail(
          email: 'a@b.c', password: 'Secret123', fullName: 'Ann');

      final confirmed =
          fakeUser(anon: false, emailConfirmedAt: '2026-10-07T00:00:00Z');
      when(() => auth.currentUser).thenReturn(confirmed);
      authEvents.add(AuthState(AuthChangeEvent.userUpdated,
          Session(accessToken: 't', tokenType: 'bearer', user: confirmed)));
      await pumpEventQueue();

      final calls = verify(() => auth.updateUser(captureAny())).captured;
      expect(calls, hasLength(2));
      expect((calls.last as UserAttributes).password, 'Secret123');
    });

    test('links immediately when confirmations are off', () async {
      when(() => auth.updateUser(any())).thenAnswer((_) async =>
          UserResponse.fromJson(
              fakeUser(anon: false, emailConfirmedAt: '2026-10-07T00:00:00Z')
                  .toJson()));

      final outcome = await service.linkEmail(
          email: 'a@b.c', password: 'Secret123', fullName: 'Ann');

      expect(outcome, LinkOutcome.linked);
      final calls = verify(() => auth.updateUser(captureAny())).captured;
      expect((calls.last as UserAttributes).password, 'Secret123');
    });

    test('an email owned by an account signs in and merges', () async {
      when(() => auth.updateUser(any())).thenThrow(const AuthException(
          'A user with this email address has already been registered',
          statusCode: '422',
          code: 'email_exists'));
      when(() => auth.signInWithPassword(email: 'a@b.c', password: 'Secret123'))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));
      when(() => functions.invoke('user-profile?action=merge_guest',
              headers: {'x-guest-token': 'guest.jwt'}))
          .thenAnswer((_) async => FunctionResponse(status: 200));

      expect(
          await service.linkEmail(
              email: 'a@b.c', password: 'Secret123', fullName: 'Ann'),
          LinkOutcome.mergedIntoExisting);
    });

    test('a wrong password for the existing account is emailExists', () async {
      when(() => auth.updateUser(any()))
          .thenThrow(const AuthException('exists', code: 'email_exists'));
      when(() => auth.signInWithPassword(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException('Invalid login credentials',
              code: 'invalid_credentials'));

      expect(
          await service.linkEmail(
              email: 'a@b.c', password: 'wrong', fullName: 'Ann'),
          LinkOutcome.emailExists);
      verifyNever(
          () => functions.invoke(any(), headers: any(named: 'headers')));
    });

    test('an older server message without a code is also emailExists',
        () async {
      when(() => auth.updateUser(any()))
          .thenThrow(const AuthException('exists', code: 'email_exists'));
      when(() =>
          auth.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'))).thenThrow(
          const AuthException('Invalid login credentials', statusCode: '400'));

      expect(
          await service.linkEmail(
              email: 'a@b.c', password: 'wrong', fullName: 'Ann'),
          LinkOutcome.emailExists);
    });

    test('any other sign-in failure still propagates', () async {
      when(() => auth.updateUser(any()))
          .thenThrow(const AuthException('exists', code: 'email_exists'));
      when(() => auth.signInWithPassword(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException('Email not confirmed',
              code: 'email_not_confirmed'));

      await expectLater(
          service.linkEmail(email: 'a@b.c', password: 'x', fullName: 'Ann'),
          throwsA(isA<AuthException>()));
    });
  });

  group('web', () {
    late List<(OAuthProvider, bool)> launches;

    setUp(() {
      launches = [];
      service = GuestSessionService(
        auth,
        functions,
        oauth,
        isWeb: true,
        stash: stash,
        webOAuth: (provider, {required link}) async {
          launches.add((provider, link));
          return true;
        },
      );
    });

    test('linkGoogle stashes the guest token and redirects to link', () async {
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: 'guest.jwt'));

      expect(await service.linkGoogle(), LinkOutcome.redirecting);

      expect(launches, [(OAuthProvider.google, true)]);
      expect(stash.value?.guestToken, 'guest.jwt');
      verifyNever(() => oauth.obtainGoogleIdToken());
    });

    test('a conflict on the callback URL redirects to sign in', () async {
      stash.value = PendingGuestMerge(
          guestToken: jwtExpiringIn(const Duration(hours: 1)),
          guestUserId: 'guest-id',
          provider: 'google');
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));

      final outcome = await service.resumePendingLink(
          callbackUri: Uri.parse(
              'https://app.example/#error=server_error&error_code=identity_already_exists&error_description=Identity+is+already+linked+to+another+user'));

      expect(outcome, LinkOutcome.redirecting);
      expect(launches, [(OAuthProvider.google, false)]);
      expect(stash.value, isNotNull);
    });

    test('back from the sign-in redirect, the guest is merged', () async {
      final guestToken = jwtExpiringIn(const Duration(hours: 1));
      stash.value = PendingGuestMerge(
          guestToken: guestToken, guestUserId: 'guest-id', provider: 'google');
      when(() => auth.currentUser)
          .thenReturn(fakeUser(anon: false, id: 'acct'));
      when(() => functions.invoke('user-profile?action=merge_guest',
              headers: {'x-guest-token': guestToken}))
          .thenAnswer((_) async => FunctionResponse(status: 200));

      expect(await service.resumePendingLink(callbackUri: Uri.parse('/')),
          LinkOutcome.mergedIntoExisting);
      expect(stash.value, isNull);
    });

    test('back from a successful link redirect, reports linked', () async {
      stash.value = PendingGuestMerge(
          guestToken: jwtExpiringIn(const Duration(hours: 1)),
          guestUserId: 'guest-id',
          provider: 'google');
      when(() => auth.currentUser).thenReturn(fakeUser(anon: false));

      expect(await service.resumePendingLink(), LinkOutcome.linked);
      expect(stash.value, isNull);
      verifyNever(
          () => functions.invoke(any(), headers: any(named: 'headers')));
    });

    test('an expired stashed guest token is dropped, not sent', () async {
      stash.value = PendingGuestMerge(
          guestToken: jwtExpiringIn(const Duration(minutes: -5)),
          guestUserId: 'guest-id',
          provider: 'google');
      when(() => auth.currentUser)
          .thenReturn(fakeUser(anon: false, id: 'acct'));

      expect(await service.resumePendingLink(), LinkOutcome.mergeFailed);
      expect(stash.value, isNull);
      verifyNever(
          () => functions.invoke(any(), headers: any(named: 'headers')));
    });

    test('nothing pending resolves to null', () async {
      expect(await service.resumePendingLink(), isNull);
    });
  });

  group('error classification', () {
    test('identity conflict by code, statusCode or message', () {
      expect(
          GuestSessionService.isIdentityConflict(
              const AuthException('x', code: 'identity_already_exists')),
          isTrue);
      // Web callback errors put error_code into statusCode.
      expect(
          GuestSessionService.isIdentityConflict(const AuthException('x',
              statusCode: 'identity_already_exists', code: 'server_error')),
          isTrue);
      expect(
          GuestSessionService.isIdentityConflict(const AuthException(
              'Identity is already linked to another user')),
          isTrue);
      expect(
          GuestSessionService.isIdentityConflict(
              const AuthException('x', code: 'manual_linking_disabled')),
          isFalse);
    });

    test('email conflict by code or message', () {
      expect(
          GuestSessionService.isEmailConflict(
              const AuthException('x', code: 'email_exists')),
          isTrue);
      expect(
          GuestSessionService.isEmailConflict(const AuthException(
              'A user with this email address has already been registered')),
          isTrue);
      expect(
          GuestSessionService.isEmailConflict(
              const AuthException('x', code: 'weak_password')),
          isFalse);
    });

    test('callback URL conflict in query or fragment', () {
      expect(
          GuestSessionService.uriHasIdentityConflict(Uri.parse(
              'https://a.b/?error=server_error&error_code=identity_already_exists')),
          isTrue);
      expect(
          GuestSessionService.uriHasIdentityConflict(
              Uri.parse('https://a.b/#error_code=identity_already_exists')),
          isTrue);
      expect(
          GuestSessionService.uriHasIdentityConflict(
              Uri.parse('https://a.b/?code=abc')),
          isFalse);
    });
  });

  group('was_guest marker', () {
    late Directory dir;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('guest_marker_test');
      Hive.init(dir.path);
      await Hive.openBox('app_settings');
    });

    tearDownAll(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    setUp(() => Hive.box('app_settings').clear());

    test('starting a guest marks the device', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signInAnonymously()).thenAnswer(
          (_) async => AuthResponse(session: fakeSession(anon: true)));

      await service.startGuest();

      expect(GuestMarker.wasGuest, isTrue);
    });

    test('linking an identity clears the mark', () async {
      await GuestMarker.markGuest();
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: 'guest.jwt'));
      when(() => oauth.obtainGoogleIdToken()).thenAnswer(
          (_) async => (idToken: 'id', accessToken: 'at', nonce: null));
      when(() => auth.linkIdentityWithIdToken(
                provider: OAuthProvider.google,
                idToken: 'id',
                accessToken: 'at',
              ))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));

      expect(await service.linkGoogle(), LinkOutcome.linked);
      expect(GuestMarker.wasGuest, isFalse);
    });
  });

  group('activation analytics', () {
    late MockActivationAnalytics analytics;

    setUp(() {
      analytics = registerMockAnalytics();
      when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
      when(() => auth.currentSession)
          .thenReturn(fakeSession(anon: true, token: 'guest.jwt'));
    });

    tearDown(() async => sl.reset());

    test('a linked Google identity is a sign-up from a guest', () async {
      when(() => oauth.obtainGoogleIdToken()).thenAnswer(
          (_) async => (idToken: 'id', accessToken: 'at', nonce: null));
      when(() => auth.linkIdentityWithIdToken(
                provider: OAuthProvider.google,
                idToken: 'id',
                accessToken: 'at',
              ))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));

      expect(await service.linkGoogle(), LinkOutcome.linked);
      verify(() => analytics.track(NuxEvent.signupCompleted,
          {'method': 'google', 'from_guest': true})).called(1);
    });

    test('an email merged into an existing account is reported', () async {
      when(() => auth.updateUser(any())).thenThrow(const AuthException(
          'A user with this email address has already been registered',
          statusCode: '422',
          code: 'email_exists'));
      when(() => auth.signInWithPassword(email: 'a@b.c', password: 'Secret123'))
          .thenAnswer(
              (_) async => AuthResponse(session: fakeSession(anon: false)));
      when(() => functions.invoke('user-profile?action=merge_guest',
              headers: {'x-guest-token': 'guest.jwt'}))
          .thenAnswer((_) async => FunctionResponse(status: 200));

      expect(
          await service.linkEmail(
              email: 'a@b.c', password: 'Secret123', fullName: 'Ann'),
          LinkOutcome.mergedIntoExisting);
      verify(() => analytics.track(NuxEvent.signupCompleted,
          {'method': 'email', 'from_guest': true})).called(1);
    });

    test('a cancelled link reports nothing', () async {
      when(() => oauth.obtainAppleIdToken()).thenThrow(
          const SignInWithAppleAuthorizationException(
              code: AuthorizationErrorCode.canceled, message: ''));

      expect(await service.linkApple(), LinkOutcome.cancelled);
      verifyNever(() => analytics.track(any(), any()));
    });

    test('a link resolved after a web redirect is reported', () async {
      stash.value = PendingGuestMerge(
          guestToken: jwtExpiringIn(const Duration(hours: 1)),
          guestUserId: 'guest-id',
          provider: 'apple');
      when(() => auth.currentUser).thenReturn(fakeUser(anon: false));

      expect(await service.resumePendingLink(), LinkOutcome.linked);
      verify(() => analytics.track(NuxEvent.signupCompleted,
          {'method': 'apple', 'from_guest': true})).called(1);
    });
  });
}
