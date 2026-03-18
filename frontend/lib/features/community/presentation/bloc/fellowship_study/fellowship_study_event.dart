import 'package:equatable/equatable.dart';

/// Base class for all FellowshipStudyBloc events.
abstract class FellowshipStudyEvent extends Equatable {
  const FellowshipStudyEvent();
}

/// Fired when the fellowship home screen initializes. Carries the fellowship
/// entity so the BLoC can set the initial current-study state and determine
/// the user's role.
class FellowshipStudyInitialized extends FellowshipStudyEvent {
  /// ID of the fellowship whose study is being managed.
  final String fellowshipId;

  /// Whether the current user is the fellowship mentor.
  final bool isMentor;

  /// ID of the currently active learning path, if any.
  final String? currentLearningPathId;

  /// Display title of the currently active learning path, if any.
  final String? currentPathTitle;

  /// Zero-based index of the guide currently being worked through.
  final int? currentGuideIndex;

  /// Total number of guides in the learning path, or null if unknown.
  final int? currentTotalGuides;

  const FellowshipStudyInitialized({
    required this.fellowshipId,
    required this.isMentor,
    this.currentLearningPathId,
    this.currentPathTitle,
    this.currentGuideIndex,
    this.currentTotalGuides,
  });

  @override
  List<Object?> get props => [
        fellowshipId,
        isMentor,
        currentLearningPathId,
        currentPathTitle,
        currentGuideIndex,
        currentTotalGuides,
      ];
}

/// Fired when the fellowship home screen appears to fetch fresh study data.
///
/// Calls the API to get the latest [currentGuideIndex] and path info.
/// Silently keeps existing state on failure so the screen still shows data.
class FellowshipStudyRefreshRequested extends FellowshipStudyEvent {
  const FellowshipStudyRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// Fired when a mentor taps "Advance to next guide" in the lessons tab.
class FellowshipStudyAdvanceRequested extends FellowshipStudyEvent {
  const FellowshipStudyAdvanceRequested();

  @override
  List<Object?> get props => [];
}

/// Fired when a mentor picks a learning path from the picker bottom-sheet.
class FellowshipStudySetRequested extends FellowshipStudyEvent {
  /// Fellowship that should be updated.
  final String fellowshipId;

  /// The learning path the mentor selected.
  final String learningPathId;

  /// Display title of the selected path (from the LearningPath entity).
  final String learningPathTitle;

  const FellowshipStudySetRequested({
    required this.fellowshipId,
    required this.learningPathId,
    required this.learningPathTitle,
  });

  @override
  List<Object?> get props => [fellowshipId, learningPathId, learningPathTitle];
}
