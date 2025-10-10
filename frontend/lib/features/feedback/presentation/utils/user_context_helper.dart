import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/feedback_entity.dart';

/// Helper class to create user context for feedback submissions
class UserContextHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Create user context from current auth state
  static Future<UserContextEntity> getCurrentUserContext() async {
    final user = _supabase.auth.currentUser;

    if (user != null && !user.isAnonymous) {
      // Authenticated user
      return UserContextEntity.authenticated(userId: user.id);
    } else {
      // Anonymous user - get session ID
      final sessionId = await _getSessionId();
      return UserContextEntity.anonymous(sessionId: sessionId);
    }
  }

  /// Get session ID for anonymous users
  static Future<String> _getSessionId() async {
    try {
      // Validate token before getting auth headers
      await ApiAuthHelper.validateTokenForRequest();

      final headers = await ApiAuthHelper.getAuthHeaders();
      return headers['x-session-id'] ?? 'unknown-session';
    } on TokenValidationException {
      // Return unknown session if token validation fails
      return 'unknown-session';
    } catch (e) {
      return 'unknown-session';
    }
  }
}
