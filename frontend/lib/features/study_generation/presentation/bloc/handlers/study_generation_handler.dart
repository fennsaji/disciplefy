import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/token_failures.dart';
import '../../../../../core/utils/error_message_sanitizer.dart';
import '../../../domain/usecases/generate_study_guide.dart';
import '../study_event.dart';
import '../study_state.dart';
import '../../../../../core/utils/logger.dart';

/// Handler for study guide generation logic.
///
/// This class encapsulates all the business logic related to generating
/// study guides, following the Single Responsibility Principle.
class StudyGenerationHandler {
  final GenerateStudyGuide _generateStudyGuide;

  const StudyGenerationHandler({
    required GenerateStudyGuide generateStudyGuide,
  }) : _generateStudyGuide = generateStudyGuide;

  /// Handles the study guide generation request.
  ///
  /// This method validates the input, calls the use case, and emits
  /// appropriate states based on the result.
  Future<void> handleGenerateStudyGuide(
    GenerateStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) async {
    Logger.debug('🚨 [STUDY_BLOC] Starting study generation handling');
    emit(const StudyGenerationInProgress());

    try {
      final result = await _generateStudyGuide(
        StudyGenerationParams(
          input: event.input,
          inputType: event.inputType,
          topicDescription: event.topicDescription,
          language: event.language,
        ),
      );

      result.fold(
        (failure) {
          Logger.error(
              '🚨 [STUDY_BLOC] Emitting StudyGenerationFailure: ${failure.runtimeType} - ${failure.message}');

          // SECURITY FIX: Sanitize error message before exposing to user
          final sanitizedMessage = ErrorMessageSanitizer.sanitize(failure);

          // Create a new failure with sanitized message
          final sanitizedFailure =
              _createSanitizedFailure(failure, sanitizedMessage);

          emit(StudyGenerationFailure(
            failure: sanitizedFailure,
            isRetryable: _isRetryableFailure(failure),
          ));
        },
        (studyGuide) {
          Logger.debug('🚨 [STUDY_BLOC] Emitting StudyGenerationSuccess');
          emit(StudyGenerationSuccess(
            studyGuide: studyGuide,
            generatedAt: DateTime.now(),
          ));
        },
      );
    } catch (e) {
      emit(StudyGenerationFailure(
        failure: ClientFailure(
          message: 'An unexpected error occurred during study generation',
          code: 'UNEXPECTED_ERROR',
          context: {'error': e.toString()},
        ),
      ));
    }
  }

  /// Handles clearing the study guide state.
  void handleClearStudyGuide(
    StudyGuideCleared event,
    Emitter<StudyState> emit,
  ) {
    emit(const StudyInitial());
  }

  /// Determines if a failure is retryable.
  ///
  /// [failure] The failure to check.
  /// Returns true if the user should be allowed to retry the operation.
  bool _isRetryableFailure(Failure failure) => switch (failure.runtimeType) {
        NetworkFailure _ || ServerFailure _ || RateLimitFailure _ => true,
        ValidationFailure _ ||
        AuthenticationFailure _ ||
        AuthorizationFailure _ =>
          false,
        _ => true,
      };

  /// SECURITY FIX: Creates a new failure with sanitized message
  ///
  /// Preserves the failure type and important fields while replacing
  /// the message with a sanitized version.
  Failure _createSanitizedFailure(
      Failure originalFailure, String sanitizedMessage) {
    return switch (originalFailure) {
      final NetworkFailure f => NetworkFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final ServerFailure f => ServerFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final AuthenticationFailure f => AuthenticationFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final AuthorizationFailure f => AuthorizationFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final ValidationFailure f => ValidationFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final RateLimitFailure f => RateLimitFailure(
          message: sanitizedMessage,
          code: f.code,
          retryAfter: f.retryAfter,
          context: f.context,
        ),
      final InsufficientTokensFailure f => InsufficientTokensFailure(
          requiredTokens: f.requiredTokens,
          availableTokens: f.availableTokens,
          nextResetTime: f.nextResetTime,
        ),
      final TokenPaymentFailure f => TokenPaymentFailure(
          paymentError: f.paymentError,
        ),
      final PlanUpgradeFailure f => PlanUpgradeFailure(
          upgradeError: f.upgradeError,
        ),
      final StorageFailure f => StorageFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final CacheFailure f => CacheFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final NotFoundFailure f => NotFoundFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final DatabaseFailure f => DatabaseFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final PaymentFailure f => PaymentFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      final TokenFailure f => TokenFailure(
          message: sanitizedMessage,
          code: f.code,
          context: f.context,
        ),
      _ => ClientFailure(
          message: sanitizedMessage,
          code: originalFailure.code,
          context: originalFailure.context,
        ),
    };
  }
}
