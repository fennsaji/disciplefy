import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/features/auth/data/services/signup_analytics.dart';
import 'package:disciplefy_bible_study/core/router/router_guard.dart';
import 'package:disciplefy_bible_study/core/services/guest_marker.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/oauth_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/exceptions/auth_exceptions.dart'
    as auth_exceptions;

/// Result of turning a guest (Supabase anonymous user) into a full account.
enum LinkOutcome {
  /// The guest's own user now carries the identity; its progress stays put.
  linked,

  /// The identity belonged to another account: the app is now signed in to
  /// that account and the guest's progress was merged into it.
  mergedIntoExisting,

  /// Email was attached but must be confirmed before it takes effect.
  emailConfirmationSent,

  /// The user closed the provider's sheet. Nothing changed.
  cancelled,

  /// Signed in to the existing account, but the progress merge failed. The
  /// user stays signed in; the merge is retried on the next app start while
  /// the guest token is still valid.
  mergeFailed,

  /// Web only: the browser is leaving for the provider. The outcome is
  /// resolved by [GuestSessionService.resumePendingLink] after the redirect.
  redirecting,

  /// Email sign-up: the email already has an account and the password given
  /// is not its password. Nothing changed; the person is still a guest.
  emailExists,
}

/// Starts a web OAuth redirect: links [provider] to the current user when
/// [link] is true, otherwise signs in with it.
typedef WebOAuthLauncher = Future<bool> Function(
  OAuthProvider provider, {
  required bool link,
});

typedef _IdTokenCredentials = ({
  String idToken,
  String? accessToken,
  String? nonce,
});

/// A guest token kept across a redirect (web) or a failed merge (retry).
@immutable
class PendingGuestMerge {
  final String guestToken;
  final String guestUserId;
  final String provider;

  const PendingGuestMerge({
    required this.guestToken,
    required this.guestUserId,
    required this.provider,
  });

  Map<String, String> toJson() => {
        'token': guestToken,
        'guest_user_id': guestUserId,
        'provider': provider,
      };

  static PendingGuestMerge? fromJson(Object? raw) {
    if (raw is! String) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final token = map['token'];
      final userId = map['guest_user_id'];
      final provider = map['provider'];
      if (token is! String || userId is! String || provider is! String) {
        return null;
      }
      return PendingGuestMerge(
          guestToken: token, guestUserId: userId, provider: provider);
    } catch (_) {
      return null;
    }
  }
}

/// Storage for [PendingGuestMerge]. Default: Hive `app_settings`.
class GuestTokenStash {
  static const String key = 'pending_guest_token';
  static const String _boxName = 'app_settings';

  Future<Box> get _box async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Future<PendingGuestMerge?> read() async =>
      PendingGuestMerge.fromJson((await _box).get(key));

  Future<void> write(PendingGuestMerge pending) async =>
      (await _box).put(key, jsonEncode(pending.toJson()));

  Future<void> clear() async => (await _box).delete(key);
}

/// Guest sessions (Supabase anonymous users) and their upgrade to a full
/// account by linking Google, Apple or email.
///
/// When the identity already belongs to another account, the service signs
/// in to that account and merges the guest's progress into it through
/// `user-profile?action=merge_guest`, authenticated by the guest's access
/// token captured before leaving the guest session.
///
/// Never logs tokens, emails or ids.
class GuestSessionService {
  final GoTrueClient _auth;
  final FunctionsClient _functions;
  final OAuthService _oauth;
  final bool _isWeb;
  final WebOAuthLauncher _webOAuth;
  final GuestTokenStash _stash;

  Future<void>? _startGuestInFlight;
  String? _pendingPassword;
  StreamSubscription<AuthState>? _emailConfirmationSub;

  /// A guest token is refreshed when it has less than this left, so it is
  /// still valid when the merge call reaches the server.
  static const Duration _minGuestTokenLifetime = Duration(minutes: 2);

  static const String _mergeFunction = 'user-profile?action=merge_guest';
  static const String _guestTokenHeader = 'x-guest-token';

  GuestSessionService(
    this._auth,
    this._functions,
    this._oauth, {
    bool? isWeb,
    WebOAuthLauncher? webOAuth,
    GuestTokenStash? stash,
  })  : _isWeb = isWeb ?? kIsWeb,
        _webOAuth = webOAuth ?? _defaultWebOAuth(_auth),
        _stash = stash ?? GuestTokenStash();

  static WebOAuthLauncher _defaultWebOAuth(GoTrueClient auth) =>
      (provider, {required link}) =>
          link ? auth.linkIdentity(provider) : auth.signInWithOAuth(provider);

  /// True when the signed-in user is a Supabase anonymous user.
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// True when any Supabase session (guest or full) is present.
  bool get hasSession => _auth.currentSession != null;

