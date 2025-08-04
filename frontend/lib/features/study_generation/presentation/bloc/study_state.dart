import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/study_guide.dart';

/// States for the Study Generation BLoC.
///
/// These states represent the current status of study guide generation
/// and related operations.
abstract class StudyState extends Equatable {
  const StudyState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no study generation has been attempted.
class StudyInitial extends StudyState {
  const StudyInitial();
}

/// State indicating that study guide generation is in progress.
class StudyGenerationInProgress extends StudyState {
  /// Optional progress indicator (0.0 to 1.0).
  final double? progress;

  const StudyGenerationInProgress({this.progress});

  @override
  List<Object?> get props => [progress];
}

/// State indicating successful study guide generation.
class StudyGenerationSuccess extends StudyState {
  /// The generated study guide.
  final StudyGuide studyGuide;

  /// Timestamp of generation for caching purposes.
  final DateTime generatedAt;

  const StudyGenerationSuccess({
    required this.studyGuide,
    required this.generatedAt,
  });

  @override
  List<Object> get props => [studyGuide, generatedAt];
}

/// State indicating that study guide generation failed.
class StudyGenerationFailure extends StudyState {
  /// The failure that occurred.
  final Failure failure;

  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudyGenerationFailure({
    required this.failure,
    this.isRetryable = true,
  });

  @override
  List<Object> get props => [failure, isRetryable];
}

/// State indicating that a study guide save operation is in progress.
class StudySaveInProgress extends StudyState {
  /// The ID of the study guide being saved.
  final String guideId;

  const StudySaveInProgress({
    required this.guideId,
  });

  @override
  List<Object> get props => [guideId];
}

/// State indicating successful study guide save/unsave operation.
class StudySaveSuccess extends StudyState {
  /// The ID of the study guide that was saved/unsaved.
  final String guideId;

  /// Whether the guide was saved (true) or unsaved (false).
  final bool saved;

  /// Success message to display to user.
  final String message;

  const StudySaveSuccess({
    required this.guideId,
    required this.saved,
    required this.message,
  });

  @override
  List<Object> get props => [guideId, saved, message];
}

/// State indicating that study guide save operation failed.
class StudySaveFailure extends StudyState {
  /// The ID of the study guide that failed to save.
  final String guideId;

  /// The failure that occurred.
  final Failure failure;

  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudySaveFailure({
    required this.guideId,
    required this.failure,
    this.isRetryable = true,
  });

  @override
  List<Object> get props => [guideId, failure, isRetryable];
}

/// State indicating the current validation status of input.
class StudyInputValidation extends StudyState {
  /// Whether the current input is valid.
  final bool isValid;

  /// Error message if input is invalid (null if valid or empty).
  final String? errorMessage;

  /// The input text that was validated.
  final String input;

  /// The input type that was validated.
  final String inputType;

  const StudyInputValidation({
    required this.isValid,
    required this.input,
    required this.inputType,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [isValid, errorMessage, input, inputType];
}

/// State indicating authentication is required for the requested operation.
class StudyAuthenticationRequired extends StudyState {
  /// The ID of the study guide that requires authentication to save.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide after authentication.
  final bool save;

  /// Message to display to the user explaining why authentication is needed.
  final String message;

  const StudyAuthenticationRequired({
    required this.guideId,
    required this.save,
    required this.message,
  });

  @override
  List<Object> get props => [guideId, save, message];
}
