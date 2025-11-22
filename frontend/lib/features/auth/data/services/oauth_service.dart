import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;

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
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
      }
      rethrow;
    }
  }

  /// Mobile Google Sign-In using native Google Sign-In SDK
  Future<bool> _signInWithGoogleMobile() async {
    try {
      print('🔐 [OAUTH SERVICE] 🚀 Starting Mobile Google Sign-In...');

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
      print('🔐 [OAUTH SERVICE] 🔧 Initializing Google Sign-In plugin...');
      print('🔐 [OAUTH SERVICE] - Using serverClientId: $webClientId');
      await googleSignIn.initialize(
        serverClientId: webClientId,
      );

      // Trigger Google Sign-In flow
      print('🔐 [OAUTH SERVICE] 📱 Launching Google Sign-In UI...');
      final GoogleIdentity googleUser = await googleSignIn.authenticate();

      print(
          '🔐 [OAUTH SERVICE] ✅ Google account selected: ${googleUser.email}');

      // Get authentication tokens
      print('🔐 [OAUTH SERVICE] 🔑 Retrieving authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          (googleUser as GoogleSignInAccount).authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('🔐 [OAUTH SERVICE] ❌ Failed to get ID token from Google');
        throw auth_exceptions.AuthenticationFailedException(
            'Failed to authenticate with Google');
      }

      print('🔐 [OAUTH SERVICE] ✅ ID token received');
      print(
          '🔐 [OAUTH SERVICE] 🔄 Signing in to Supabase with Google credentials...');

      // Sign in to Supabase with Google ID token
      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user == null) {
        print('🔐 [OAUTH SERVICE] ❌ Supabase sign-in failed');
        throw auth_exceptions.AuthenticationFailedException(
            'Failed to create Supabase session');
      }

      print('🔐 [OAUTH SERVICE] ✅ Supabase session created successfully');
      print('🔐 [OAUTH SERVICE] - User: ${response.user!.email}');
      print('🔐 [OAUTH SERVICE] - User ID: ${response.user!.id}');

      return true;
    } on auth_exceptions.OAuthCancelledException {
      rethrow;
    } catch (e) {
      print('🔐 [OAUTH SERVICE] ❌ Mobile Google Sign-In Error: $e');

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
      print('🔐 [OAUTH SERVICE] 🚀 Starting Google OAuth NATIVE PKCE flow...');
      print('🔐 [OAUTH SERVICE] - Supabase server: 127.0.0.1:54321');
      print(
          '🔐 [OAUTH SERVICE] - OAuth callback: 127.0.0.1:54321/auth/v1/callback');
      print(
          '🔐 [OAUTH SERVICE] - Using pure PKCE flow (NO custom Flutter callbacks)');

      // CRITICAL FIX: Pure native Supabase PKCE flow
      // With backend config fixed, OAuth will redirect to Supabase auth endpoint
      // This enables proper PKCE token exchange and session establishment
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // NO redirectTo - Supabase will use its configured auth endpoint
        // NO authScreenLaunchMode - use default platform behavior
      );

      print('🔐 [OAUTH SERVICE] ✅ OAuth PKCE flow initiated successfully');
      print(
          '🔐 [OAUTH SERVICE] - Google will redirect to: 127.0.0.1:54321/auth/v1/callback');
      print(
          '🔐 [OAUTH SERVICE] - Supabase will handle PKCE token exchange automatically');

      // Wait for Supabase to process the OAuth callback and establish session
      // The auth state change listener will detect the successful authentication
      return response;
    } catch (e) {
      print('🔐 [OAUTH SERVICE] ❌ Web Google OAuth PKCE Error: $e');

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
      print('🔐 [OAUTH SERVICE] 🔍 Checking for established OAuth session...');

      // First, check if session already exists
      final currentSession = Supabase.instance.client.auth.currentSession;

      if (currentSession != null) {
        print('🔐 [OAUTH SERVICE] ✅ OAuth session found immediately');
        print('🔐 [OAUTH SERVICE] - User: ${currentSession.user.email}');
        print(
            '🔐 [OAUTH SERVICE] - Provider: ${currentSession.user.appMetadata['provider'] ?? 'unknown'}');
        print(
            '🔐 [OAUTH SERVICE] - Session ID: ${currentSession.accessToken.substring(0, 20)}...');
        return true;
      }

      // For PKCE flow, Supabase may need time to process the callback
      print('🔐 [OAUTH SERVICE] ⏳ Waiting for Supabase PKCE token exchange...');

      // Wait in intervals to check for session establishment
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          print(
              '🔐 [OAUTH SERVICE] ✅ OAuth session established after ${(i + 1) * 500}ms');
          print('🔐 [OAUTH SERVICE] - User: ${session.user.email}');
          print(
              '🔐 [OAUTH SERVICE] - Provider: ${session.user.appMetadata['provider'] ?? 'unknown'}');
          return true;
        }

        print('🔐 [OAUTH SERVICE] ⏳ Still waiting... (attempt ${i + 1}/10)');
      }

      print('🔐 [OAUTH SERVICE] ⚠️ No OAuth session found after 5 seconds');
      print(
          '🔐 [OAUTH SERVICE] ⚠️ This may indicate PKCE flow failed or configuration issues');
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [OAUTH SERVICE] ❌ Error checking OAuth session: $e');
      }
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
      print('🔐 [OAUTH SERVICE] 🔍 Processing OAuth callback...');

      // Check if session is already established (common with PKCE flow)
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        print('🔐 [OAUTH SERVICE] ✅ OAuth session already established');
        return true;
      }

      // If no session exists, wait briefly for Supabase to process the callback
      await Future.delayed(const Duration(milliseconds: 1000));

      final laterSession = Supabase.instance.client.auth.currentSession;
      if (laterSession != null) {
        print('🔐 [OAUTH SERVICE] ✅ OAuth session established after delay');
        return true;
      }

      print(
          '🔐 [OAUTH SERVICE] ⚠️ No OAuth session found after callback processing');
      return false;
    } catch (e) {
      print('🔐 [OAUTH SERVICE] ❌ Error processing OAuth callback: $e');
      rethrow;
    }
  }

  /// Check if there's an existing anonymous session for potential migration
  Future<String?> _getExistingAnonymousUserId() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        print(
            '🔐 [OAUTH SERVICE] 👤 Found existing anonymous user: ${currentUser.id}');
        return currentUser.id;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [OAUTH SERVICE] ⚠️ Error checking anonymous session: $e');
      }
      return null;
    }
  }

  /// Sign in with Apple OAuth (iOS/Web only)
  /// FIXED: Updated for corrected PKCE flow configuration
  Future<bool> signInWithApple() async {
    try {
      print('🍎 [OAUTH SERVICE] 🚀 Starting Apple OAuth PKCE flow...');

      // FIXED: Same as Google - use native Supabase PKCE flow
      // Apple OAuth will also redirect to Supabase auth endpoints
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        // NO redirectTo - native PKCE flow with Supabase auth endpoints
        // NO authScreenLaunchMode - use default platform behavior
      );

      print(
          '🍎 [OAUTH SERVICE] ✅ Apple OAuth PKCE flow initiated successfully');
      return true;
    } catch (e) {
      print('🍎 [OAUTH SERVICE] ❌ Apple Sign-In Error: $e');

      if (e.toString().contains('redirect_uri_mismatch')) {
        throw auth_exceptions.AuthConfigException(
            'Apple OAuth redirect URI mismatch. Ensure Apple Developer Console configuration matches Supabase auth endpoints.');
      }

      rethrow;
    }
  }

  /// Sign out from Google if available
  Future<void> signOutFromGoogle() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
        print('🔐 [OAUTH SERVICE] ✅ Signed out from Google');
      } catch (e) {
        print('🔐 [OAUTH SERVICE] ⚠️ Error signing out from Google: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    // Google Sign-In doesn't need explicit disposal
  }
}
