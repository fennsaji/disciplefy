import 'package:equatable/equatable.dart';

/// Events for LearningPathsBloc
abstract class LearningPathsEvent extends Equatable {
  const LearningPathsEvent();

  @override
  List<Object?> get props => [];
}

/// Load available learning paths.
class LoadLearningPaths extends LearningPathsEvent {
  /// Language code for localization
  final String language;

  /// Whether to include enrolled paths
  final bool includeEnrolled;

  /// Whether to force a refresh (bypass cache)
  final bool forceRefresh;

  const LoadLearningPaths({
    this.language = 'en',
    this.includeEnrolled = true,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [language, includeEnrolled, forceRefresh];
}

/// Load details for a specific learning path.
class LoadLearningPathDetails extends LearningPathsEvent {
  /// The ID of the learning path
  final String pathId;

  /// Language code for localization
  final String language;

  /// Whether to force a refresh (bypass cache)
  final bool forceRefresh;

  const LoadLearningPathDetails({
    required this.pathId,
    this.language = 'en',
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [pathId, language, forceRefresh];
}

/// Enroll in a learning path.
class EnrollInLearningPath extends LearningPathsEvent {
  /// The ID of the learning path to enroll in
  final String pathId;

  const EnrollInLearningPath({required this.pathId});

  @override
  List<Object?> get props => [pathId];
}

/// Refresh learning paths (force refresh).
class RefreshLearningPaths extends LearningPathsEvent {
  /// Language code for localization
  final String language;

  const RefreshLearningPaths({this.language = 'en'});

  @override
  List<Object?> get props => [language];
}

/// Clear cached learning paths data.
class ClearLearningPathsCache extends LearningPathsEvent {
  const ClearLearningPathsCache();
}
