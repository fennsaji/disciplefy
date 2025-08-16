import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;
import '../../domain/utils/auth_validator.dart';
import 'auth_storage_service.dart';
import 'oauth_service.dart';

/// Core authentication service that orchestrates auth operations
/// Handles Supabase integration, anonymous sessions, and user state management
class AuthenticationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthStorageService _storageService;
  final OAuthService _oauthService;

  AuthenticationService({
    AuthStorageService? storageService,
    OAuthService? oauthService,
  })  : _storageService = storageService ?? AuthStorageService(),
        _oauthService = oauthService ?? OAuthService();

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is authenticated (either via Supabase or anonymous session)
  bool get isAuthenticated {
    // Check Supabase authentication first
    if (currentUser != null) {
      return true;
    }

    // Note: For anonymous sessions, use isAuthenticatedAsync() method
    // This synchronous getter only checks Supabase authentication
    return false;
  }

  /// Async method to check authentication status including anonymous sessions
  /// Returns false only for legitimate unauthenticated state, not for errors
  Future<bool> isAuthenticatedAsync() async {
    // REFACTORED: Use centralized authentication validation
    final validationResult = await AuthValidator.validateCurrentAuthState(
      supabaseUser: currentUser,
      getUserType: _storageService.getUserType,
    );

    if (validationResult.isAuthenticated) {
      return true;
    } else if (validationResult.isError) {
      // Handle validation errors - propagate critical ones, handle recoverable ones
      final errorMessage = validationResult.errorMessage!;

      if (kDebugMode) {
        print('🔐 [AUTH] Authentication validation error: $errorMessage');
      }

      // For storage-related errors, this is critical and should not be masked
      if (errorMessage.contains('storage') ||
          errorMessage.contains('permission') ||
          errorMessage.contains('PlatformException')) {
        throw const auth_exceptions.AuthenticationFailedException(
          'Storage access failed: Unable to verify authentication status. Please sign in again.',
        );
      }

      // For other validation errors, treat as unauthenticated
      return false;
    }

    // Unauthenticated state
    return false;
  }

  /// Listen to authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Check if the current token is valid and not expiring soon
  /// Returns false if token expires within 5 minutes or session is null
  Future<bool> isTokenValid() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return false;

    // Check if token expires within 5 minutes
    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));

    final isValid = expiresAt.isAfter(fiveMinutesFromNow);

    if (kDebugMode) {
      print('🔐 [TOKEN VALIDATION] Current time: ${DateTime.now()}');
      print('🔐 [TOKEN VALIDATION] Token expires at: $expiresAt');
      print('🔐 [TOKEN VALIDATION] Token valid: $isValid');
      if (!isValid) {
        final timeUntilExpiry = expiresAt.difference(DateTime.now());
        print(
            '🔐 [TOKEN VALIDATION] ⚠️ Token expires in: ${timeUntilExpiry.inMinutes} minutes');
      }
    }

    return isValid;
  }

  /// Sign in with Google OAuth using native Supabase PKCE flow
  /// FIXED: Updated for corrected backend configuration
  Future<bool> signInWithGoogle() async {
    try {
      print('🔐 [AUTH SERVICE] 🚀 Initiating Google OAuth PKCE flow...');
      print(
          '🔐 [AUTH SERVICE] - Backend: OAuth redirects to Supabase auth endpoints');

      final success = await _oauthService.signInWithGoogle();

      if (success) {
        print(
            '🔐 [AUTH SERVICE] ✅ Google OAuth PKCE flow initiated successfully');

        // For corrected PKCE flow, check if session was established
        final sessionEstablished =
            await _oauthService.checkOAuthSessionEstablished();

        if (sessionEstablished && currentUser != null) {
          print('🔐 [AUTH SERVICE] ✅ Google OAuth PKCE session established');

          // Store authentication state after successful OAuth
          await _storageService.storeAuthData(
            AuthDataStorageParams.google(
              accessToken: _supabase.auth.currentSession?.accessToken ?? '',
              userId: currentUser?.id,
            ),
          );

          return true;
        } else {
          print(
              '🔐 [AUTH SERVICE] ⚠️ Google OAuth PKCE session not established');
          return false;
        }
      } else {
        print('🔐 [AUTH SERVICE] ❌ Google OAuth PKCE initiation failed');
        return false;
      }
    } catch (e) {
      print('🔐 [AUTH SERVICE] ❌ Google OAuth PKCE Error: $e');

      // Enhanced error handling for PKCE-specific issues
      if (e.toString().contains('redirect_uri_mismatch')) {
        throw auth_exceptions.AuthConfigException(
            'Google OAuth redirect URI mismatch. Ensure Google Console has http://127.0.0.1:54321/auth/v1/callback configured.');
      }

      if (e is auth_exceptions.AuthException) {
        rethrow;
      }
      throw auth_exceptions.AuthenticationFailedException(
          'Google authentication failed: ${e.toString()}');
    }
  }

  /// Process Google OAuth callback with authorization code
  Future<bool> processGoogleOAuthCallback(
      GoogleOAuthCallbackParams params) async {
    try {
      // If there's an OAuth error, handle it
      if (params.error != null) {
        if (params.error == 'access_denied') {
          throw const auth_exceptions.OAuthCancelledException(
              'Google OAuth was cancelled by user');
        }
        String errorMessage = 'Google OAuth failed';
        if (params.errorDescription != null) {
          errorMessage += ': ${params.errorDescription}';
        }
        throw auth_exceptions.AuthenticationFailedException(errorMessage);
      }

      // Call OAuth service for callback processing
      final success = await _oauthService.processOAuthCallback(
        OAuthApiCallbackParams(
          code: params.code,
          state: params.state,
        ),
      );

      if (success && currentUser != null) {
        print(
            '🔍 [DEBUG] Current user after session recovery: ${currentUser?.id}');
        print(
            '🔍 [DEBUG] Current user isAnonymous: ${currentUser?.isAnonymous}');

        // Store authentication state
        print('🔍 [DEBUG] About to store auth data...');
        await _storageService.storeAuthData(
          AuthDataStorageParams.google(
            accessToken: _supabase.auth.currentSession?.accessToken ?? '',
            userId: currentUser?.id,
          ),
        );
        print('🔍 [DEBUG] Auth data storage completed');

        // Verify what was stored
        final storedUserType = await _storageService.getUserType();
        final storedUserId = await _storageService.getUserId();
        final storedOnboarding = await _storageService.isOnboardingCompleted();
        print('🔍 [DEBUG] Storage verification:');
        print('🔍 [DEBUG] - Stored user type: $storedUserType');
        print('🔍 [DEBUG] - Stored user ID: $storedUserId');
        print('🔍 [DEBUG] - Onboarding completed: $storedOnboarding');

        return true;
      } else {
        throw const auth_exceptions.AuthenticationFailedException(
            'OAuth callback processing failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google OAuth Callback Error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with Apple OAuth (iOS/Web only)
  Future<bool> signInWithApple() async {
    final success = await _oauthService.signInWithApple();

    if (success && currentUser != null) {
      // Store authentication state after successful OAuth
      await _storageService.storeAuthData(
        AuthDataStorageParams.apple(
          accessToken: _supabase.auth.currentSession?.accessToken ?? '',
          userId: currentUser?.id,
        ),
      );
    }

    return success;
  }

  /// Sign in anonymously using Supabase + custom backend session
  Future<bool> signInAnonymously() async {
    try {
      print('🔍 [DEBUG] signInAnonymously called');
      print('🔍 [DEBUG] Stack trace: ${StackTrace.current}');

      // Step 1: Create a proper Supabase anonymous user first
      final response = await _supabase.auth.signInAnonymously();
      final user = response.user;

      if (user == null) {
        throw const auth_exceptions.AuthenticationFailedException(
            'Failed to create Supabase anonymous user');
      }

      print('🔍 [DEBUG] Supabase anonymous user created: ${user.id}');
      print(
          '🔍 [DEBUG] Anonymous user JWT token available: ${response.session?.accessToken != null}');

      // Step 2: Store auth state properly - using JWT token, not session_id
      await _storageService.storeAuthData(
        AuthDataStorageParams.guest(
          accessToken:
              response.session!.accessToken, // ✅ Using actual JWT token
          userId: user.id, // ✅ Using Supabase user ID
        ),
      );

      if (kDebugMode) {
        print('🔍 [DEBUG] Anonymous sign-in completed successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Anonymous Sign-In Error: $e');
      }
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      // Sign out from OAuth providers
      await _oauthService.signOutFromGoogle();

      // Sign out from Supabase
      await _supabase.auth.signOut();

      // Clear stored auth data
      await _storageService.clearAllData();
    } catch (e) {
      if (kDebugMode) {
        print('Sign-Out Error: $e');
      }
      rethrow;
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;

    try {
      // Note: Profile deletion should be handled by UserProfileService
      // This method only handles auth-specific cleanup

      // Sign out after profile deletion
      await signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Delete Account Error: $e');
      }
      rethrow;
    }
  }

  /// Creates a mock User object for anonymous sessions
  User createAnonymousUser() {
    // Create a minimal User object for anonymous sessions
    // This is needed because the AuthenticatedState expects a User object
    return User(
      id: 'anonymous_user',
      appMetadata: const {},
      userMetadata: const {'is_anonymous': true},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: true,
    );
  }

  /// Dispose resources
  void dispose() {
    _oauthService.dispose();
  }
}
