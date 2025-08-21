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

  /// Force refresh bypassing cache (default: false)
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

/// Event to refresh recommended topics.
class RefreshRecommendedTopics extends RecommendedTopicsEvent {
  const RefreshRecommendedTopics();
}

/// Event to clear error state.
class ClearRecommendedTopicsError extends RecommendedTopicsEvent {
  const ClearRecommendedTopicsError();
}
