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
        _storageService = storageService ?? AuthStorageService();

  /// Get current authenticated user
  User? get currentUser => _authService.currentUser;

  /// Check if user is authenticated (either via Supabase or anonymous session)
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Async method to check authentication status including anonymous sessions
  /// Returns false only for legitimate unauthenticated state, not for errors
  Future<bool> isAuthenticatedAsync() async => _authService.isAuthenticatedAsync();

  /// Listen to authentication state changes
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;

  /// Sign in with Google OAuth using custom backend callback
  Future<bool> signInWithGoogle() async => _authService.signInWithGoogle();

  /// Process Google OAuth callback with authorization code
  Future<bool> processGoogleOAuthCallback(GoogleOAuthCallbackParams params) async =>
      _authService.processGoogleOAuthCallback(params);

  /// Sign in with Apple OAuth (iOS/Web only)
  Future<bool> signInWithApple() async => _authService.signInWithApple();

  /// Sign in anonymously using Supabase + custom backend session
  Future<bool> signInAnonymously() async => _authService.signInAnonymously();

  /// Sign out current user
  Future<void> signOut() async => _authService.signOut();

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
  Future<bool> isOnboardingCompleted() async => await _storageService.isOnboardingCompleted();

  /// Store authentication data
  Future<void> storeAuthData(AuthDataStorageParams params) async => await _storageService.storeAuthData(params);

  /// Clear all stored auth data
  Future<void> clearAllData() async => await _storageService.clearAllData();

  /// Dispose resources
  void dispose() => _authService.dispose();
}
