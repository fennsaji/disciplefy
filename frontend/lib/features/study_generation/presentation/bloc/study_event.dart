import 'package:equatable/equatable.dart';

/// Events for the Study Generation BLoC.
///
/// These events represent user actions that trigger study guide generation
/// or related operations.
abstract class StudyEvent extends Equatable {
  const StudyEvent();

  @override
  List<Object> get props => [];
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

  /// Optional language code for the study guide.
  final String? language;

  const GenerateStudyGuideRequested({
    required this.input,
    required this.inputType,
    this.language,
  });

  @override
  List<Object> get props => [input, inputType, language ?? ''];
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
  List<Object> get props => [guideId, save];
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
  List<Object> get props => [input, inputType];
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
  List<Object> get props => [guideId, save];
}
