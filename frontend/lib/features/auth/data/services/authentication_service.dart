import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;
import '../../domain/utils/auth_validator.dart';
import '../../../user_profile/data/services/user_profile_api_service.dart';
import 'auth_storage_service.dart';
import 'oauth_service.dart';

/// Core authentication service that orchestrates auth operations
/// Handles Supabase integration, anonymous sessions, and user state management
class AuthenticationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthStorageService _storageService;
  final OAuthService _oauthService;
  final UserProfileApiService _profileApiService;

  AuthenticationService({
    AuthStorageService? storageService,
    OAuthService? oauthService,
    UserProfileApiService? profileApiService,
  })  : _storageService = storageService ?? AuthStorageService(),
        _oauthService = oauthService ?? OAuthService(),
        _profileApiService = profileApiService ?? UserProfileApiService();

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

    // Guard against null expiresAt
    if (session.expiresAt == null) {
      if (kDebugMode) {
        print(
            '🔐 [TOKEN VALIDATION] ⚠️ Session expiresAt is null, treating as invalid');
      }
      return false;
    }

    // Check if token expires within 5 minutes - using consistent UTC timezone
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
      isUtc: true,
    );
    final currentTimeUtc = DateTime.now().toUtc();
    final fiveMinutesFromNowUtc =
        currentTimeUtc.add(const Duration(minutes: 5));

    final isValid = expiresAt.isAfter(fiveMinutesFromNowUtc);

    if (kDebugMode) {
      print('🔐 [TOKEN VALIDATION] Current time (UTC): $currentTimeUtc');
      print('🔐 [TOKEN VALIDATION] Token expires at (UTC): $expiresAt');
      print('🔐 [TOKEN VALIDATION] Token valid: $isValid');
      if (!isValid) {
        final timeUntilExpiry = expiresAt.difference(currentTimeUtc);
        print(
            '🔐 [TOKEN VALIDATION] ⚠️ Token expires in: ${timeUntilExpiry.inMinutes} minutes');
      }
    }

    return isValid;
  }

  /// SECURITY FIX: Refresh the current authentication token
  /// Returns true if refresh succeeded, false otherwise
  /// Automatically updates stored session data with new expiration
  Future<bool> refreshToken() async {
    try {
      if (kDebugMode) {
        print('🔐 [TOKEN REFRESH] 🔄 Starting token refresh...');
      }

      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (kDebugMode) {
          print('🔐 [TOKEN REFRESH] ❌ No active session to refresh');
        }
        return false;
      }

      // Refresh the session using Supabase
      final response = await _supabase.auth.refreshSession();
      final newSession = response.session;

      if (newSession == null) {
        if (kDebugMode) {
          print('🔐 [TOKEN REFRESH] ❌ Token refresh failed - no new session');
        }
        return false;
      }

      if (kDebugMode) {
        final newExpiresAt = DateTime.fromMillisecondsSinceEpoch(
          newSession.expiresAt! * 1000,
          isUtc: true,
        );
        print('🔐 [TOKEN REFRESH] ✅ Token refreshed successfully');
        print('🔐 [TOKEN REFRESH] New expiration: $newExpiresAt');
      }

      // Update stored session data with new expiration
      final user = response.user;
      if (user != null) {
        final expiresAt = _extractSessionExpiration(newSession);
        final deviceId = await _generateDeviceFingerprint();

        // Determine user type and update storage accordingly
        final userType = await _storageService.getUserType();
        if (userType == 'google') {
          await _storageService.storeAuthData(
            AuthDataStorageParams.google(
              accessToken: newSession.accessToken,
              userId: user.id,
              expiresAt: expiresAt,
              deviceId: deviceId,
            ),
          );
        } else if (userType == 'guest' || user.isAnonymous) {
          await _storageService.storeAuthData(
            AuthDataStorageParams.guest(
              accessToken: newSession.accessToken,
              userId: user.id,
              expiresAt: expiresAt,
              deviceId: deviceId,
            ),
          );
        } else if (userType == 'apple') {
          await _storageService.storeAuthData(
            AuthDataStorageParams.apple(
              accessToken: newSession.accessToken,
              userId: user.id,
              expiresAt: expiresAt,
              deviceId: deviceId,
            ),
          );
        }

        if (kDebugMode) {
          print('🔐 [TOKEN REFRESH] ✅ Stored updated session data');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [TOKEN REFRESH] ❌ Error during token refresh: $e');
      }
      return false;
    }
  }

  /// SECURITY FIX: Ensure token is valid, refreshing if necessary
  /// Returns true if token is valid or was successfully refreshed
  /// This is the recommended method for checking auth before API calls
  Future<bool> ensureTokenValid() async {
    // Check if token is currently valid
    final isValid = await isTokenValid();
    if (isValid) {
      if (kDebugMode) {
        print('🔐 [TOKEN VALIDATION] ✅ Token is valid, no refresh needed');
      }
      return true;
    }

    // Token is expiring soon or expired - attempt refresh
    if (kDebugMode) {
      print(
          '🔐 [TOKEN VALIDATION] ⚠️ Token expiring soon, attempting refresh...');
    }

    final refreshed = await refreshToken();
    if (refreshed) {
      if (kDebugMode) {
        print('🔐 [TOKEN VALIDATION] ✅ Token successfully refreshed');
      }
      return true;
    }

    // Refresh failed - user needs to re-authenticate
    if (kDebugMode) {
      print(
          '🔐 [TOKEN VALIDATION] ❌ Token refresh failed - re-authentication required');
    }
    return false;
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

          // SECURITY FIX: Extract session expiration and generate device fingerprint
          final session = _supabase.auth.currentSession!;
          final expiresAt = _extractSessionExpiration(session);
          final deviceId = await _generateDeviceFingerprint();

          // Store authentication state after successful OAuth
          await _storageService.storeAuthData(
            AuthDataStorageParams.google(
              accessToken: session.accessToken,
              userId: currentUser?.id,
              expiresAt: expiresAt,
              deviceId: deviceId,
            ),
          );

          // Extract and sync OAuth profile data
          await _syncOAuthProfileData();

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

        // SECURITY FIX: Extract session expiration and generate device fingerprint
        final session = _supabase.auth.currentSession!;
        final expiresAt = _extractSessionExpiration(session);
        final deviceId = await _generateDeviceFingerprint();

        // Store authentication state
        print('🔍 [DEBUG] About to store auth data...');
        await _storageService.storeAuthData(
          AuthDataStorageParams.google(
            accessToken: session.accessToken,
            userId: currentUser?.id,
            expiresAt: expiresAt,
            deviceId: deviceId,
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

        // Extract and sync OAuth profile data
        await _syncOAuthProfileData();

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
      // SECURITY FIX: Extract session expiration and generate device fingerprint
      final session = _supabase.auth.currentSession!;
      final expiresAt = _extractSessionExpiration(session);
      final deviceId = await _generateDeviceFingerprint();

      // Store authentication state after successful OAuth
      await _storageService.storeAuthData(
        AuthDataStorageParams.apple(
          accessToken: session.accessToken,
          userId: currentUser?.id,
          expiresAt: expiresAt,
          deviceId: deviceId,
        ),
      );

      // Extract and sync OAuth profile data
      await _syncOAuthProfileData();
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

      // SECURITY FIX: Extract session expiration and generate device fingerprint
      final session = response.session!;
      final expiresAt = _extractSessionExpiration(session);
      final deviceId = await _generateDeviceFingerprint();

      // Step 2: Store auth state properly - using JWT token, not session_id
      await _storageService.storeAuthData(
        AuthDataStorageParams.guest(
          accessToken: session.accessToken, // ✅ Using actual JWT token
          userId: user.id, // ✅ Using Supabase user ID
          expiresAt: expiresAt, // ✅ SECURITY FIX: Track expiration
          deviceId: deviceId, // ✅ SECURITY FIX: Bind to device
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

      // Clear stored auth data - only secure storage (use ClearUserDataUseCase for comprehensive cleanup)
      await _storageService.clearSecureStorage();
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

  /// Extract OAuth profile data from current user and sync to backend
  Future<void> _syncOAuthProfileData() async {
    if (kDebugMode) {
      print('🔐 [PROFILE SYNC] 🚀 _syncOAuthProfileData() called');
      print('🔐 [PROFILE SYNC] Current user: ${currentUser?.id}');
      print('🔐 [PROFILE SYNC] User email: ${currentUser?.email}');
      print('🔐 [PROFILE SYNC] Is anonymous: ${currentUser?.isAnonymous}');
      print('🔐 [PROFILE SYNC] App metadata: ${currentUser?.appMetadata}');
      print('🔐 [PROFILE SYNC] User metadata: ${currentUser?.userMetadata}');
    }

    if (currentUser == null) {
      if (kDebugMode) {
        print('🔐 [PROFILE SYNC] ⚠️ No current user, skipping profile sync');
      }
      return;
    }

    if (currentUser!.isAnonymous) {
      if (kDebugMode) {
        print(
            '🔐 [PROFILE SYNC] ℹ️ User is anonymous, skipping OAuth profile sync');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔐 [PROFILE SYNC] ✅ Starting OAuth profile data extraction...');
        print('🔐 [PROFILE SYNC] User ID: ${currentUser!.id}');
        print(
            '🔐 [PROFILE SYNC] User metadata raw: ${currentUser!.userMetadata}');
      }

      final userMetadata = currentUser!.userMetadata ?? {};
      if (userMetadata.isEmpty) {
        if (kDebugMode) {
          print(
              '🔐 [PROFILE SYNC] ℹ️ No user metadata available, skipping sync');
        }
        return;
      }

      // Extract profile data from OAuth metadata
      final profileData = <String, dynamic>{};

      // Extract name fields
      if (userMetadata['full_name'] != null) {
        final fullName = userMetadata['full_name'] as String;
        final nameParts = fullName.trim().split(' ');
        if (nameParts.isNotEmpty) {
          profileData['firstName'] = nameParts.first;
          if (nameParts.length > 1) {
            profileData['lastName'] = nameParts.skip(1).join(' ');
          }
        }
      }

      // Extract individual name fields if available
      if (userMetadata['name'] != null && profileData['firstName'] == null) {
        final name = userMetadata['name'] as String;
        final nameParts = name.trim().split(' ');
        if (nameParts.isNotEmpty) {
          profileData['firstName'] = nameParts.first;
          if (nameParts.length > 1) {
            profileData['lastName'] = nameParts.skip(1).join(' ');
          }
        }
      }

      // Try to get first_name and last_name directly
      if (userMetadata['first_name'] != null) {
        profileData['firstName'] = userMetadata['first_name'];
      }
      if (userMetadata['last_name'] != null) {
        profileData['lastName'] = userMetadata['last_name'];
      }

      // Extract profile picture
      if (userMetadata['avatar_url'] != null) {
        profileData['profilePicture'] = userMetadata['avatar_url'];
      } else if (userMetadata['picture'] != null) {
        profileData['profilePicture'] = userMetadata['picture'];
      }

      // Extract email and phone
      if (currentUser!.email != null) {
        profileData['email'] = currentUser!.email;
      }
      if (currentUser!.phone != null) {
        profileData['phone'] = currentUser!.phone;
      }

      if (profileData.isNotEmpty) {
        if (kDebugMode) {
          print('🔐 [PROFILE SYNC] 📤 Syncing profile data: $profileData');
        }

        // Sync profile data to backend
        if (kDebugMode) {
          print('🔐 [PROFILE SYNC] 📤 Making API call to sync profile data...');
        }

        final result = await _profileApiService.syncOAuthProfile(profileData);

        if (kDebugMode) {
          print('🔐 [PROFILE SYNC] 📊 API response: $result');
        }

        result.fold(
          (failure) {
            if (kDebugMode) {
              print('🔐 [PROFILE SYNC] ❌ API call failed: ${failure.message}');
            }
          },
          (profile) {
            if (kDebugMode) {
              print(
                  '🔐 [PROFILE SYNC] ✅ Profile data sync completed successfully');
              print(
                  '🔐 [PROFILE SYNC] Updated profile: firstName=${profile.firstName}, lastName=${profile.lastName}');
            }
          },
        );
      } else {
        if (kDebugMode) {
          print('🔐 [PROFILE SYNC] ℹ️ No profile data to sync');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [PROFILE SYNC] ❌ Error syncing profile data: $e');
      }
      // Don't throw the error to avoid breaking the auth flow
      // Profile sync is a best-effort operation
    }
  }

  /// Manual test method for OAuth profile sync (DEBUG ONLY)
  Future<void> testOAuthProfileSync() async {
    if (kDebugMode) {
      print('🔐 [PROFILE SYNC TEST] 🧪 Manual test triggered');
      await _syncOAuthProfileData();
    }
  }

  /// Generate a device fingerprint for session binding
  /// SECURITY FIX: Creates a unique identifier based on device characteristics
  Future<String> _generateDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String fingerprint;

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // Combine browser characteristics for web fingerprint
        final components = [
          webInfo.userAgent ?? '',
          webInfo.vendor ?? '',
          webInfo.platform ?? '',
          webInfo.language ?? '',
        ];
        fingerprint = components.join('|');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        // Combine device characteristics for Android
        final components = [
          androidInfo.id, // Android ID
          androidInfo.device,
          androidInfo.model,
          androidInfo.product,
        ];
        fingerprint = components.join('|');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Combine device characteristics for iOS
        final components = [
          iosInfo.identifierForVendor ?? '', // iOS vendor ID
          iosInfo.model,
          iosInfo.systemName,
          iosInfo.systemVersion,
        ];
        fingerprint = components.join('|');
      } else {
        // Fallback for other platforms
        fingerprint =
            'unknown_platform_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Hash the fingerprint for privacy
      final bytes = utf8.encode(fingerprint);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [DEVICE FINGERPRINT] ⚠️ Error generating fingerprint: $e');
      }
      // Return a fallback identifier
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Extract session expiration from Supabase session
  /// SECURITY FIX: Converts Unix timestamp to DateTime for storage
  DateTime _extractSessionExpiration(Session session) {
    if (session.expiresAt != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
        isUtc: true,
      );
    }
    // Default to 24 hours from now if no expiration
    return DateTime.now().toUtc().add(const Duration(hours: 24));
  }

  /// Dispose resources
  void dispose() {
    _oauthService.dispose();
  }
}
