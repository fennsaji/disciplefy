import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/api_auth_helper.dart';

/// Service for submitting user feedback to the backend
/// References: API Reference v1.2 - Feedback endpoint
class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submit feedback for a study guide or general app feedback
  Future<void> submitFeedback({
    String? studyGuideId,
    String? jeffReedSessionId,
    required bool wasHelpful,
    String? message,
    String? category,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final headers = await ApiAuthHelper.getAuthHeaders();

      // Determine if user is authenticated (not anonymous)
      final isAuthenticated = user != null && !user.isAnonymous;

      final body = {
        if (studyGuideId != null) 'study_guide_id': studyGuideId,
        if (jeffReedSessionId != null) 'jeff_reed_session_id': jeffReedSessionId,
        'was_helpful': wasHelpful,
        if (message != null && message.isNotEmpty) 'message': message,
        if (category != null && category.isNotEmpty) 'category': category,
        'user_context': {
          'is_authenticated': isAuthenticated,
          if (isAuthenticated) 'user_id': user.id,
          if (!isAuthenticated) 'session_id': await _getSessionId(),
        }
      };

      final response = await _supabase.functions.invoke(
        'feedback',
        body: body,
        headers: headers,
      );

      if (response.status != 200) {
        throw Exception(response.data['message'] ?? 'Failed to submit feedback');
      }

      // Check if response indicates success
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Feedback submission failed');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to submit feedback: $e');
    }
  }

  /// Get session ID for anonymous users
  Future<String?> _getSessionId() async {
    try {
      final headers = await ApiAuthHelper.getAuthHeaders();
      return headers['x-session-id'];
    } catch (e) {
      return null;
    }
  }

  /// Submit positive feedback (convenience method)
  Future<void> submitPositiveFeedback({
    String? studyGuideId,
    String? message,
  }) async {
    await submitFeedback(
      studyGuideId: studyGuideId,
      wasHelpful: true,
      message: message,
      category: 'general',
    );
  }

  /// Submit negative feedback (convenience method)
  Future<void> submitNegativeFeedback({
    String? studyGuideId,
    required String message,
    String category = 'general',
  }) async {
    await submitFeedback(
      studyGuideId: studyGuideId,
      wasHelpful: false,
      message: message,
      category: category,
    );
  }

  /// Submit general app feedback
  Future<void> submitGeneralFeedback({
    required bool wasHelpful,
    required String message,
    String category = 'general',
  }) async {
    await submitFeedback(
      wasHelpful: wasHelpful,
      message: message,
      category: category,
    );
  }
}
