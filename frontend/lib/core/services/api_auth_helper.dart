import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

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
        print('🔐 [API] Using Supabase session token for user: ${session.user.id}');
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

  /// Debug helper to log current authentication state
  static void logAuthState() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      print('🔐 [DEBUG] Authenticated user: ${session.user.id}');
      print('🔐 [DEBUG] Token expires: ${DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)}');
    } else {
      print('🔐 [DEBUG] Anonymous user - no active session');
    }
  }
}