import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/entities/study_stream_event.dart';

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

/// State indicating that study guide is being streamed progressively.
///
/// This state holds partial content as sections arrive from the SSE stream.
/// UI can render available sections while waiting for remaining ones.
class StudyGenerationStreaming extends StudyState {
  /// Accumulated streaming content with sections loaded so far.
  final StreamingStudyGuideContent content;

  /// Input type used for generation (for context).
  final String inputType;

  /// Input value used for generation (for context).
  final String inputValue;

  /// Language of the study guide.
  final String language;

  const StudyGenerationStreaming({
    required this.content,
    required this.inputType,
    required this.inputValue,
    required this.language,
  });

  /// Convenience getter for progress (0.0 to 1.0).
  double get progress => content.progress;

  /// Whether all sections have been loaded.
  bool get isComplete => content.isComplete;

  /// Whether content is from cache.
  bool get isFromCache => content.isFromCache;

  /// Create a new state with an additional section.
  StudyGenerationStreaming withSection(StudyStreamSectionEvent section) {
    return StudyGenerationStreaming(
      content: content.copyWithSection(section),
      inputType: inputType,
      inputValue: inputValue,
      language: language,
    );
  }

  @override
  List<Object?> get props => [content.props, inputType, inputValue, language];
}

/// State indicating streaming failed but partial content may be available.
class StudyGenerationStreamingFailed extends StudyState {
  /// Partial content that was received before failure.
  final StreamingStudyGuideContent? partialContent;

  /// The failure that occurred.
  final Failure failure;

  /// Whether the failure is retryable.
  final bool canRetry;

  /// Input type used for generation (for retry).
  final String inputType;

  /// Input value used for generation (for retry).
  final String inputValue;

  /// Language of the study guide (for retry).
  final String language;

  const StudyGenerationStreamingFailed({
    this.partialContent,
    required this.failure,
    required this.canRetry,
    required this.inputType,
    required this.inputValue,
    required this.language,
  });

  /// Whether any partial content is available.
  bool get hasPartialContent =>
      partialContent != null && partialContent!.sectionsLoaded > 0;

  @override
  List<Object?> get props => [
        partialContent?.props,
        failure,
        canRetry,
        inputType,
        inputValue,
        language,
      ];
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

/// State indicating that an enhanced save operation is in progress.
///
/// This combines study guide saving with personal notes operations.
class StudyEnhancedSaveInProgress extends StudyState {
  /// The ID of the study guide being saved.
  final String guideId;

  /// Progress indicator for the operation (0.0 to 1.0).
  final double? progress;

  /// Current step being performed (for user feedback).
  final String? currentStep;

  const StudyEnhancedSaveInProgress({
    required this.guideId,
    this.progress,
    this.currentStep,
  });

  @override
  List<Object?> get props => [guideId, progress, currentStep];
}

/// State indicating successful enhanced save operation.
///
/// This state is emitted when both study guide and personal notes
/// operations complete successfully.
class StudyEnhancedSaveSuccess extends StudyState {
  /// The ID of the study guide that was saved.
  final String guideId;

  /// Whether the guide was saved (true) or unsaved (false).
  final bool guideSaved;

  /// Whether personal notes were saved successfully.
  final bool notesSaved;

  /// Success message to display to user.
  final String message;

  /// The saved personal notes content (for state consistency).
  final String? savedNotes;

  const StudyEnhancedSaveSuccess({
    required this.guideId,
    required this.guideSaved,
    required this.notesSaved,
    required this.message,
    this.savedNotes,
  });

  @override
  List<Object?> get props =>
      [guideId, guideSaved, notesSaved, message, savedNotes];
}

/// State indicating that an enhanced save operation failed.
///
/// This state provides detailed information about which operations
/// succeeded and which failed for proper error handling.
class StudyEnhancedSaveFailure extends StudyState {
  /// The ID of the study guide that failed to save.
  final String guideId;

  /// Whether the guide save operation succeeded.
  final bool guideSaveSuccess;

  /// Whether the notes save operation succeeded.
  final bool notesSaveSuccess;

  /// The primary failure that occurred.
  final Failure primaryFailure;

