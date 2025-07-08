import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/app_config.dart';

/// Authentication service handling OAuth providers and Supabase integration
/// References: Security Design Plan, Technical Architecture Document
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  GoogleSignIn? _googleSignIn;

  AuthService() {
    _initializeGoogleSignIn();
  }

  void _initializeGoogleSignIn() {
    if (!kIsWeb && AppConfig.googleClientId.isNotEmpty) {
      _googleSignIn = GoogleSignIn(
        clientId: AppConfig.googleClientId,
        scopes: ['email', 'profile'],
      );
    }
  }

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Listen to authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-based Google OAuth
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: AppConfig.authRedirectUrl,
        );
        return true;
      } else {
        // Mobile Google Sign-In
        if (_googleSignIn == null) {
          throw Exception('Google Sign-In not configured for mobile platform');
        }

        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In was cancelled');
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('Failed to get Google authentication tokens');
        }

        await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken!,
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with Apple OAuth (iOS/Web only)
  Future<bool> signInWithApple() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: AppConfig.authRedirectUrl,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Apple Sign-In Error: $e');
      }
      rethrow;
    }
  }

  /// Sign in anonymously
  Future<bool> signInAnonymously() async {
    try {
      await _supabase.auth.signInAnonymously();
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
      // Sign out from Google if available
      if (_googleSignIn != null && await _googleSignIn!.isSignedIn()) {
        await _googleSignIn!.signOut();
      }
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Sign-Out Error: $e');
      }
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isAuthenticated) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Get User Profile Error: $e');
      }
      return null;
    }
  }

  /// Create or update user profile
  Future<void> upsertUserProfile({
    required String languagePreference,
    String themePreference = 'light',
  }) async {
    if (!isAuthenticated) return;

    try {
      await _supabase.from('user_profiles').upsert({
        'id': currentUser!.id,
        'language_preference': languagePreference,
        'theme_preference': themePreference,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Upsert User Profile Error: $e');
      }
      rethrow;
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;

    try {
      // Delete user profile (cascade will handle related data)
      await _supabase
          .from('user_profiles')
          .delete()
          .eq('id', currentUser!.id);
      
      // Sign out after deletion
      await signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Delete Account Error: $e');
      }
      rethrow;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (!isAuthenticated) return false;

    try {
      final profile = await getUserProfile();
      return profile?['is_admin'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('Check Admin Status Error: $e');
      }
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    // Google Sign-In doesn't need explicit disposal
    // Supabase client is managed globally
  }
}