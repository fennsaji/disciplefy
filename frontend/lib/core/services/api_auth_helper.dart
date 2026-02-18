import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../utils/logger.dart';

/// Unified authentication helper for all API services
/// Ensures consistent authentication across the application
class ApiAuthHelper {
  static const String _anonymousSessionBoxName = 'app_settings';
  static const String _sessionIdKey = 'anonymous_session_id';
  static const Uuid _uuid = Uuid();

  /// Completer to synchronize concurrent token refresh attempts
  /// Prevents race condition where multiple API calls trigger simultaneous refreshes
  static Completer<bool>? _refreshCompleter;

  /// Get API headers with proper authentication
  /// Uses live Supabase session for authenticated users
  /// Uses anon key authorization for unauthenticated users (required for Edge Functions)
  ///
  /// OAUTH FIX: After Google/Apple OAuth login, there's a brief delay before the session
  /// is persisted to currentSession. We retry a few times to handle this timing issue.
  static Future<Map<String, String>> getAuthHeaders({
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': AppConfig.supabaseAnonKey,
      };

      // Try to get session with retry logic for OAuth flow
      Session? session;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        session = Supabase.instance.client.auth.currentSession;

        if (session != null && session.accessToken.isNotEmpty) {
          // Session found
          break;
        }

        if (attempt < maxRetries) {
          // Wait before retrying (only if we have more attempts)
          Logger.debug(
              '🔐 [API] Session not ready (attempt $attempt/$maxRetries), retrying in ${retryDelay.inMilliseconds}ms...');
          await Future.delayed(retryDelay);
        }
      }

      if (session != null && session.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${session.accessToken}';

        // Warn if session token is unexpectedly the anon key
        final isAnonKey = session.accessToken == AppConfig.supabaseAnonKey;
        if (isAnonKey) {
          Logger.warning(
              '🚨 [API] CRITICAL: Session token is the anon key! Should not happen after OAuth login.');
        }
      } else {
        // For unauthenticated users, use anon key in Authorization header
        // This is required for Edge Functions to accept the request
        headers['Authorization'] = 'Bearer ${AppConfig.supabaseAnonKey}';

        // Also add x-session-id header for backend session tracking
        final sessionId = await _getOrCreateAnonymousSessionId();
        headers['x-session-id'] = sessionId;
        Logger.debug(
            '🔐 [API] Using anon key authorization with session ID: $sessionId');
      }

