import 'package:equatable/equatable.dart';

import '../../domain/entities/study_topics_filter.dart';

/// Events for the StudyTopicsBloc
abstract class StudyTopicsEvent extends Equatable {
  const StudyTopicsEvent();

  @override
  List<Object?> get props => [];
}

/// Load initial topics and categories
class LoadStudyTopics extends StudyTopicsEvent {
  /// Optional initial filter to apply
  final StudyTopicsFilter? initialFilter;

  /// Force refresh from API (bypass cache)
  final bool forceRefresh;

  const LoadStudyTopics({
    this.initialFilter,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [initialFilter, forceRefresh];
}

/// Apply category filters
class FilterByCategories extends StudyTopicsEvent {
  /// List of selected category names
  final List<String> selectedCategories;

  const FilterByCategories(this.selectedCategories);

  @override
  List<Object?> get props => [selectedCategories];
}

/// Apply search query filter
class SearchTopics extends StudyTopicsEvent {
  /// Search query string
  final String query;

  const SearchTopics(this.query);

  @override
  List<Object?> get props => [query];
}

/// Load more topics for pagination
class LoadMoreTopics extends StudyTopicsEvent {
  const LoadMoreTopics();
}

/// Refresh all data (pull-to-refresh)
class RefreshStudyTopics extends StudyTopicsEvent {
  const RefreshStudyTopics();
}

/// Clear all filters and reset to initial state
class ClearFilters extends StudyTopicsEvent {
  const ClearFilters();
}

/// Clear error state
class ClearError extends StudyTopicsEvent {
  const ClearError();
}

/// Update language for topics
class ChangeLanguage extends StudyTopicsEvent {
  /// Language code (e.g., 'en', 'hi', 'ml')
  final String language;

  const ChangeLanguage(this.language);

  @override
  List<Object?> get props => [language];
}