  /// Signs in anonymously unless a user is already signed in.
  /// Concurrent calls share one sign-in.
  Future<void> startGuest() {
    if (_auth.currentUser != null) {
      Logger.debug('[GUEST] startGuest skipped: a session already exists');
      return Future.value();
    }
    return _startGuestInFlight ??=
        _signInAnonymously().whenComplete(() => _startGuestInFlight = null);
  }

  Future<void> _signInAnonymously() async {
    Logger.info('[GUEST] Starting guest session');
    final response = await _auth.signInAnonymously();
    if (response.session == null) {
      Logger.error('[GUEST] Anonymous sign-in returned no session');
      throw const AuthException('Guest session could not be started');
    }
    // A guest is created on the first-run goal screen, after the language
    // was chosen there: never bounce them to /language-selection.
    RouterGuard.markLanguageSelectionCompleted();
    // If this session is ever lost, the router starts a new first run.
    await GuestMarker.markGuest();
    Logger.info('[GUEST] Guest session started');
  }

  /// Links Google to the guest (native ID token on mobile, redirect on web).
  Future<LinkOutcome> linkGoogle() async => _reported(
      await _linkProvider(OAuthProvider.google, _oauth.obtainGoogleIdToken),
      OAuthProvider.google.name);

  /// Links Apple to the guest (native ID token on iOS, redirect on web).
  Future<LinkOutcome> linkApple() async => _reported(
      await _linkProvider(OAuthProvider.apple, _oauth.obtainAppleIdToken),
      OAuthProvider.apple.name);

  /// Reports a guest that became (or joined) a full account as a sign-up.
  LinkOutcome _reported(LinkOutcome outcome, String method) {
    if (outcome == LinkOutcome.linked ||
        outcome == LinkOutcome.mergedIntoExisting) {
      trackSignupCompleted(method, fromGuest: true);
    }
    return outcome;
  }

  Future<LinkOutcome> _linkProvider(
    OAuthProvider provider,
    Future<_IdTokenCredentials> Function() obtainIdToken,
  ) async {
    _requireGuest();
    if (_isWeb) return _linkOnWeb(provider);

    final _IdTokenCredentials credentials;
    try {
      credentials = await obtainIdToken();
    } catch (e) {
      if (_isCancellation(e)) {
        Logger.info('[GUEST] ${provider.name} link cancelled');
        return LinkOutcome.cancelled;
      }
      Logger.error('[GUEST] ${provider.name} credential failed',
          error: e.runtimeType);
      rethrow;
    }

    try {
      await _auth.linkIdentityWithIdToken(
        provider: provider,
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
        nonce: credentials.nonce,
      );
      Logger.info('[GUEST] ${provider.name} linked to guest');
      await GuestMarker.clear();
      return LinkOutcome.linked;
    } on AuthException catch (e) {
      if (!isIdentityConflict(e)) {
        Logger.error('[GUEST] ${provider.name} link failed (code: ${e.code})');
        rethrow;
      }
      Logger.info(
          '[GUEST] ${provider.name} belongs to another account: sign in + merge');
      return _signInAndMerge(
        provider.name,
        () => _auth.signInWithIdToken(
          provider: provider,
          idToken: credentials.idToken,
          accessToken: credentials.accessToken,
          nonce: credentials.nonce,
        ),
      );
    }
  }

  /// Attaches email + name to the guest. Supabase sends a confirmation email;
  /// the password is set once the email is confirmed (Supabase does not let
  /// an anonymous user set a password before that).
  ///
  /// When the email already belongs to an account, signs in to it with
  /// [password] and merges the guest's progress into it.
  Future<LinkOutcome> linkEmail({
    required String email,
    required String password,
    required String fullName,
  }) async =>
      _reported(
          await _linkEmail(
              email: email, password: password, fullName: fullName),
          'email');