  /// Secondary failure (if one operation succeeded and another failed).
  final Failure? secondaryFailure;

  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudyEnhancedSaveFailure({
    required this.guideId,
    required this.guideSaveSuccess,
    required this.notesSaveSuccess,
    required this.primaryFailure,
    this.secondaryFailure,
    this.isRetryable = true,
  });

  @override
  List<Object?> get props => [
        guideId,
        guideSaveSuccess,
        notesSaveSuccess,
        primaryFailure,
        secondaryFailure,
        isRetryable,
      ];
}

/// State indicating that personal notes operation is in progress.
class StudyPersonalNotesInProgress extends StudyState {
  /// The ID of the study guide being updated.
  final String guideId;

  /// Whether this is an auto-save operation.
  final bool isAutoSave;

  const StudyPersonalNotesInProgress({
    required this.guideId,
    this.isAutoSave = false,
  });

  @override
  List<Object> get props => [guideId, isAutoSave];
}

/// State indicating successful personal notes operation.
class StudyPersonalNotesSuccess extends StudyState {
  /// The ID of the study guide that was updated.
  final String guideId;

  /// The saved personal notes content.
  final String? savedNotes;

  /// Whether this was an auto-save operation.
  final bool isAutoSave;

  /// Success message to display to user (null for auto-save).
  final String? message;

  const StudyPersonalNotesSuccess({
    required this.guideId,
    this.savedNotes,
    this.isAutoSave = false,
    this.message,
  });

  @override
  List<Object?> get props => [guideId, savedNotes, isAutoSave, message];
}

/// State indicating that personal notes operation failed.
class StudyPersonalNotesFailure extends StudyState {
  /// The ID of the study guide that failed to update.
  final String guideId;

  /// The failure that occurred.
  final Failure failure;

  /// Whether this was an auto-save operation.
  final bool isAutoSave;

  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudyPersonalNotesFailure({
    required this.guideId,
    required this.failure,
    this.isAutoSave = false,
    this.isRetryable = true,
  });

  @override
  List<Object> get props => [guideId, failure, isAutoSave, isRetryable];
}

/// State containing loaded personal notes.
class StudyPersonalNotesLoaded extends StudyState {
  /// The ID of the study guide.
  final String guideId;

  /// The loaded personal notes content.
  final String? notes;

  /// Timestamp when notes were loaded (for cache invalidation).
  final DateTime loadedAt;

  const StudyPersonalNotesLoaded({
    required this.guideId,
    this.notes,
    required this.loadedAt,
  });

  @override
  List<Object?> get props => [guideId, notes, loadedAt];
}

/// State indicating authentication is required for enhanced operations.
class StudyEnhancedAuthenticationRequired extends StudyState {
  /// The ID of the study guide that requires authentication.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide after authentication.
  final bool save;

  /// Personal notes to save after authentication.
  final String? personalNotes;

  /// Message to display to the user explaining why authentication is needed.
  final String message;

  const StudyEnhancedAuthenticationRequired({
    required this.guideId,
    required this.save,
    this.personalNotes,
    required this.message,
  });

  @override
  List<Object?> get props => [guideId, save, personalNotes, message];
}

/// State indicating that marking a study guide as complete is in progress.
class StudyCompletionInProgress extends StudyState {
  /// The ID of the study guide being marked as complete.
  final String guideId;

  const StudyCompletionInProgress({
    required this.guideId,
  });

  @override
  List<Object> get props => [guideId];
}

/// State indicating successful study guide completion marking.
class StudyCompletionSuccess extends StudyState {
  /// The ID of the study guide that was marked as complete.
  final String guideId;

  /// Timestamp when the guide was completed.
  final DateTime completedAt;

  /// Time spent on the guide in seconds.
  final int timeSpentSeconds;

  const StudyCompletionSuccess({
    required this.guideId,
    required this.completedAt,
    required this.timeSpentSeconds,
  });

  @override
  List<Object> get props => [guideId, completedAt, timeSpentSeconds];
}

/// State indicating that marking study guide as complete failed.
class StudyCompletionFailure extends StudyState {
  /// The ID of the study guide that failed to mark as complete.
  final String guideId;

  /// The failure that occurred.
  final Failure failure;

  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudyCompletionFailure({
    required this.guideId,
    required this.failure,
    this.isRetryable = true,
  });

  @override
  List<Object> get props => [guideId, failure, isRetryable];
}