      return headers;
    } catch (e) {
      Logger.error('🚨 [API] Error creating auth headers: $e');
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
        Logger.debug('🔐 [API] Created new anonymous session ID: $sessionId');
      } else {
        Logger.debug(
            '🔐 [API] Using existing anonymous session ID: $sessionId');
      }

      return sessionId;
    } catch (e) {
      // Fallback to generating a new session ID
      final fallbackId = _uuid.v4();
      Logger.debug('🔐 [API] Fallback to generated session ID: $fallbackId');
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
        Logger.debug('🔐 [TOKEN_VALIDATION] No session found - token invalid');
        return false;
      }

      if (session.accessToken.isEmpty) {
        Logger.debug(
            '🔐 [TOKEN_VALIDATION] Empty access token - token invalid');
        return false;
      }

      // Check if token is expired
      if (session.expiresAt != null) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final now = DateTime.now();

        if (now.isAfter(expiryDate)) {
          Logger.debug(
              '🔐 [TOKEN_VALIDATION] Token expired at: $expiryDate - token invalid');
          return false;
        }

        Logger.debug(
            '🔐 [TOKEN_VALIDATION] Token is valid for user: ${session.user.id} (expires: $expiryDate)');
      } else {
        Logger.debug(
            '🔐 [TOKEN_VALIDATION] ℹ️  No expiry timestamp - token assumed valid for user: ${session.user.id}');
      }

      return true;
    } catch (e) {
      Logger.error(
          '🔐 [TOKEN_VALIDATION] Error validating token: $e - token invalid');
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
  ///
  /// OAUTH FIX: After Google/Apple OAuth login, we retry validation a few times
  /// to handle the timing delay while session is being persisted.
  static Future<void> validateTokenForRequest({
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    // Try validation with retries to handle OAuth timing
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Check if we need to validate at all
        if (!requiresTokenValidation()) {
          if (attempt > 1) {
            Logger.debug(
                '🔐 [TOKEN_VALIDATION] Session became anonymous during retry (attempt $attempt/$maxRetries)');
          } else {
            Logger.debug(
                '🔐 [TOKEN_VALIDATION] Anonymous user - skipping token validation');
          }
          return;
        }

        if (attempt > 1) {
          Logger.debug(
              '🔐 [TOKEN_VALIDATION] Retry attempt $attempt/$maxRetries after ${retryDelay.inMilliseconds}ms delay');
        } else {
          Logger.debug(
              '🔐 [TOKEN_VALIDATION] Starting token validation for authenticated user');
        }

        // Proactively refresh session if expired or close to expiry
        final refreshed = await _refreshSessionIfNeeded();
        if (!refreshed) {
          throw const TokenValidationException(
            message:
                'Authentication session expired and could not be refreshed',
            code: 'SESSION_EXPIRED',
          );
        }

        // Validate the (now refreshed) token
        if (!validateCurrentToken()) {
          throw const TokenValidationException(
            message: 'Authentication token is invalid or expired',
            code: 'TOKEN_INVALID',
          );
        }

        Logger.debug(
            '🔐 [TOKEN_VALIDATION] ✅ Token validation passed - proceeding with request');
        return;
      } on TokenValidationException catch (e) {
        lastError = e;

        // If this is not the last attempt and the error is about session expiry,
        // it might be an OAuth timing issue - retry
        if (attempt < maxRetries && e.code == 'SESSION_EXPIRED') {
          Logger.error(
              '🔐 [TOKEN_VALIDATION] Session validation failed (attempt $attempt/$maxRetries), retrying...');
          await Future.delayed(retryDelay);
        } else {
          // Last attempt or non-retryable error
          rethrow;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          Logger.error(
              '🔐 [TOKEN_VALIDATION] Unexpected error (attempt $attempt/$maxRetries): $e');
          await Future.delayed(retryDelay);
        } else {
          rethrow;
        }
      }
    }

    // If we exhausted all retries, throw the last error
    if (lastError != null) {
      if (lastError is TokenValidationException) {
        throw lastError;
      } else {
        throw TokenValidationException(
          message: 'Token validation failed: ${lastError.toString()}',
          code: 'VALIDATION_ERROR',
        );
      }
    }
  }

  /// Refresh session if token is expired or expires within 5 minutes
  /// Returns true if session is valid (either already valid or successfully refreshed)
  /// Returns false if refresh failed
  ///
  /// RACE CONDITION FIX: Uses Completer to ensure only one refresh happens at a time
  /// If multiple API calls trigger refresh simultaneously, they all wait for the same refresh
  static Future<bool> _refreshSessionIfNeeded() async {
    // If refresh already in progress, wait for it to complete
    if (_refreshCompleter != null) {
      Logger.debug(
          '🔐 [SESSION_REFRESH] ⏳ Refresh already in progress, waiting for completion...');
      return await _refreshCompleter!.future;
    }

    // Start new refresh operation
    _refreshCompleter = Completer<bool>();

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        Logger.debug('🔐 [SESSION_REFRESH] No session to refresh');
        _refreshCompleter!.complete(false);
        return false;
      }

      // Check if token has expiry information
      if (session.expiresAt == null) {
        // No expiry timestamp - assume session is valid (persistent/long-lived session)
        Logger.debug(
            '🔐 [SESSION_REFRESH] ℹ️  No expiry timestamp found - assuming session is valid');
        Logger.debug(
            '🔐 [SESSION_REFRESH] ℹ️  Session may be persistent or long-lived');
        _refreshCompleter!.complete(true);
        return true;
      }

      // Check if token is expired or expires soon (within 5 minutes)
      final expiryTime =
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      final now = DateTime.now();
      final expiresWithin5Min = now.add(const Duration(minutes: 5));

      if (expiryTime.isAfter(expiresWithin5Min)) {
        Logger.debug(
            '🔐 [SESSION_REFRESH] Token is still valid (expires: $expiryTime) - no refresh needed');
        _refreshCompleter!.complete(true);
        return true;
      }

      Logger.debug(
          '🔐 [SESSION_REFRESH] Token expired or expires soon (expires: $expiryTime) - refreshing...');

      // Attempt to refresh the session
      final response = await Supabase.instance.client.auth.refreshSession();

      if (response.session != null) {
        // Verify the refreshed token is actually valid and not expired
        if (response.session!.expiresAt != null) {
          final newExpiry = DateTime.fromMillisecondsSinceEpoch(
              response.session!.expiresAt! * 1000);
          final now = DateTime.now();

          if (now.isAfter(newExpiry)) {
            Logger.error(
                '🔐 [SESSION_REFRESH] ❌ Refreshed token is still expired (expires: $newExpiry)');
            Logger.debug(
                '🔐 [SESSION_REFRESH] This indicates the refresh token itself is expired');
            _refreshCompleter!.complete(false);
            return false;
          }

          Logger.debug('🔐 [SESSION_REFRESH] ✅ Session refresh successful');
          Logger.debug('🔐 [SESSION_REFRESH] New token expires: $newExpiry');
        } else {
          Logger.debug('🔐 [SESSION_REFRESH] ✅ Session refresh successful');
          Logger.debug(
              '🔐 [SESSION_REFRESH] ℹ️  No expiry timestamp on refreshed session - assumed valid');
        }

        _refreshCompleter!.complete(true);
        return true;
      } else {
        Logger.error('🔐 [SESSION_REFRESH] ❌ Session refresh returned null');
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      Logger.error('🔐 [SESSION_REFRESH] ❌ Session refresh error: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      // Reset completer for next refresh cycle
      _refreshCompleter = null;
    }
  }

  /// Debug helper to log current authentication state
  static void logAuthState() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Logger.debug('🔐 [DEBUG] Authenticated user: ${session.user.id}');
      Logger.debug(
          '🔐 [DEBUG] Token expires: ${DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)}');
    } else {
      Logger.debug('🔐 [DEBUG] Anonymous user - no active session');
    }
  }
}
