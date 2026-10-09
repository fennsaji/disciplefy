import 'package:equatable/equatable.dart';

import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// Status of the first page of the current list.
enum AllPathsStatus { loading, loaded, error }

/// The All paths list: one server-paged list of either every path, one
/// category's paths, or a search's matches.
class AllPathsState extends Equatable {
  /// Content language; null until the page opened.
  final String? language;

  /// Selected category; null for "All".
  final String? category;

  /// Search text; empty when not searching.
  final String query;

  final AllPathsStatus status;

  /// Paths loaded so far, in server order, without duplicates.
  final List<LearningPath> paths;

  /// Offset of the next page.
  final int nextOffset;

  /// The server has more paths for this list.
  final bool hasMore;

  /// The next page is being fetched.
  final bool loadingMore;

  /// The next page failed; only the footer's Retry asks again.
  final bool moreFailed;

  /// A refresh is replacing the list that stays on screen.
  final bool refreshing;

  /// Every category with its path count (empty until it lands or if it
  /// failed).
  final List<LearningPathCategorySummary> categories;

  /// Number of active paths per the server, null while unknown.
  final int? listTotal;

  const AllPathsState({
    this.language,
    this.category,
    this.query = '',
    this.status = AllPathsStatus.loading,
    this.paths = const [],
    this.nextOffset = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreFailed = false,
    this.refreshing = false,
    this.categories = const [],
    this.listTotal,
  });

  bool get searching => query.isNotEmpty;

  /// Number of paths in the whole catalogue: the server's total, else the
  /// sum of the category counts; null when neither is known.
  int? get allTotal {
    final total = listTotal;
    if (total != null) return total;
    if (categories.isEmpty) return null;
    return categories.fold<int>(0, (sum, c) => sum + c.totalPaths);
  }

  AllPathsState copyWith({
    String? language,
    String? category,
    bool clearCategory = false,
    String? query,
    AllPathsStatus? status,
    List<LearningPath>? paths,
    int? nextOffset,
    bool? hasMore,
    bool? loadingMore,
    bool? moreFailed,
    bool? refreshing,
    List<LearningPathCategorySummary>? categories,
    int? listTotal,
    bool clearListTotal = false,
  }) =>
      AllPathsState(
        language: language ?? this.language,
        category: clearCategory ? null : (category ?? this.category),
        query: query ?? this.query,
        status: status ?? this.status,
        paths: paths ?? this.paths,
        nextOffset: nextOffset ?? this.nextOffset,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        moreFailed: moreFailed ?? this.moreFailed,
        refreshing: refreshing ?? this.refreshing,
        categories: categories ?? this.categories,
        listTotal: clearListTotal ? null : (listTotal ?? this.listTotal),
      );

  @override
  List<Object?> get props => [
        language,
        category,
        query,
        status,
        paths,
        nextOffset,
        hasMore,
        loadingMore,
        moreFailed,
        refreshing,
        categories,
        listTotal,
      ];
}
