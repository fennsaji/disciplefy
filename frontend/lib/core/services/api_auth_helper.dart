import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// Unified authentication helper for all API services
/// Ensures consistent authentication across the application
class ApiAuthHelper {
  static const String _anonymousSessionBoxName = 'app_settings';
  static const String _sessionIdKey = 'anonymous_session_id';
  static const Uuid _uuid = Uuid();

  /// Get API headers with proper authentication
  /// Uses live Supabase session for authenticated users
  /// Uses anon key authorization for unauthenticated users (required for Edge Functions)
  static Future<Map<String, String>> getAuthHeaders() async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': AppConfig.supabaseAnonKey,
      };

      // Get live Supabase session (same pattern as working StudyGuidesApiService)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${session.accessToken}';
        print(
            '🔐 [API] Using Supabase session token for user: ${session.user.id}');
      } else {
        // For unauthenticated users, use anon key in Authorization header
        // This is required for Edge Functions to accept the request
        headers['Authorization'] = 'Bearer ${AppConfig.supabaseAnonKey}';

        // Also add x-session-id header for backend session tracking
        final sessionId = await _getOrCreateAnonymousSessionId();
        headers['x-session-id'] = sessionId;
        print(
            '🔐 [API] Using anon key authorization with session ID: $sessionId');
      }

      return headers;
    } catch (e) {
      print('🚨 [API] Error creating auth headers: $e');
      rethrow;
    }
  }

  /// Get or create anonymous session ID for unauthenticated users
  /// Consistent with StudyRepositoryImpl session management
  static Future<String> _getOrCreateAnonymousSessionId() async {
    try {
      if (!Hive.isBoxOpen(_anonymousSessionBoxName)) {
        await Hive.openBox(_anonymousSessionBoxName);
      }

      final box = Hive.box(_anonymousSessionBoxName);
      String? sessionId = box.get(_sessionIdKey);

      if (sessionId == null || sessionId.isEmpty) {
        sessionId = _uuid.v4();
        await box.put(_sessionIdKey, sessionId);
        print('🔐 [API] Created new anonymous session ID: $sessionId');
      } else {
        print('🔐 [API] Using existing anonymous session ID: $sessionId');
      }

      return sessionId;
    } catch (e) {
      // Fallback to generating a new session ID
      final fallbackId = _uuid.v4();
      print('🔐 [API] Fallback to generated session ID: $fallbackId');
      return fallbackId;
    }
  }

  /// Check if user is currently authenticated with live Supabase session
  static bool get isAuthenticated {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null && session.accessToken.isNotEmpty;
  }

  /// Get current authenticated user ID (if available)
  static String? get currentUserId {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.user.id;
  }

  /// Validate if current token is valid and not expired
  /// Returns true if token exists and is valid, false otherwise
  static bool validateCurrentToken() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        print('🔐 [TOKEN_VALIDATION] No session found - token invalid');
        return false;
      }

      if (session.accessToken.isEmpty) {
        print('🔐 [TOKEN_VALIDATION] Empty access token - token invalid');
        return false;
      }

      // Check if token is expired
      if (session.expiresAt != null) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final now = DateTime.now();

        if (now.isAfter(expiryDate)) {
          print(
              '🔐 [TOKEN_VALIDATION] Token expired at: $expiryDate - token invalid');
          return false;
        }
      }

      print(
          '🔐 [TOKEN_VALIDATION] Token is valid for user: ${session.user.id}');
      return true;
    } catch (e) {
      print('🔐 [TOKEN_VALIDATION] Error validating token: $e - token invalid');
      return false;
    }
  }

  /// Check if user requires authentication for API calls
  /// Anonymous users don't need token validation
  static bool requiresTokenValidation() {
    final session = Supabase.instance.client.auth.currentSession;
    // If there's any session data, we should validate the token
    return session != null;
  }

  /// Validate token before making authenticated API requests
  /// Throws TokenValidationException if token is invalid
  /// Automatically refreshes session if token is expired or close to expiry
  static Future<void> validateTokenForRequest() async {
    // Anonymous users don't need token validation
    if (!requiresTokenValidation()) {
      print('🔐 [TOKEN_VALIDATION] Anonymous user - skipping token validation');
      return;
    }

    print(
        '🔐 [TOKEN_VALIDATION] Starting token validation for authenticated user');

    // Proactively refresh session if expired or close to expiry
    // This prevents initial API failures after long inactivity
    final refreshed = await _refreshSessionIfNeeded();
    if (!refreshed) {
      print(
          '🔐 [TOKEN_VALIDATION] ❌ Session refresh failed - both access and refresh tokens may be expired');
      print('🔐 [TOKEN_VALIDATION] User will need to re-authenticate');
      throw const TokenValidationException(
        message: 'Authentication session expired and could not be refreshed',
        code: 'SESSION_EXPIRED',
      );
    }

    print(
        '🔐 [TOKEN_VALIDATION] Session refresh check complete - validating token');

    // Validate the (now refreshed) token
    if (!validateCurrentToken()) {
      print(
          '🔐 [TOKEN_VALIDATION] ❌ Token validation failed after refresh - unexpected error');
      throw const TokenValidationException(
        message: 'Authentication token is invalid or expired',
        code: 'TOKEN_INVALID',
      );
    }

    print(
        '🔐 [TOKEN_VALIDATION] ✅ Token validation passed - proceeding with request');
  }

  /// Refresh session if token is expired or expires within 5 minutes
  /// Returns true if session is valid (either already valid or successfully refreshed)
  /// Returns false if refresh failed
  static Future<bool> _refreshSessionIfNeeded() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        print('🔐 [SESSION_REFRESH] No session to refresh');
        return false;
      }

      // Check if token is expired or expires soon (within 5 minutes)
      if (session.expiresAt != null) {
        final expiryTime =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final now = DateTime.now();
        final expiresWithin5Min = now.add(const Duration(minutes: 5));

        if (expiryTime.isAfter(expiresWithin5Min)) {
          print(
              '🔐 [SESSION_REFRESH] Token is still valid (expires: $expiryTime) - no refresh needed');
          return true;
        }

        print(
            '🔐 [SESSION_REFRESH] Token expired or expires soon (expires: $expiryTime) - refreshing...');
      }

      // Attempt to refresh the session
      final response = await Supabase.instance.client.auth.refreshSession();

      if (response.session != null) {
        // Verify the refreshed token is actually valid and not expired
        final newExpiry = DateTime.fromMillisecondsSinceEpoch(
            response.session!.expiresAt! * 1000);
        final now = DateTime.now();

        if (now.isAfter(newExpiry)) {
          print(
              '🔐 [SESSION_REFRESH] ❌ Refreshed token is still expired (expires: $newExpiry)');
          print(
              '🔐 [SESSION_REFRESH] This indicates the refresh token itself is expired');
          return false;
        }

        print('🔐 [SESSION_REFRESH] ✅ Session refresh successful');
        print('🔐 [SESSION_REFRESH] New token expires: $newExpiry');
        return true;
      } else {
        print('🔐 [SESSION_REFRESH] ❌ Session refresh returned null');
        return false;
      }
    } catch (e) {
      print('🔐 [SESSION_REFRESH] ❌ Session refresh error: $e');
      return false;
    }
  }

  /// Debug helper to log current authentication state
  static void logAuthState() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      print('🔐 [DEBUG] Authenticated user: ${session.user.id}');
      print(
          '🔐 [DEBUG] Token expires: ${DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)}');
    } else {
      print('🔐 [DEBUG] Anonymous user - no active session');
    }
  }
}
