import 'package:equatable/equatable.dart';

import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';

/// States for the StudyTopicsBloc
abstract class StudyTopicsState extends Equatable {
  const StudyTopicsState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class StudyTopicsInitial extends StudyTopicsState {
  const StudyTopicsInitial();
}

/// Loading state for initial data (topics + categories)
class StudyTopicsLoading extends StudyTopicsState {
  const StudyTopicsLoading();
}

/// Loading state specifically for applying filters
class StudyTopicsFiltering extends StudyTopicsState {
  /// Current loaded topics (to show while filtering)
  final List<RecommendedGuideTopic> currentTopics;

  /// Available categories
  final List<String> categories;

  /// Current filter being applied
  final StudyTopicsFilter currentFilter;

  const StudyTopicsFiltering({
    required this.currentTopics,
    required this.categories,
    required this.currentFilter,
  });

  @override
  List<Object?> get props => [currentTopics, categories, currentFilter];
}

/// Loading more topics for pagination
class StudyTopicsLoadingMore extends StudyTopicsState {
  /// Current loaded topics
  final List<RecommendedGuideTopic> currentTopics;

  /// Available categories
  final List<String> categories;

  /// Current applied filter
  final StudyTopicsFilter currentFilter;

  /// Whether there are more topics to load
  final bool hasMore;

  const StudyTopicsLoadingMore({
    required this.currentTopics,
    required this.categories,
    required this.currentFilter,
    required this.hasMore,
  });

  @override
  List<Object?> get props =>
      [currentTopics, categories, currentFilter, hasMore];
}

/// Successfully loaded topics with all data
class StudyTopicsLoaded extends StudyTopicsState {
  /// List of loaded topics
  final List<RecommendedGuideTopic> topics;

  /// Available categories for filtering
  final List<String> categories;

  /// Current applied filter
  final StudyTopicsFilter currentFilter;

  /// Whether there are more topics to load
  final bool hasMore;

  /// Total number of topics available (for display purposes)
  final int? totalCount;

  const StudyTopicsLoaded({
    required this.topics,
    required this.categories,
    required this.currentFilter,
    this.hasMore = false,
    this.totalCount,
  });

  @override
  List<Object?> get props => [
        topics,
        categories,
        currentFilter,
        hasMore,
        totalCount,
      ];

  /// Create a copy with updated values
  StudyTopicsLoaded copyWith({
    List<RecommendedGuideTopic>? topics,
    List<String>? categories,
    StudyTopicsFilter? currentFilter,
    bool? hasMore,
    int? totalCount,
  }) =>
      StudyTopicsLoaded(
        topics: topics ?? this.topics,
        categories: categories ?? this.categories,
        currentFilter: currentFilter ?? this.currentFilter,
        hasMore: hasMore ?? this.hasMore,
        totalCount: totalCount ?? this.totalCount,
      );
}

/// Error state
class StudyTopicsError extends StudyTopicsState {
  /// Error message to display
  final String message;

  /// Optional error code for specific handling
  final String? errorCode;

  /// Whether this error occurred during initial load or subsequent operations
  final bool isInitialLoadError;

  const StudyTopicsError({
    required this.message,
    this.errorCode,
    this.isInitialLoadError = true,
  });

  @override
  List<Object?> get props => [message, errorCode, isInitialLoadError];
}

/// Empty state when no topics match the current filter
class StudyTopicsEmpty extends StudyTopicsState {
  /// Available categories for filtering
  final List<String> categories;

  /// Current applied filter that resulted in empty results
  final StudyTopicsFilter currentFilter;

  const StudyTopicsEmpty({
    required this.categories,
    required this.currentFilter,
  });

  @override
  List<Object?> get props => [categories, currentFilter];
}
