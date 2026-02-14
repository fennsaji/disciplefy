import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../constants/feedback_constants.dart';
import '../entities/feedback_entity.dart';
import '../repositories/feedback_repository.dart';

/// Use case for submitting user feedback
class SubmitFeedbackUseCase implements UseCase<void, SubmitFeedbackParams> {
  final FeedbackRepository repository;

  SubmitFeedbackUseCase({required this.repository});

  @override
  Future<Either<Failure, void>> call(SubmitFeedbackParams params) async =>
      await repository.submitFeedback(params.feedback);
}

/// Parameters for submit feedback use case
class SubmitFeedbackParams {
  final FeedbackEntity feedback;

  const SubmitFeedbackParams({required this.feedback});

  /// Create params for general feedback
  factory SubmitFeedbackParams.general({
    required bool wasHelpful,
    required String message,
    String category = FeedbackCategories.general,
    required UserContextEntity userContext,
  }) =>
      SubmitFeedbackParams(
        feedback: FeedbackEntity(
          wasHelpful: wasHelpful,
          message: message,
          category: category,
          userContext: userContext,
        ),
      );

  /// Create params for study guide feedback
  factory SubmitFeedbackParams.studyGuide({
    required String studyGuideId,
    required bool wasHelpful,
    String? message,
    String category = FeedbackCategories.contentFeedback,
    required UserContextEntity userContext,
  }) =>
      SubmitFeedbackParams(
        feedback: FeedbackEntity(
          studyGuideId: studyGuideId,
          wasHelpful: wasHelpful,
          message: message,
          category: category,
          userContext: userContext,
        ),
      );

  /// Create params for bug report
  factory SubmitFeedbackParams.bugReport({
    required String message,
    required UserContextEntity userContext,
  }) =>
      SubmitFeedbackParams(
        feedback: FeedbackEntity(
          wasHelpful: false,
          message: message,
          category: FeedbackCategories.bugReport,
          userContext: userContext,
        ),
      );
}
