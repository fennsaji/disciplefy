import '../../domain/entities/feedback_entity.dart';

/// Remote data source abstraction for feedback operations
abstract class FeedbackRemoteDataSource {
  /// Submit feedback to the remote server
  Future<void> submitFeedback(FeedbackEntity feedback);
}
