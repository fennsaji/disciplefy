import 'package:equatable/equatable.dart';

/// Entity representing filter criteria for study topics search.
class StudyTopicsFilter extends Equatable {
  /// Selected categories for filtering (empty means all categories)
  final List<String> selectedCategories;

  /// Search query for title/description filtering
  final String searchQuery;

  /// Number of topics per page for pagination
  final int limit;

  /// Current page offset for pagination
  final int offset;

  /// Language code for topics (e.g., 'en', 'hi', 'ml')
  final String language;

  const StudyTopicsFilter({
    this.selectedCategories = const [],
    this.searchQuery = '',
    this.limit = 10,
    this.offset = 0,
    this.language = 'en',
  });

  /// Creates a copy with updated fields
  StudyTopicsFilter copyWith({
    List<String>? selectedCategories,
    String? searchQuery,
    int? limit,
    int? offset,
    String? language,
  }) =>
      StudyTopicsFilter(
        selectedCategories: selectedCategories ?? this.selectedCategories,
        searchQuery: searchQuery ?? this.searchQuery,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
        language: language ?? this.language,
      );

  /// Reset filter to default state
  StudyTopicsFilter clear() => const StudyTopicsFilter();

  /// Check if any filters are applied
  bool get hasFilters =>
      selectedCategories.isNotEmpty || searchQuery.isNotEmpty;

  /// Check if category filters are applied
  bool get hasCategoryFilters => selectedCategories.isNotEmpty;

  /// Check if search filter is applied
  bool get hasSearchFilter => searchQuery.isNotEmpty;

  /// Get categories as comma-separated string for API
  String? get categoriesAsString =>
      selectedCategories.isEmpty ? null : selectedCategories.join(',');

  @override
  List<Object?> get props => [
        selectedCategories,
        searchQuery,
        limit,
        offset,
        language,
      ];

  @override
  String toString() => 'StudyTopicsFilter('
      'categories: $selectedCategories, '
      'search: "$searchQuery", '
      'limit: $limit, '
      'offset: $offset, '
      'language: $language)';
}
