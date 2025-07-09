import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  /// Sign in with Google OAuth using custom backend callback
  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-based Google OAuth with custom callback
        return await _signInWithGoogleWeb();
      } else {
        // Mobile Google Sign-In with custom callback
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
      }
      rethrow;
    }
  }

  /// Web-based Google OAuth with custom callback
  Future<bool> _signInWithGoogleWeb() async {
    // Initialize Google OAuth flow
    final redirectUrl = AppConfig.authRedirectUrl;
    
    try {
      // Use Supabase's OAuth to get the authorization code
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
      // Note: The OAuth redirect will be handled by platform-specific code
      // and will eventually call our callback API
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Web Google OAuth Error: $e');
      }
      rethrow;
    }
  }

  /// Mobile Google Sign-In with custom callback
  Future<bool> _signInWithGoogleMobile() async {
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

    // Get the authorization code from Google
    final String authorizationCode = googleAuth.accessToken!;
    
    // Call our custom backend callback
    return await _callGoogleOAuthCallback(
      code: authorizationCode,
      idToken: googleAuth.idToken,
    );
  }

  /// Process Google OAuth callback with custom backend API
  Future<bool> processGoogleOAuthCallback({
    required String code,
    String? state,
    String? error,
    String? errorDescription,
  }) async {
    try {
      // If there's an OAuth error, handle it
      if (error != null) {
        String errorMessage = 'Google OAuth failed';
        if (errorDescription != null) {
          errorMessage += ': $errorDescription';
        }
        throw Exception(errorMessage);
      }

      // Call our custom backend callback
      return await _callGoogleOAuthCallback(
        code: code,
        state: state,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Google OAuth Callback Error: $e');
      }
      rethrow;
    }
  }

  /// Call the custom Google OAuth callback API
  Future<bool> _callGoogleOAuthCallback({
    required String code,
    String? state,
    String? idToken,
  }) async {
    try {
      // Get guest session ID for potential migration
      final String? guestSessionId = await _getGuestSessionId();
      
      // Prepare request headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      };
      
      // Add guest session ID if available
      if (guestSessionId != null) {
        headers['X-Anonymous-Session-ID'] = guestSessionId;
      }
      
      // Prepare request body
      final Map<String, dynamic> body = {
        'code': code,
      };
      
      if (state != null) {
        body['state'] = state;
      }
      
      // Call the callback API
      final response = await http.post(
        Uri.parse('${AppConfig.baseApiUrl}/auth-google-callback'),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          // Extract session data
          final sessionData = responseData['session'];
          
          // Set the Supabase session
          await _supabase.auth.recoverSession(
            sessionData['access_token'],
          );
          
          // Create or update user profile
          await upsertUserProfile(
            languagePreference: 'en',
            themePreference: 'light',
          );
          
          return true;
        } else {
          throw Exception(responseData['message'] ?? 'Authentication failed');
        }
      } else {
        // Handle error response
        Map<String, dynamic> errorData = {};
        try {
          errorData = jsonDecode(response.body);
        } catch (e) {
          // If JSON parsing fails, use status code
          throw Exception('HTTP ${response.statusCode}: Authentication failed');
        }
        
        final String errorMessage = errorData['message'] ?? 'Authentication failed';
        final String? errorCode = errorData['error'];
        
        // Handle specific error types
        if (errorCode == 'RATE_LIMITED') {
          throw Exception('Too many login attempts. Please try again later.');
        } else if (errorCode == 'CSRF_VALIDATION_FAILED') {
          throw Exception('Security validation failed. Please try again.');
        } else if (errorCode == 'INVALID_REQUEST') {
          throw Exception('Invalid login request. Please try again.');
        } else {
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google OAuth Callback API Error: $e');
      }
      rethrow;
    }
  }

  /// Get guest session ID for migration
  Future<String?> _getGuestSessionId() async {
    try {
      // Check if current user is anonymous
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        return currentUser.id;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting guest session ID: $e');
      }
      return null;
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