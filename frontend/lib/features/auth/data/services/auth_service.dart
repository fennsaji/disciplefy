import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/auth_params.dart';
import 'authentication_service.dart';
import 'auth_storage_service.dart';

/// REFACTORED: Facade pattern for backward compatibility
/// Now delegates to specialized services following Single Responsibility Principle
///
/// This maintains the existing API while internally using:
/// - AuthenticationService: Core auth state and session management
/// - AuthStorageService: Secure data storage operations
class AuthService {
  final AuthenticationService _authService;
  final AuthStorageService _storageService;

  /// Constructor with dependency injection for better testability
  AuthService({
    AuthenticationService? authenticationService,
    AuthStorageService? storageService,
  })  : _authService = authenticationService ?? AuthenticationService(),
        _storageService = storageService ?? AuthStorageService() {
    // Set up profile sync monitoring for OAuth users
    _monitorForProfileSync();
  }

  /// Get current authenticated user
  User? get currentUser => _authService.currentUser;

  /// Check if user is authenticated (either via Supabase or anonymous session)
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Async method to check authentication status including anonymous sessions
  /// Returns false only for legitimate unauthenticated state, not for errors
  Future<bool> isAuthenticatedAsync() async =>
      _authService.isAuthenticatedAsync();

  /// Check if the current token is valid and not expiring soon
  /// Returns false if token expires within 5 minutes or session is null
  Future<bool> isTokenValid() async => _authService.isTokenValid();

  /// Listen to authentication state changes
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;

  /// Sign in with Google OAuth using custom backend callback
  Future<bool> signInWithGoogle() async => _authService.signInWithGoogle();

  /// Process Google OAuth callback with authorization code
  Future<bool> processGoogleOAuthCallback(
          GoogleOAuthCallbackParams params) async =>
      _authService.processGoogleOAuthCallback(params);

  /// Sign in with Apple OAuth (iOS/Web only)
  Future<bool> signInWithApple() async => _authService.signInWithApple();

  /// Sign in anonymously using Supabase + custom backend session
  Future<bool> signInAnonymously() async => _authService.signInAnonymously();

  /// Sign out current user
  Future<void> signOut() async => _authService.signOut();

  /// Send OTP to phone number for authentication
  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phoneNumber,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Phone sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Send magic link to email for authentication
  Future<void> signInWithEmail(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Email sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Verify OTP for phone or email authentication
  Future<AuthResponse> verifyOTP({
    required String identifier,
    required String otp,
    required String method,
  }) async {
    try {
      if (method == 'phone') {
        return await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.sms,
          phone: identifier,
          token: otp,
        );
      } else {
        return await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.email,
          email: identifier,
          token: otp,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('OTP verification error: $e');
      }
      rethrow;
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteAccount() async => _authService.deleteAccount();

  /// Creates a mock User object for anonymous sessions
  User createAnonymousUser() => _authService.createAnonymousUser();

  // ===== STORAGE FACADE METHODS =====

  /// Get stored user type
  Future<String?> getUserType() async => await _storageService.getUserType();

  /// Get stored user ID
  Future<String?> getUserId() async => await _storageService.getUserId();

  /// Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async =>
      await _storageService.isOnboardingCompleted();

  /// Store authentication data
  Future<void> storeAuthData(AuthDataStorageParams params) async =>
      await _storageService.storeAuthData(params);

  /// Clear all stored auth data
  Future<void> clearAllData() async => await _storageService.clearAllData();

  /// Monitor authentication changes for profile sync
  void _monitorForProfileSync() {
    // Check if user is already signed in with OAuth (for existing sessions)
    _checkExistingOAuthUser();

    // Listen to auth state changes and sync profile for new OAuth users
    authStateChanges.listen((authState) async {
      if (authState.event == AuthChangeEvent.signedIn) {
        // Check current user after sign in event
        final user = currentUser;
        if (user != null && !user.isAnonymous) {
          // New OAuth user signed in - trigger profile sync
          if (kDebugMode) {
            print(
                '🔄 [AUTH SERVICE] OAuth user signed in, triggering profile sync');
          }
          await _authService.testOAuthProfileSync();
        }
      }
    });
  }

  /// Check if there's an existing OAuth user and sync profile if needed
  Future<void> _checkExistingOAuthUser() async {
    // Small delay to ensure initialization is complete
    await Future.delayed(const Duration(milliseconds: 500));

    if (currentUser != null && !currentUser!.isAnonymous) {
      if (kDebugMode) {
        print(
            '🔄 [AUTH SERVICE] Found existing OAuth user, triggering profile sync');
        print(
            '🔄 [AUTH SERVICE] User: ${currentUser!.email} (${currentUser!.id})');
      }
      await _authService.testOAuthProfileSync();
    }
  }

  /// Dispose resources
  void dispose() => _authService.dispose();
}
