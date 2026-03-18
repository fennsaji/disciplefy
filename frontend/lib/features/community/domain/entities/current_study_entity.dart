import 'package:equatable/equatable.dart';

/// Domain entity representing the current study associated with a fellowship.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [CurrentStudyModel.toEntity] and consumed by the domain and presentation
/// layers.
class CurrentStudyEntity extends Equatable {
  /// The ID of the learning path being studied.
  final String learningPathId;

  /// Display title of the learning path (e.g. "Gospel of John").
  final String? learningPathTitle;

  /// Zero-based index of the guide currently being worked through.
  final int currentGuideIndex;

  /// ISO-8601 timestamp when the fellowship started this study.
  final String startedAt;

  /// ISO-8601 timestamp when the study was completed, or null if still active.
  final String? completedAt;

  /// Total number of guides in the learning path, or null if unknown.
  final int? totalGuides;

  const CurrentStudyEntity({
    required this.learningPathId,
    this.learningPathTitle,
    required this.currentGuideIndex,
    required this.startedAt,
    this.completedAt,
    this.totalGuides,
  });

  @override
  List<Object?> get props => [
        learningPathId,
        learningPathTitle,
        currentGuideIndex,
        startedAt,
        completedAt,
        totalGuides,
      ];
}
