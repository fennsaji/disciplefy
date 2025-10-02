import 'package:equatable/equatable.dart';

/// Events for the Home Study Generation BLoC.
abstract class HomeStudyGenerationEvent extends Equatable {
  const HomeStudyGenerationEvent();

  @override
  List<Object?> get props => [];
}

/// Event to generate a study guide from a verse reference.
class GenerateStudyGuideFromVerse extends HomeStudyGenerationEvent {
  /// The verse reference to generate a study guide from.
  final String verseReference;

  /// The language for the study guide.
  final String language;

  const GenerateStudyGuideFromVerse({
    required this.verseReference,
    required this.language,
  });

  @override
  List<Object?> get props => [verseReference, language];
}

/// Event to generate a study guide from a topic.
class GenerateStudyGuideFromTopic extends HomeStudyGenerationEvent {
  /// The topic name to generate a study guide from.
  final String topicName;

  /// The language for the study guide.
  final String language;

  const GenerateStudyGuideFromTopic({
    required this.topicName,
    required this.language,
  });

  @override
  List<Object?> get props => [topicName, language];
}

/// Event to generate a study guide from a question.
class GenerateStudyGuideFromQuestion extends HomeStudyGenerationEvent {
  /// The question to generate a study guide from.
  final String question;

  /// The language for the study guide.
  final String language;

  const GenerateStudyGuideFromQuestion({
    required this.question,
    required this.language,
  });

  @override
  List<Object?> get props => [question, language];
}

/// Event to clear error state.
class ClearHomeStudyGenerationError extends HomeStudyGenerationEvent {
  const ClearHomeStudyGenerationError();
}
