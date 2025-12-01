import 'package:equatable/equatable.dart';

/// Events for the Recommended Topics BLoC.
abstract class RecommendedTopicsEvent extends Equatable {
  const RecommendedTopicsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load recommended topics with optional filters.
class LoadRecommendedTopics extends RecommendedTopicsEvent {
  /// Maximum number of topics to load.
  final int? limit;

  /// Category filter for topics.
  final String? category;

  /// Difficulty filter for topics.
  final String? difficulty;

  /// Language code for topic translations.
  final String? language;

  /// Force refresh bypassing cache (default: false)
  final bool forceRefresh;

  const LoadRecommendedTopics({
    this.limit,
    this.category,
    this.difficulty,
    this.language,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props =>
      [limit, category, difficulty, language, forceRefresh];
}

/// Event to refresh recommended topics.
class RefreshRecommendedTopics extends RecommendedTopicsEvent {
  const RefreshRecommendedTopics();
}

/// Event to clear error state.
class ClearRecommendedTopicsError extends RecommendedTopicsEvent {
  const ClearRecommendedTopicsError();
}

/// Event for language preference change from settings.
class LanguagePreferenceChanged extends RecommendedTopicsEvent {
  /// The new language code
  final String languageCode;

  const LanguagePreferenceChanged({required this.languageCode});

  @override
  List<Object?> get props => [languageCode];
}

/// Event to load personalized "For You" topics for authenticated users.
///
/// This event triggers the personalized topics endpoint which considers
/// the user's questionnaire responses and study history.
class LoadForYouTopics extends RecommendedTopicsEvent {
  /// Maximum number of topics to load (default: 4).
  final int limit;

  /// Language code for topic translations.
  final String? language;

  /// Force refresh bypassing cache (default: false)
  final bool forceRefresh;

  const LoadForYouTopics({
    this.limit = 4,
    this.language,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [limit, language, forceRefresh];
}

/// Event to dismiss the personalization prompt card.
///
/// This hides the prompt without skipping the questionnaire,
/// allowing it to potentially show again on next app open.
class DismissPersonalizationPrompt extends RecommendedTopicsEvent {
  const DismissPersonalizationPrompt();
}

/// Event to invalidate the "For You" cache after a study guide is completed.
///
/// This ensures that completed study guide topics are no longer shown
/// in the "For You" section when the user returns to the home screen.
class InvalidateForYouCache extends RecommendedTopicsEvent {
  const InvalidateForYouCache();
}
