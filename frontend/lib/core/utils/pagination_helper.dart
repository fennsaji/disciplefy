/// Centralized pagination utility to eliminate magic numbers and duplicate logic
/// Provides consistent pagination behavior across the application
class PaginationHelper {
  /// Default page size for list-based UI components
  static const int defaultPageSize = 20;

  /// Default offset for starting pagination
  static const int defaultOffset = 0;

  /// Maximum page size to prevent excessive API calls
  static const int maxPageSize = 100;

  /// Minimum page size to ensure reasonable UI performance
  static const int minPageSize = 5;

  /// Calculate the next offset for pagination
  static int calculateNextOffset(int currentOffset, int pageSize) => currentOffset + pageSize;

  /// Calculate the previous offset for pagination
  static int calculatePreviousOffset(int currentOffset, int pageSize) {
    final previousOffset = currentOffset - pageSize;
    return previousOffset < 0 ? 0 : previousOffset;
  }

  /// Check if there are more items to load based on the returned count
  static bool hasMoreItems(int returnedCount, int pageSize) => returnedCount == pageSize;

  /// Calculate the total number of pages
  static int calculateTotalPages(int totalItems, int pageSize) => (totalItems / pageSize).ceil();

  /// Calculate which page number we're currently on (1-based)
  static int calculateCurrentPage(int offset, int pageSize) => (offset / pageSize).floor() + 1;

  /// Validate and clamp page size within acceptable bounds
  static int validatePageSize(int pageSize) {
    if (pageSize < minPageSize) return minPageSize;
    if (pageSize > maxPageSize) return maxPageSize;
    return pageSize;
  }

  /// Create pagination parameters with validation
  static PaginationParams createParams({
    int? limit,
    int? offset,
  }) =>
      PaginationParams(
        limit: validatePageSize(limit ?? defaultPageSize),
        offset: offset ?? defaultOffset,
      );

  /// Reset pagination to the beginning
  static PaginationParams reset({int? pageSize}) => PaginationParams(
        limit: validatePageSize(pageSize ?? defaultPageSize),
        offset: defaultOffset,
      );

  /// Get the next page parameters
  static PaginationParams nextPage(PaginationParams current) => PaginationParams(
        limit: current.limit,
        offset: calculateNextOffset(current.offset, current.limit),
      );

  /// Get the previous page parameters
  static PaginationParams previousPage(PaginationParams current) => PaginationParams(
        limit: current.limit,
        offset: calculatePreviousOffset(current.offset, current.limit),
      );
}

/// Data class for pagination parameters
class PaginationParams {
  final int limit;
  final int offset;

  const PaginationParams({
    required this.limit,
    required this.offset,
  });

  /// Create a copy with updated parameters
  PaginationParams copyWith({
    int? limit,
    int? offset,
  }) =>
      PaginationParams(
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );

  /// Check if this is the first page
  bool get isFirstPage => offset == 0;

  /// Calculate the page number (1-based)
  int get pageNumber => PaginationHelper.calculateCurrentPage(offset, limit);

  /// Convert to query parameters for API calls
  Map<String, String> toQueryParams() => {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

  @override
  String toString() => 'PaginationParams(limit: $limit, offset: $offset)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaginationParams && other.limit == limit && other.offset == offset;
  }

  @override
  int get hashCode => limit.hashCode ^ offset.hashCode;
}

/// Mixin for BLoCs that need pagination functionality
mixin PaginationMixin {
  /// Current pagination state for saved guides
  PaginationParams _savedPagination = PaginationHelper.reset();

  /// Current pagination state for recent guides
  PaginationParams _recentPagination = PaginationHelper.reset();

  /// Get current saved guides pagination
  PaginationParams get savedPagination => _savedPagination;

  /// Get current recent guides pagination
  PaginationParams get recentPagination => _recentPagination;

  /// Reset saved guides pagination
  void resetSavedPagination({int? pageSize}) {
    _savedPagination = PaginationHelper.reset(pageSize: pageSize);
  }

  /// Reset recent guides pagination
  void resetRecentPagination({int? pageSize}) {
    _recentPagination = PaginationHelper.reset(pageSize: pageSize);
  }

  /// Move to next page for saved guides
  void nextSavedPage() {
    _savedPagination = PaginationHelper.nextPage(_savedPagination);
  }

  /// Move to next page for recent guides
  void nextRecentPage() {
    _recentPagination = PaginationHelper.nextPage(_recentPagination);
  }

  /// Move to previous page for saved guides
  void previousSavedPage() {
    _savedPagination = PaginationHelper.previousPage(_savedPagination);
  }

  /// Move to previous page for recent guides
  void previousRecentPage() {
    _recentPagination = PaginationHelper.previousPage(_recentPagination);
  }
}

/// Extension to add pagination support to lists
extension PaginationExtension<T> on List<T> {
  /// Check if the list indicates there might be more items
  bool hasMoreItems(int pageSize) => PaginationHelper.hasMoreItems(length, pageSize);

  /// Paginate a list locally (for in-memory pagination)
  List<T> paginate(PaginationParams params) {
    final startIndex = params.offset;
    final endIndex = startIndex + params.limit;

    if (startIndex >= length) return [];

    return sublist(
      startIndex,
      endIndex > length ? length : endIndex,
    );
  }
}
