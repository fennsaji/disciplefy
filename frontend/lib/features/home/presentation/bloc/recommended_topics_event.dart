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

  const LoadRecommendedTopics({
    this.limit,
    this.category,
    this.difficulty,
  });

  @override
  List<Object?> get props => [limit, category, difficulty];
}

/// Event to refresh recommended topics.
class RefreshRecommendedTopics extends RecommendedTopicsEvent {
  const RefreshRecommendedTopics();
}

/// Event to clear error state.
class ClearRecommendedTopicsError extends RecommendedTopicsEvent {
  const ClearRecommendedTopicsError();
}