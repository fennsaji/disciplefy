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

/// Loaded state with learning paths.
class LearningPathsLoaded extends LearningPathsState {
  /// List of available learning paths
  final List<LearningPath> paths;

  /// List of enrolled paths (filtered from all paths)
  final List<LearningPath> enrolledPaths;

  /// Total number of paths available
  final int total;

  const LearningPathsLoaded({
    required this.paths,
    this.enrolledPaths = const [],
    this.total = 0,
  });

  @override
  List<Object?> get props => [paths, enrolledPaths, total];

  /// Whether there are paths to display
  bool get hasPaths => paths.isNotEmpty;

  /// Featured paths (first 2 or ones marked as featured)
  List<LearningPath> get featuredPaths {
    final featured = paths.where((p) => p.isFeatured).toList();
    if (featured.isNotEmpty) return featured.take(2).toList();
    return paths.take(2).toList();
  }

  /// Whether the user has any enrolled paths
  bool get hasEnrolledPaths => enrolledPaths.isNotEmpty;
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
