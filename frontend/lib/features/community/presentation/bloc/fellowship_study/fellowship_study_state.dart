import 'package:equatable/equatable.dart';

/// Status of the set-study operation triggered when a mentor picks a path.
enum FellowshipStudySetStatus { idle, loading, success, failure }

/// Status of the advance-study operation.
enum FellowshipStudyAdvanceStatus { idle, loading, success, failure }

/// State for [FellowshipStudyBloc].
class FellowshipStudyState extends Equatable {
  /// ID of the fellowship this state belongs to.
  final String fellowshipId;

  /// Whether the current user is the fellowship mentor.
  final bool isMentor;

  /// ID of the currently active learning path, or null if none assigned.
  final String? currentLearningPathId;

  /// Display title of the currently active learning path.
  ///
  /// Populated after the mentor sets a path, or from the passed-in title on
  /// initialization.
  final String? currentPathTitle;

  /// Status of the set-study API call.
  final FellowshipStudySetStatus setStatus;

  /// Error message from a failed set-study call.
  final String? setError;

  /// Status of the advance-guide operation.
  final FellowshipStudyAdvanceStatus advanceStatus;

  /// Error message from a failed advance call.
  final String? advanceError;

  /// Whether the study path is fully completed after an advance.
  final bool studyCompleted;

  /// Current guide index (0-based) after an advance.
  final int? currentGuideIndex;

  /// Total number of guides in the path.
  final int? totalGuides;

  const FellowshipStudyState({
    required this.fellowshipId,
    this.isMentor = false,
    this.currentLearningPathId,
    this.currentPathTitle,
    this.setStatus = FellowshipStudySetStatus.idle,
    this.setError,
    this.advanceStatus = FellowshipStudyAdvanceStatus.idle,
    this.advanceError,
    this.studyCompleted = false,
    this.currentGuideIndex,
    this.totalGuides,
  });

  factory FellowshipStudyState.initial() => const FellowshipStudyState(
        fellowshipId: '',
      );

  FellowshipStudyState copyWith({
    String? fellowshipId,
    bool? isMentor,
    String? currentLearningPathId,
    bool clearCurrentLearningPathId = false,
    String? currentPathTitle,
    bool clearCurrentPathTitle = false,
    FellowshipStudySetStatus? setStatus,
    String? setError,
    bool clearSetError = false,
    FellowshipStudyAdvanceStatus? advanceStatus,
    String? advanceError,
    bool clearAdvanceError = false,
    bool? studyCompleted,
    int? currentGuideIndex,
    int? totalGuides,
  }) {
    return FellowshipStudyState(
      fellowshipId: fellowshipId ?? this.fellowshipId,
      isMentor: isMentor ?? this.isMentor,
      currentLearningPathId: clearCurrentLearningPathId
          ? null
          : currentLearningPathId ?? this.currentLearningPathId,
      currentPathTitle: clearCurrentPathTitle
          ? null
          : currentPathTitle ?? this.currentPathTitle,
      setStatus: setStatus ?? this.setStatus,
      setError: clearSetError ? null : setError ?? this.setError,
      advanceStatus: advanceStatus ?? this.advanceStatus,
      advanceError:
          clearAdvanceError ? null : advanceError ?? this.advanceError,
      studyCompleted: studyCompleted ?? this.studyCompleted,
      currentGuideIndex: currentGuideIndex ?? this.currentGuideIndex,
      totalGuides: totalGuides ?? this.totalGuides,
    );
  }

  @override
  List<Object?> get props => [
        fellowshipId,
        isMentor,
        currentLearningPathId,
        currentPathTitle,
        setStatus,
        setError,
        advanceStatus,
        advanceError,
        studyCompleted,
        currentGuideIndex,
        totalGuides,
      ];
}
