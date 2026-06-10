import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;
import '../../../../core/utils/logger.dart';

/// Dedicated service for OAuth operations
/// Handles Google OAuth flow, Apple OAuth, and third-party authentication
class OAuthService {
  final HttpService _httpService = HttpService();

  /// Sign in with Google OAuth using custom backend callback
  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-based Google OAuth with custom callback
        return await _signInWithGoogleWeb();
      } else {
        // Mobile Google Sign-In using native SDK
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      Logger.debug('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Mobile Google Sign-In using native Google Sign-In SDK
  Future<bool> _signInWithGoogleMobile() async {
    try {
      Logger.debug('🔐 [OAUTH SERVICE] 🚀 Starting Mobile Google Sign-In...');

      // CRITICAL FIX: Configure GoogleSignIn with serverClientId for Supabase
      // Supabase requires the Web OAuth Client ID to validate ID tokens
      // Get from environment variable (configured at build time via --dart-define)
      const webClientId = AppConfig.googleClientId;

      if (webClientId.isEmpty) {
        throw auth_exceptions.AuthConfigException(
            'GOOGLE_CLIENT_ID not configured. Please set via --dart-define at build time.');
      }

      // Get GoogleSignIn singleton instance
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      // Initialize with serverClientId for Supabase authentication
      Logger.debug(
          '🔐 [OAUTH SERVICE] 🔧 Initializing Google Sign-In plugin...');
      Logger.debug('🔐 [OAUTH SERVICE] - Using serverClientId: $webClientId');
      await googleSignIn.initialize(
        serverClientId: webClientId,
      );

      // Trigger Google Sign-In flow
      Logger.debug('🔐 [OAUTH SERVICE] 📱 Launching Google Sign-In UI...');
      final GoogleIdentity googleUser = await googleSignIn.authenticate();

      Logger.debug(
          '🔐 [OAUTH SERVICE] ✅ Google account selected: ${googleUser.email}');

      // Get authentication tokens
      Logger.debug('🔐 [OAUTH SERVICE] 🔑 Retrieving authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          (googleUser as GoogleSignInAccount).authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        Logger.error('🔐 [OAUTH SERVICE] ❌ Failed to get ID token from Google');
        throw auth_exceptions.AuthenticationFailedException(
            'Failed to authenticate with Google');
      }

      Logger.debug('🔐 [OAUTH SERVICE] ✅ ID token received');
      Logger.debug(
          '🔐 [OAUTH SERVICE] 🔄 Signing in to Supabase with Google credentials...');

      // Sign in to Supabase with Google ID token
      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user == null) {
        Logger.error('🔐 [OAUTH SERVICE] ❌ Supabase sign-in failed');
        throw auth_exceptions.AuthenticationFailedException(
            'Failed to create Supabase session');
      }

      Logger.debug(
          '🔐 [OAUTH SERVICE] ✅ Supabase session created successfully');
      Logger.debug('🔐 [OAUTH SERVICE] - User: ${response.user!.email}');
      Logger.debug('🔐 [OAUTH SERVICE] - User ID: ${response.user!.id}');

      return true;
    } on auth_exceptions.OAuthCancelledException {
      rethrow;
    } catch (e) {
      Logger.error('🔐 [OAUTH SERVICE] ❌ Mobile Google Sign-In Error: $e');

      if (e.toString().contains('DEVELOPER_ERROR') ||
          e.toString().contains('API_NOT_CONNECTED')) {
        throw auth_exceptions.AuthConfigException(
            'Google Sign-In configuration error. Please check SHA-1 fingerprints in Firebase Console.');
      }

      throw auth_exceptions.AuthenticationFailedException(
          'Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Web-based Google OAuth with Supabase native PKCE handling
  /// FIXED: Now properly configured to work with Supabase auth endpoints
  Future<bool> _signInWithGoogleWeb() async {
    try {
      Logger.debug(
          '🔐 [OAUTH SERVICE] 🚀 Starting Google OAuth NATIVE PKCE flow...');
      Logger.debug('🔐 [OAUTH SERVICE] - Supabase server: 127.0.0.1:54321');
      Logger.debug(
          '🔐 [OAUTH SERVICE] - OAuth callback: 127.0.0.1:54321/auth/v1/callback');
      Logger.debug(
          '🔐 [OAUTH SERVICE] - Using pure PKCE flow (NO custom Flutter callbacks)');

      // Pure native Supabase PKCE flow — no sensitive scopes at sign-in.
      // Google Meet links are generated via the Meet REST API using the
      // service account, so calendar.events scope is not needed here.
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // NO redirectTo - Supabase will use its configured auth endpoint
        // NO authScreenLaunchMode - use default platform behavior
      );

      Logger.debug(
          '🔐 [OAUTH SERVICE] ✅ OAuth PKCE flow initiated successfully');
      Logger.debug(
          '🔐 [OAUTH SERVICE] - Google will redirect to: 127.0.0.1:54321/auth/v1/callback');
      Logger.debug(
          '🔐 [OAUTH SERVICE] - Supabase will handle PKCE token exchange automatically');

      // Wait for Supabase to process the OAuth callback and establish session
      // The auth state change listener will detect the successful authentication
      return response;
    } catch (e) {
      Logger.error('🔐 [OAUTH SERVICE] ❌ Web Google OAuth PKCE Error: $e');

      // Enhanced error handling for specific PKCE configuration issues
      if (e.toString().contains('flow_state_not_found')) {
        throw auth_exceptions.AuthenticationFailedException(
            'OAuth flow state not found. Ensure Supabase server is running on 127.0.0.1:54321 and Google OAuth is configured correctly.');
      } else if (e.toString().contains('404')) {
        throw auth_exceptions.AuthConfigException(
            'OAuth endpoint not found. Verify Supabase is running and config.toml has correct auth configuration.');
      } else if (e.toString().contains('invalid_credentials')) {
        throw auth_exceptions.AuthConfigException(
            'Invalid OAuth credentials. Check Google OAuth Client ID/Secret and redirect URI configuration.');
      } else if (e.toString().contains('redirect_uri_mismatch')) {
        throw auth_exceptions.AuthConfigException(
            'OAuth redirect URI mismatch. Ensure Google OAuth Console has http://127.0.0.1:54321/auth/v1/callback configured.');
      }

      rethrow;
    }
  }

  /// Check if Supabase session was established after OAuth
  /// ENHANCED: Better session detection for corrected PKCE flow
  Future<bool> checkOAuthSessionEstablished() async {
    try {
      Logger.debug(
          '🔐 [OAUTH SERVICE] 🔍 Checking for established OAuth session...');

      // First, check if session already exists
      final currentSession = Supabase.instance.client.auth.currentSession;

      if (currentSession != null) {
        Logger.debug(
            '🔐 [OAUTH SERVICE] ✅ Session found for user: ${currentSession.user.id}');

        final isAnonKey =
            currentSession.accessToken == AppConfig.supabaseAnonKey;
        if (isAnonKey) {
          Logger.warning(
              '🚨 [OAUTH SERVICE] Session contains anon key instead of user JWT!');
        }

        return true;
      }

      // For PKCE flow, Supabase may need time to process the callback
      Logger.debug(
          '🔐 [OAUTH SERVICE] ⏳ Waiting for Supabase PKCE token exchange...');

      // Wait in intervals to check for session establishment
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          Logger.debug(
              '🔐 [OAUTH SERVICE] ✅ Session established after ${(i + 1) * 500}ms for user: ${session.user.id}');

          final isAnonKey = session.accessToken == AppConfig.supabaseAnonKey;
          if (isAnonKey) {
            Logger.warning(
                '🚨 [OAUTH SERVICE] Session contains anon key instead of user JWT!');
          }

          return true;
        }

        Logger.warning(
            '🔐 [OAUTH SERVICE] ⏳ Still waiting... (attempt ${i + 1}/10)');
      }

      Logger.debug(
          '🔐 [OAUTH SERVICE] ⚠️ No OAuth session found after 5 seconds');
      Logger.error(
          '🔐 [OAUTH SERVICE] ⚠️ This may indicate PKCE flow failed or configuration issues');
      return false;
    } catch (e) {
      Logger.error('🔐 [OAUTH SERVICE] ❌ Error checking OAuth session: $e');
      throw auth_exceptions.AuthenticationFailedException(
          'Failed to verify OAuth session: ${e.toString()}');
    }
  }

  /// Process OAuth callback with authorization code (for custom flows)
  /// This method is primarily used for handling callbacks from custom OAuth implementations
  Future<bool> processOAuthCallback(dynamic params) async {
    try {
      // For Supabase native PKCE flow, we typically don't need to process callbacks manually
      // The session is established automatically by Supabase's OAuth handling
      Logger.debug('🔐 [OAUTH SERVICE] 🔍 Processing OAuth callback...');

      // Check if session is already established (common with PKCE flow)
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        Logger.debug('🔐 [OAUTH SERVICE] ✅ OAuth session already established');
        return true;
      }

      // If no session exists, wait briefly for Supabase to process the callback
      await Future.delayed(const Duration(milliseconds: 1000));

      final laterSession = Supabase.instance.client.auth.currentSession;
      if (laterSession != null) {
        Logger.debug(
            '🔐 [OAUTH SERVICE] ✅ OAuth session established after delay');
        return true;
      }

      Logger.warning(
          '🔐 [OAUTH SERVICE] ⚠️ No OAuth session found after callback processing');
      return false;
    } catch (e) {
      Logger.error('🔐 [OAUTH SERVICE] ❌ Error processing OAuth callback: $e');
      rethrow;
    }
  }

  /// Native Sign in with Apple (iOS).
  ///
  /// Uses the native Apple authorization sheet via `sign_in_with_apple`, then
  /// exchanges the returned identity token with Supabase via [signInWithIdToken].
  /// A hashed nonce is sent to Apple and the raw nonce to Supabase so the token
  /// can be verified without weakening security (no "skip nonce" required).
  Future<bool> signInWithApple() async {
    try {
      Logger.debug('🍎 [OAUTH SERVICE] 🚀 Starting native Apple Sign-In...');

      // Nonce: Apple receives the SHA-256 hash, Supabase receives the raw value.
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw auth_exceptions.AuthenticationFailedException(
            'Apple Sign-In did not return an identity token');
      }

      Logger.debug('🍎 [OAUTH SERVICE] ✅ Apple credential received');

      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user == null) {
        throw auth_exceptions.AuthenticationFailedException(
            'Failed to create Supabase session');
      }

      // Apple returns the user's name ONLY on the first authorization. Persist
      // it to user metadata so the profile isn't left blank on later logins.
      final fullName = [credential.givenName, credential.familyName]
          .where((p) => p != null && p.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'full_name': fullName, 'name': fullName}),
          );
        } catch (e) {
          Logger.error(
              '🍎 [OAUTH SERVICE] Failed to set Apple display name: $e');
        }
      }

      Logger.debug('🍎 [OAUTH SERVICE] ✅ Supabase session created via Apple');
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const auth_exceptions.OAuthCancelledException(
            'Apple Sign-In was cancelled');
      }
      Logger.error(
          '🍎 [OAUTH SERVICE] ❌ Apple authorization error: ${e.code} - ${e.message}');
      throw auth_exceptions.AuthenticationFailedException(
          'Apple Sign-In failed: ${e.message}');
    } on auth_exceptions.OAuthCancelledException {
      rethrow;
    } catch (e) {
      Logger.error('🍎 [OAUTH SERVICE] ❌ Apple Sign-In Error: $e');
      throw auth_exceptions.AuthenticationFailedException(
          'Apple Sign-In failed: ${e.toString()}');
    }
  }

  /// Generates a cryptographically secure random nonce for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Sign out from Google if available
  Future<void> signOutFromGoogle() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
        Logger.debug('🔐 [OAUTH SERVICE] ✅ Signed out from Google');
      } catch (e) {
        Logger.debug('🔐 [OAUTH SERVICE] ⚠️ Error signing out from Google: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    // Google Sign-In doesn't need explicit disposal
  }
}
