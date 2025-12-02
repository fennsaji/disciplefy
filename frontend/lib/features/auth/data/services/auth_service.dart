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

  /// Gets the current authenticated user.
  ///
  /// @returns The authenticated [User] or `null` if not authenticated.
  User? get currentUser => _authService.currentUser;

  /// Checks if user is authenticated (either via Supabase or anonymous session).
  ///
  /// @returns `true` if authenticated, `false` otherwise.
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Asynchronously checks authentication status including anonymous sessions.
  ///
  /// @returns `false` only for legitimate unauthenticated state, not for errors.
  Future<bool> isAuthenticatedAsync() async =>
      _authService.isAuthenticatedAsync();

  /// Checks if the current authentication token is valid and not expiring soon.
  ///
  /// @returns `false` if token expires within 5 minutes or session is null.
  Future<bool> isTokenValid() async => _authService.isTokenValid();

  /// Ensures the authentication token is valid, refreshing if necessary.
  ///
  /// This is the recommended method for checking auth before API calls.
  ///
  /// @returns `true` if token is valid or was successfully refreshed.
  Future<bool> ensureTokenValid() async => _authService.ensureTokenValid();

  /// Refreshes the current authentication token.
  ///
  /// @returns `true` if refresh succeeded, `false` otherwise.
  Future<bool> refreshToken() async => _authService.refreshToken();

  /// Stream of authentication state changes for real-time auth monitoring.
  ///
  /// @returns A stream of [AuthState] updates.
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;

  /// Signs in with Google OAuth using custom backend callback flow.
  ///
  /// @returns `true` if sign-in succeeded, `false` otherwise.
  Future<bool> signInWithGoogle() async => _authService.signInWithGoogle();

  /// Processes Google OAuth callback with the provided authorization code.
  ///
  /// @returns `true` if callback processing and sign-in succeeded, `false` otherwise.
  Future<bool> processGoogleOAuthCallback(
          GoogleOAuthCallbackParams params) async =>
      _authService.processGoogleOAuthCallback(params);

  /// Signs in with Apple OAuth (iOS/Web only).
  ///
  /// @returns `true` if sign-in succeeded, `false` otherwise.
  Future<bool> signInWithApple() async => _authService.signInWithApple();

  /// Signs in anonymously using Supabase with custom backend session.
  ///
  /// @returns `true` if anonymous sign-in succeeded, `false` otherwise.
  Future<bool> signInAnonymously() async => _authService.signInAnonymously();

  /// Signs up with email, password, and full name.
  ///
  /// Creates a new user account with email/password authentication.
  /// The user's full name is stored in user metadata.
  ///
  /// @returns `true` if sign-up succeeded, `false` otherwise.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async =>
      _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );

  /// Signs in with email and password.
  ///
  /// Authenticates an existing user with their email and password.
  ///
  /// @returns `true` if sign-in succeeded, `false` otherwise.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _authService.signInWithEmail(
        email: email,
        password: password,
      );

  /// Sends a password reset email to the specified email address.
  ///
  /// @param email The email address to send the reset link to.
  Future<void> sendPasswordResetEmail(String email) async =>
      _authService.sendPasswordResetEmail(email);

  /// Check if current user's email is verified.
  ///
  /// Returns true if the user has verified their email address.
  /// For non-email auth users (Google, anonymous), returns true.
  bool get isEmailVerified => _authService.isEmailVerified;

  /// Resend email verification link.
  ///
  /// Sends a new verification email to the current user.
  /// Only works for email auth users who haven't verified yet.
  Future<void> resendVerificationEmail() async =>
      _authService.resendVerificationEmail();

  /// Sync email verification status from Supabase to user profile.
  ///
  /// Call this when user returns to app after clicking verification link.
  /// If Supabase shows email as confirmed, updates the profile accordingly.
  Future<bool> syncEmailVerificationStatus() async =>
      _authService.syncEmailVerificationStatus();

  /// Signs out the current user and clears all session data.
  Future<void> signOut() async => _authService.signOut();

  /// Deletes the user account and all associated data permanently.
  Future<void> deleteAccount() async => _authService.deleteAccount();

  /// Creates a mock User object for anonymous sessions.
  ///
  /// @returns A [User] instance with anonymous user data.
  User createAnonymousUser() => _authService.createAnonymousUser();

  // ===== STORAGE FACADE METHODS =====

  /// Retrieves the stored user type from secure storage.
  ///
  /// @returns The user type string or `null` if not stored.
  Future<String?> getUserType() async => await _storageService.getUserType();

  /// Retrieves the stored user ID from secure storage.
  ///
  /// @returns The user ID string or `null` if not stored.
  Future<String?> getUserId() async => await _storageService.getUserId();

  /// Checks if the user has completed the onboarding flow.
  ///
  /// @returns `true` if onboarding is completed, `false` otherwise.
  Future<bool> isOnboardingCompleted() async =>
      await _storageService.isOnboardingCompleted();

  /// Stores authentication data in secure storage.
  ///
  /// [params] Authentication data parameters to store.
  Future<void> storeAuthData(AuthDataStorageParams params) async =>
      await _storageService.storeAuthData(params);

  /// Clears stored authentication data from secure storage only.
  ///
  /// Use [ClearUserDataUseCase] for comprehensive data cleanup instead.
  Future<void> clearSecureStorage() async =>
      await _storageService.clearSecureStorage();

  /// Legacy method for clearing all stored data.
  ///
  /// @deprecated Use [ClearUserDataUseCase] for comprehensive data cleanup instead.
  @Deprecated('Use ClearUserDataUseCase for comprehensive data cleanup instead')
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
