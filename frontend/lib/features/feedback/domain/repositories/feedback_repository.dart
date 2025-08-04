import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feedback_entity.dart';

/// Repository abstraction for feedback operations
abstract class FeedbackRepository {
  /// Submit user feedback
  Future<Either<Failure, void>> submitFeedback(FeedbackEntity feedback);

  /// Submit positive feedback (convenience method)
  Future<Either<Failure, void>> submitPositiveFeedback({
    String? studyGuideId,
    String? message,
    required UserContextEntity userContext,
  });

  /// Submit negative feedback (convenience method)
  Future<Either<Failure, void>> submitNegativeFeedback({
    String? studyGuideId,
    required String message,
    String category = 'general',
    required UserContextEntity userContext,
  });

  /// Submit general app feedback
  Future<Either<Failure, void>> submitGeneralFeedback({
    required bool wasHelpful,
    required String message,
    String category = 'general',
    required UserContextEntity userContext,
  });
}