  Future<LinkOutcome> _linkEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _requireGuest();
    try {
      final response = await _auth.updateUser(
        UserAttributes(email: email, data: {'full_name': fullName}),
      );
      if (response.user?.emailConfirmedAt == null) {
        Logger.info('[GUEST] Email attached, confirmation pending');
        _awaitEmailConfirmation(password);
        return LinkOutcome.emailConfirmationSent;
      }
      await _auth.updateUser(UserAttributes(password: password));
      Logger.info('[GUEST] Email linked to guest');
      return LinkOutcome.linked;
    } on AuthException catch (e) {
      if (!isEmailConflict(e)) {
        Logger.error('[GUEST] Email link failed (code: ${e.code})');
        rethrow;
      }
      Logger.info('[GUEST] Email belongs to another account: sign in + merge');
      try {
        return await _signInAndMerge(
          'email',
          () => _auth.signInWithPassword(email: email, password: password),
        );
      } on AuthException catch (signInError) {
        if (!isInvalidCredentials(signInError)) rethrow;
        // The form asked for a NEW password; it is not this account's.
        Logger.info('[GUEST] Existing account: wrong password');
        return LinkOutcome.emailExists;
      }
    }
  }

  /// Sets the password kept by [linkEmail] once the email is confirmed.
  /// Returns true when it was set. Called automatically on auth events; the
  /// password lives only in memory, so after an app restart the user sets it
  /// through password reset instead.
  Future<bool> completePendingEmailPassword() async {
    final password = _pendingPassword;
    final user = _auth.currentUser;
    if (password == null || user == null || user.emailConfirmedAt == null) {
      return false;
    }
    _clearPendingPassword();
    try {
      await _auth.updateUser(UserAttributes(password: password));
      Logger.info('[GUEST] Password set after email confirmation');
      return true;
    } on AuthException catch (e) {
      Logger.error('[GUEST] Setting password failed (code: ${e.code})');
      return false;
    }
  }

  void _awaitEmailConfirmation(String password) {
    _pendingPassword = password;
    _emailConfirmationSub?.cancel();
    _emailConfirmationSub = _auth.onAuthStateChange.listen(
      (state) {
        if (state.session?.user.emailConfirmedAt != null) {
          unawaited(completePendingEmailPassword());
        } else if (state.event == AuthChangeEvent.signedOut) {
          _clearPendingPassword();
        }
      },
      onError: (Object _) {},
    );
  }

  void _clearPendingPassword() {
    _pendingPassword = null;
    _emailConfirmationSub?.cancel();
    _emailConfirmationSub = null;
  }

  /// Resolves a link left pending by a web redirect, or retries a merge that
  /// failed earlier. Call once the session is restored on app start, with
  /// the page URL on web. Returns null when nothing was pending or nothing
  /// could be done.
  Future<LinkOutcome?> resumePendingLink({Uri? callbackUri}) async {
    final pending = await _stash.read();
    if (pending == null) return null;
    final outcome = await _resume(pending, callbackUri);
    return outcome == null ? null : _reported(outcome, pending.provider);
  }

  Future<LinkOutcome?> _resume(
      PendingGuestMerge pending, Uri? callbackUri) async {
    final user = _auth.currentUser;
    if (user == null) {
      Logger.debug('[GUEST] Pending link kept: no session yet');
      return null;
    }

    if (user.id == pending.guestUserId) {
      if (!user.isAnonymous) {
        await _stash.clear();
        Logger.info('[GUEST] ${pending.provider} linked after redirect');
        return LinkOutcome.linked;
      }
      if (callbackUri != null && uriHasIdentityConflict(callbackUri)) {
        // Still the guest; the identity belongs to another account. Sign in
        // to it — the merge runs when this method is called after that
        // redirect, with the guest token kept in the stash.
        final provider = _providerByName(pending.provider);
        if (provider == null) {
          await _stash.clear();
          return null;
        }
        Logger.info(
            '[GUEST] ${pending.provider} belongs to another account: redirecting to sign in');
        final launched = await _webOAuth(provider, link: false);
        if (!launched) {
          await _stash.clear();
          return LinkOutcome.cancelled;
        }
        return LinkOutcome.redirecting;
      }
      // The guest abandoned the redirect. Drop the token once it is useless.
      if (_isJwtExpired(pending.guestToken)) await _stash.clear();
      return null;
    }

    if (user.isAnonymous) {
      // A different guest: the stored token cannot be merged anywhere useful.
      await _stash.clear();
      return null;
    }

    if (_isJwtExpired(pending.guestToken)) {
      Logger.warning('[GUEST] Pending merge dropped: guest token expired');
      await _stash.clear();
      return LinkOutcome.mergeFailed;
    }
    return _merge(pending);
  }

  Future<LinkOutcome> _linkOnWeb(OAuthProvider provider) async {
    final guestToken = await _freshGuestAccessToken();
    await _stash.write(PendingGuestMerge(
      guestToken: guestToken,
      guestUserId: _auth.currentUser!.id,
      provider: provider.name,
    ));
    Logger.info('[GUEST] Redirecting to link ${provider.name}');
    final launched = await _webOAuth(provider, link: true);
    if (!launched) {
      await _stash.clear();
      return LinkOutcome.cancelled;
    }
    return LinkOutcome.redirecting;
  }

  /// Captures the guest token, signs in with [signIn], then merges.
  /// If [signIn] throws the app is still the guest and the error propagates.
  Future<LinkOutcome> _signInAndMerge(
    String provider,
    Future<AuthResponse> Function() signIn,
  ) async {
    final guestToken = await _freshGuestAccessToken();
    final guestUserId = _auth.currentUser!.id;

    final response = await signIn();
    if (response.session == null) {
      throw const AuthException('Sign-in returned no session');
    }
    Logger.info('[GUEST] Signed in to existing account; merging guest');

    return _merge(PendingGuestMerge(
      guestToken: guestToken,
      guestUserId: guestUserId,
      provider: provider,
    ));
  }

  Future<LinkOutcome> _merge(PendingGuestMerge pending) async {
    try {
      final response = await _functions.invoke(
        _mergeFunction,
        headers: {_guestTokenHeader: pending.guestToken},
      );
      await _stash.clear();
      await GuestMarker.clear();
      Logger.info('[GUEST] Guest progress merged (status ${response.status})');
      return LinkOutcome.mergedIntoExisting;
    } on FunctionException catch (e) {
      // 4xx: the server rejected the guest token for good — do not retry.
      final permanent = e.status >= 400 && e.status < 500;
      Logger.error(
          '[GUEST] Guest merge failed (status ${e.status}, retry: ${!permanent})');
      await _keepForRetry(pending, retry: !permanent);
      return LinkOutcome.mergeFailed;
    } catch (e) {
      Logger.error('[GUEST] Guest merge failed', error: e.runtimeType);
      await _keepForRetry(pending, retry: true);
      return LinkOutcome.mergeFailed;
    }
  }

  Future<void> _keepForRetry(PendingGuestMerge pending,
      {required bool retry}) async {
    try {
      retry ? await _stash.write(pending) : await _stash.clear();
    } catch (e) {
      Logger.warning(
          '[GUEST] Could not update pending merge (${e.runtimeType})');
    }
  }

  /// The guest's access token, refreshed first when it is about to expire so
  /// the server can still verify it after we leave the guest session.
  Future<String> _freshGuestAccessToken() async {
    final session = _auth.currentSession;
    if (session == null) throw StateError('No guest session');
    final expiresAt = session.expiresAt;
    final expiresSoon = expiresAt != null &&
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            .isBefore(DateTime.now().add(_minGuestTokenLifetime));
    if (!expiresSoon) return session.accessToken;

    Logger.info('[GUEST] Refreshing guest token before leaving the session');
    final refreshed = await _auth.refreshSession();
    final token = refreshed.session?.accessToken;
    if (token == null) {
      throw const AuthException('Guest session could not be refreshed');
    }
    return token;
  }

  void _requireGuest() {
    if (!isGuest) {
      throw StateError('Linking needs a guest session');
    }
  }

  /// True for GoTrue's "identity already linked to another user" error.
  @visibleForTesting
  static bool isIdentityConflict(AuthException e) {
    final haystack = '${e.code} ${e.statusCode} ${e.message}'.toLowerCase();
    return haystack.contains('identity_already_exists') ||
        haystack.contains('already linked');
  }

  /// True when a password sign-in was refused for wrong credentials.
  @visibleForTesting
  static bool isInvalidCredentials(AuthException e) {
    if (e.code?.toLowerCase() == 'invalid_credentials') return true;
    return e.message.toLowerCase().contains('invalid login credentials');
  }

  /// True when updateUser(email) hit an email owned by another account.
  @visibleForTesting
  static bool isEmailConflict(AuthException e) {
    final code = e.code?.toLowerCase();
    if (code == 'email_exists' || code == 'user_already_exists') return true;
    final message = e.message.toLowerCase();
    return message.contains('already been registered') ||
        message.contains('already registered');
  }

  /// True when a web callback URL reports an identity conflict, in the query
  /// or the fragment.
  @visibleForTesting
  static bool uriHasIdentityConflict(Uri uri) {
    final fragmentParams = uri.fragment.contains('=')
        ? Uri.splitQueryString(uri.fragment)
        : const <String, String>{};
    final params = {...uri.queryParameters, ...fragmentParams};
    return [params['error_code'], params['error'], params['error_description']]
        .whereType<String>()
        .any((v) =>
            v.toLowerCase().contains('identity_already_exists') ||
            v.toLowerCase().contains('already linked'));
  }

  static bool _isCancellation(Object e) {
    if (e is auth_exceptions.OAuthCancelledException) return true;
    if (e is SignInWithAppleAuthorizationException) {
      return e.code == AuthorizationErrorCode.canceled;
    }
    if (e is GoogleSignInException) {
      return e.code == GoogleSignInExceptionCode.canceled;
    }
    return false;
  }

  static OAuthProvider? _providerByName(String name) {
    if (name == OAuthProvider.google.name) return OAuthProvider.google;
    if (name == OAuthProvider.apple.name) return OAuthProvider.apple;
    return null;
  }

  static bool _isJwtExpired(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! int) return true;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          .isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  void dispose() => _clearPendingPassword();
}
