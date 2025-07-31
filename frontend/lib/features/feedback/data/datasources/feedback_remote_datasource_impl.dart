import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/feedback_entity.dart';
import 'feedback_remote_datasource.dart';

/// Implementation of FeedbackRemoteDataSource using Supabase
class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final SupabaseClient supabaseClient;

  FeedbackRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<void> submitFeedback(FeedbackEntity feedback) async {
    try {
      final body = _buildRequestBody(feedback);

      final response = await supabaseClient.functions.invoke(
        'feedback',
        body: body,
      );

      if (response.status != 200) {
        throw ServerException(
          message: response.data['message'] ?? 'Failed to submit feedback',
          code: 'FEEDBACK_SUBMIT_ERROR',
        );
      }

      // Check if response indicates success
      if (response.data['success'] != true) {
        throw ServerException(
          message: response.data['message'] ?? 'Feedback submission failed',
          code: 'FEEDBACK_SUBMIT_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to submit feedback: $e',
        code: 'FEEDBACK_SUBMIT_ERROR',
      );
    }
  }

  /// Build request body from feedback entity
  Map<String, dynamic> _buildRequestBody(FeedbackEntity feedback) => {
      if (feedback.studyGuideId != null) 'study_guide_id': feedback.studyGuideId,
      if (feedback.jeffReedSessionId != null) 'jeff_reed_session_id': feedback.jeffReedSessionId,
      'was_helpful': feedback.wasHelpful,
      if (feedback.message != null && feedback.message!.isNotEmpty) 'message': feedback.message,
      if (feedback.category != null && feedback.category!.isNotEmpty) 'category': feedback.category,
      'user_context': _buildUserContextMap(feedback.userContext),
    };

  /// Build user context map from entity
  Map<String, dynamic> _buildUserContextMap(UserContextEntity userContext) => {
      'is_authenticated': userContext.isAuthenticated,
      if (userContext.isAuthenticated && userContext.userId != null) 
        'user_id': userContext.userId,
      if (!userContext.isAuthenticated && userContext.sessionId != null) 
        'session_id': userContext.sessionId,
    };
}