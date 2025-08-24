import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

/// Exception thrown when token validation fails
class TokenValidationException implements Exception {
  final String message;
  const TokenValidationException(this.message);

  @override
  String toString() => 'TokenValidationException: $message';
}

/// Unified authentication helper for all API services
/// Ensures consistent authentication across the application
class ApiAuthHelper {
  static const String _anonymousSessionBoxName = 'app_settings';
  static const String _sessionIdKey = 'anonymous_session_id';
  static const Uuid _uuid = Uuid();

  /// Get API headers with proper authentication
  /// Uses live Supabase session for authenticated users
  /// Uses x-session-id header for anonymous users
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
        // For anonymous users, add x-session-id header (as expected by backend)
        final sessionId = await _getOrCreateAnonymousSessionId();
        headers['x-session-id'] = sessionId;
        print('🔐 [API] Using anonymous session ID: $sessionId');
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
  static Future<void> validateTokenForRequest() async {
    // Anonymous users don't need token validation
    if (!requiresTokenValidation()) {
      print('🔐 [TOKEN_VALIDATION] Anonymous user - skipping token validation');
      return;
    }

    if (!validateCurrentToken()) {
      print(
          '🔐 [TOKEN_VALIDATION] Token validation failed - throwing exception');
      throw TokenValidationException(
          'Authentication token is invalid or expired');
    }

    print(
        '🔐 [TOKEN_VALIDATION] Token validation passed - proceeding with request');
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
