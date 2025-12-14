import 'package:equatable/equatable.dart';

/// Events for the Study Generation BLoC.
///
/// These events represent user actions that trigger study guide generation
/// or related operations.
abstract class StudyEvent extends Equatable {
  const StudyEvent();

  @override
  List<Object?> get props => [];
}

/// Event to request generation of a new study guide.
///
/// This event is triggered when a user submits a verse or topic
/// for study guide generation.
class GenerateStudyGuideRequested extends StudyEvent {
  /// The input text (verse reference or topic).
  final String input;

  /// The type of input ('scripture' or 'topic').
  final String inputType;

  /// Optional topic description for providing additional context.
  final String? topicDescription;

  /// Optional language code for the study guide.
  final String? language;

  const GenerateStudyGuideRequested({
    required this.input,
    required this.inputType,
    this.topicDescription,
    this.language,
  });

  @override
  List<Object?> get props =>
      [input, inputType, topicDescription ?? '', language ?? ''];
}

/// Event to clear the current study guide state.
class StudyGuideCleared extends StudyEvent {
  const StudyGuideCleared();
}

/// Event to save a study guide.
class SaveStudyGuideRequested extends StudyEvent {
  /// The ID of the study guide to save.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide.
  final bool save;

  const SaveStudyGuideRequested({
    required this.guideId,
    required this.save,
  });

  @override
  List<Object?> get props => [guideId, save];
}

/// Event to validate input text.
///
/// This event is triggered when user types to provide real-time validation feedback.
class ValidateInputRequested extends StudyEvent {
  /// The input text to validate.
  final String input;

  /// The type of input ('scripture' or 'topic').
  final String inputType;

  const ValidateInputRequested({
    required this.input,
    required this.inputType,
  });

  @override
  List<Object?> get props => [input, inputType];
}

/// Event to check authentication status before save operation.
///
/// This event is triggered when user attempts to save a study guide
/// to validate they are properly authenticated.
class CheckAuthenticationRequested extends StudyEvent {
  /// The ID of the study guide to potentially save.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide if authenticated.
  final bool save;

  const CheckAuthenticationRequested({
    required this.guideId,
    required this.save,
  });

  @override
  List<Object?> get props => [guideId, save];
}

/// Event to request enhanced save operation with personal notes.
///
/// This event combines study guide saving with personal notes persistence.
class EnhancedSaveStudyGuideRequested extends StudyEvent {
  /// The ID of the study guide to save.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide.
  final bool save;

  /// Personal notes to save with the guide (null to delete notes).
  final String? personalNotes;

  const EnhancedSaveStudyGuideRequested({
    required this.guideId,
    required this.save,
    this.personalNotes,
  });

  @override
  List<Object?> get props => [guideId, save, personalNotes];
}

/// Event to check authentication for enhanced save operation.
///
/// This event validates authentication before performing combined
/// guide saving and personal notes operations.
class CheckEnhancedAuthenticationRequested extends StudyEvent {
  /// The ID of the study guide to potentially save.
  final String guideId;

  /// Whether to save (true) or unsave (false) the guide if authenticated.
  final bool save;

  /// Personal notes to save with the guide if authenticated.
  final String? personalNotes;

  const CheckEnhancedAuthenticationRequested({
    required this.guideId,
    required this.save,
    this.personalNotes,
  });

  @override
  List<Object?> get props => [guideId, save, personalNotes];
}

/// Event to update personal notes independently.
///
/// This event is used for auto-save functionality to persist notes
/// without affecting the study guide save status.
class UpdatePersonalNotesRequested extends StudyEvent {
  /// The ID of the study guide to update notes for.
  final String guideId;

  /// Personal notes to save (null to delete notes).
  final String? personalNotes;

  /// Whether this is an auto-save operation (affects UI feedback).
  final bool isAutoSave;

  const UpdatePersonalNotesRequested({
    required this.guideId,
    this.personalNotes,
    this.isAutoSave = false,
  });

  @override
  List<Object?> get props => [guideId, personalNotes, isAutoSave];
}

/// Event to load personal notes for a study guide.
///
/// This event fetches existing personal notes when viewing a saved study guide.
class LoadPersonalNotesRequested extends StudyEvent {
  /// The ID of the study guide to load notes for.
  final String guideId;

  const LoadPersonalNotesRequested({
    required this.guideId,
  });

  @override
  List<Object?> get props => [guideId];
}

/// Event to mark a study guide as completed.
///
/// This event is triggered automatically when both completion conditions are met:
/// 1. User spent at least 60 seconds on the study guide page
/// 2. User scrolled to the bottom of the content
///
/// Completed guides are excluded from recommended topic push notifications.
class MarkStudyGuideCompleteRequested extends StudyEvent {
  /// The ID of the study guide to mark as complete.
  final String guideId;

  /// Total time spent reading the study guide in seconds.
  final int timeSpentSeconds;

  /// Whether the user scrolled to the bottom of the study guide.
  final bool scrolledToBottom;

  const MarkStudyGuideCompleteRequested({
    required this.guideId,
    required this.timeSpentSeconds,
    required this.scrolledToBottom,
  });

  @override
  List<Object?> get props => [guideId, timeSpentSeconds, scrolledToBottom];
}

// ==================== Streaming Events ====================

/// Event to request streaming generation of a study guide.
///
/// This event uses SSE streaming for progressive section rendering,
/// reducing perceived loading time.
class GenerateStudyGuideStreamingRequested extends StudyEvent {
  /// The input text (verse reference or topic).
  final String input;

  /// The type of input ('scripture', 'topic', or 'question').
  final String inputType;

  /// Optional topic description for providing additional context.
  final String? topicDescription;

  /// Language code for the study guide.
  final String language;

  const GenerateStudyGuideStreamingRequested({
    required this.input,
    required this.inputType,
    this.topicDescription,
    required this.language,
  });

  @override
  List<Object?> get props => [input, inputType, topicDescription, language];
}

/// Internal event when a streaming section is received.
///
/// This event is dispatched internally when the SSE stream
/// delivers a completed section.
class StudyStreamSectionReceived extends StudyEvent {
  /// The section event containing type and content.
  final dynamic sectionEvent;

  const StudyStreamSectionReceived({required this.sectionEvent});

  @override
  List<Object?> get props => [sectionEvent];
}

/// Internal event when streaming completes successfully.
class StudyStreamCompleted extends StudyEvent {
  /// The study guide ID from the backend.
  final String studyGuideId;

  /// Number of tokens consumed.
  final int tokensConsumed;

  /// Whether content was from cache.
  final bool fromCache;

  const StudyStreamCompleted({
    required this.studyGuideId,
    required this.tokensConsumed,
    required this.fromCache,
  });

  @override
  List<Object?> get props => [studyGuideId, tokensConsumed, fromCache];
}

/// Internal event when streaming encounters an error.
class StudyStreamErrorOccurred extends StudyEvent {
  /// Error code from the backend.
  final String code;

  /// Error message.
  final String message;

  /// Whether the error is retryable.
  final bool retryable;

  const StudyStreamErrorOccurred({
    required this.code,
    required this.message,
    required this.retryable,
  });

  @override
  List<Object?> get props => [code, message, retryable];
}

/// Event to cancel an ongoing streaming generation.
class CancelStudyStreamingRequested extends StudyEvent {
  const CancelStudyStreamingRequested();
}
