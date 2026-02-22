import 'package:equatable/equatable.dart';

import '../../domain/entities/learning_path.dart';

/// States for LearningPathsBloc
abstract class LearningPathsState extends Equatable {
  const LearningPathsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action.
class LearningPathsInitial extends LearningPathsState {
  const LearningPathsInitial();
}

/// Loading state while fetching paths.
class LearningPathsLoading extends LearningPathsState {
  const LearningPathsLoading();
}

/// Loaded state with category-grouped learning paths.
class LearningPathsLoaded extends LearningPathsState {
  /// Learning paths grouped by category (accumulated across pages)
  final List<LearningPathCategory> categories;

  /// Enrolled paths (derived from categories for quick access)
  final List<LearningPath> enrolledPaths;

  /// Whether more category pages are available from the server
  final bool hasMoreCategories;

  /// Whether a load-more-categories request is in flight
  final bool isFetchingMoreCategories;

  /// Offset to use for the next category page fetch
  final int nextCategoryOffset;

  /// Category names currently loading more paths (per-category load more)
  final List<String> loadingCategories;

  const LearningPathsLoaded({
    required this.categories,
    this.enrolledPaths = const [],
    this.hasMoreCategories = false,
    this.isFetchingMoreCategories = false,
    this.nextCategoryOffset = 4,
    this.loadingCategories = const [],
  });

  @override
  List<Object?> get props => [
        categories,
        enrolledPaths,
        hasMoreCategories,
        isFetchingMoreCategories,
        nextCategoryOffset,
        loadingCategories,
      ];

  /// Whether there are any paths to display
  bool get hasPaths => categories.any((c) => c.paths.isNotEmpty);

  /// All paths flattened across categories
  List<LearningPath> get allPaths => categories.expand((c) => c.paths).toList();

  /// Featured paths (first 2 marked as featured, or first 2 overall)
  List<LearningPath> get featuredPaths {
    final featured = allPaths.where((p) => p.isFeatured).toList();
    if (featured.isNotEmpty) return featured.take(2).toList();
    return allPaths.take(2).toList();
  }

  /// Whether the user has any enrolled paths
  bool get hasEnrolledPaths => enrolledPaths.isNotEmpty;

  /// Convenience: old flat `paths` accessor for backward compatibility
  List<LearningPath> get paths => allPaths;

  /// Whether more pages (categories or paths) are loading
  bool get hasMore => hasMoreCategories;

  LearningPathsLoaded copyWith({
    List<LearningPathCategory>? categories,
    List<LearningPath>? enrolledPaths,
    bool? hasMoreCategories,
    bool? isFetchingMoreCategories,
    int? nextCategoryOffset,
    List<String>? loadingCategories,
  }) {
    return LearningPathsLoaded(
      categories: categories ?? this.categories,
      enrolledPaths: enrolledPaths ?? this.enrolledPaths,
      hasMoreCategories: hasMoreCategories ?? this.hasMoreCategories,
      isFetchingMoreCategories:
          isFetchingMoreCategories ?? this.isFetchingMoreCategories,
      nextCategoryOffset: nextCategoryOffset ?? this.nextCategoryOffset,
      loadingCategories: loadingCategories ?? this.loadingCategories,
    );
  }
}

/// Loading state for learning path details.
class LearningPathDetailLoading extends LearningPathsState {
  final String pathId;

  const LearningPathDetailLoading({required this.pathId});

  @override
  List<Object?> get props => [pathId];
}

/// Loaded state with learning path details.
class LearningPathDetailLoaded extends LearningPathsState {
  /// The detailed learning path with topics
  final LearningPathDetail pathDetail;

  const LearningPathDetailLoaded({required this.pathDetail});

  @override
  List<Object?> get props => [pathDetail];
}

/// Enrolling state while enrolling in a path.
class LearningPathEnrolling extends LearningPathsState {
  final String pathId;

  const LearningPathEnrolling({required this.pathId});

  @override
  List<Object?> get props => [pathId];
}

/// Enrolled state after successful enrollment.
class LearningPathEnrolled extends LearningPathsState {
  /// The enrollment result
  final EnrollmentResult enrollment;

  const LearningPathEnrolled({required this.enrollment});

  @override
  List<Object?> get props => [enrollment];
}

/// Error state when fetching failed.
class LearningPathsError extends LearningPathsState {
  /// Error message to display
  final String message;

  /// Whether this was an initial load error (vs. refresh error)
  final bool isInitialLoadError;

  const LearningPathsError({
    required this.message,
    this.isInitialLoadError = true,
  });

  @override
  List<Object?> get props => [message, isInitialLoadError];
}

/// Empty state when no paths are available.
class LearningPathsEmpty extends LearningPathsState {
  const LearningPathsEmpty();
}
