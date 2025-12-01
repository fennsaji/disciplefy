import 'package:equatable/equatable.dart';

import 'recommended_topics_state.dart' as topics_states;
import 'home_study_generation_state.dart' as generation_states;

/// Events for the Home screen
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load recommended topics
class LoadRecommendedTopics extends HomeEvent {
  final int? limit;
  final String? category;
  final String? difficulty;
  final bool forceRefresh;

  const LoadRecommendedTopics({
    this.limit,
    this.category,
    this.difficulty,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [limit, category, difficulty, forceRefresh];
}

/// Event to refresh recommended topics
class RefreshRecommendedTopics extends HomeEvent {
  const RefreshRecommendedTopics();
}

/// Event to generate study guide from verse
class GenerateStudyGuideFromVerse extends HomeEvent {
  final String verseReference;
  final String language;

  const GenerateStudyGuideFromVerse({
    required this.verseReference,
    required this.language,
  });

  @override
  List<Object?> get props => [verseReference, language];
}

/// Event to generate study guide from topic
class GenerateStudyGuideFromTopic extends HomeEvent {
  final String topicName;
  final String language;

  const GenerateStudyGuideFromTopic({
    required this.topicName,
    required this.language,
  });

  @override
  List<Object?> get props => [topicName, language];
}

/// Event to clear any error states
class ClearHomeError extends HomeEvent {
  const ClearHomeError();
}

/// Event for language preference change from settings
class LanguagePreferenceChanged extends HomeEvent {
  const LanguagePreferenceChanged();
}

/// Event to load personalized "For You" topics for authenticated users.
///
/// This uses the personalized topics endpoint that considers the user's
/// questionnaire responses and study history for recommendations.
class LoadForYouTopics extends HomeEvent {
  final int limit;
  final bool forceRefresh;

  const LoadForYouTopics({
    this.limit = 4,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [limit, forceRefresh];
}

/// Event to dismiss the personalization prompt card.
///
/// This hides the prompt without skipping the questionnaire permanently.
class DismissPersonalizationPrompt extends HomeEvent {
  const DismissPersonalizationPrompt();
}

/// Event to load the user's active learning path for the For You section.
///
/// This fetches the learning path the user is currently enrolled in and
/// making progress on to display in the For You section of the home screen.
class LoadActiveLearningPath extends HomeEvent {
  final bool forceRefresh;

  const LoadActiveLearningPath({
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [forceRefresh];
}

// Internal coordination events (for BLoC implementation)

/// Internal event triggered when topics BLoC state changes
class TopicsStateChangedEvent extends HomeEvent {
  final topics_states.RecommendedTopicsState topicsState;

  const TopicsStateChangedEvent(this.topicsState);

  @override
  List<Object?> get props => [topicsState];
}

/// Internal event triggered when study generation BLoC state changes
class StudyGenerationStateChangedEvent extends HomeEvent {
  final generation_states.HomeStudyGenerationState generationState;

  const StudyGenerationStateChangedEvent(this.generationState);

  @override
  List<Object?> get props => [generationState];
}
