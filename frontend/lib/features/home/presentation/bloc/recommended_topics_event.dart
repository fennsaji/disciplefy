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
