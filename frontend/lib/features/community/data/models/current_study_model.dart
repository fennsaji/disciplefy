import '../../domain/entities/current_study_entity.dart';

/// Data model for the current study associated with a fellowship.
///
/// Parsed from the `current_study` nested object in a fellowship API response.
class CurrentStudyModel {
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

  const CurrentStudyModel({
    required this.learningPathId,
    this.learningPathTitle,
    required this.currentGuideIndex,
    required this.startedAt,
    this.completedAt,
  });

  /// Creates a [CurrentStudyModel] from a JSON map (API response).
  factory CurrentStudyModel.fromJson(Map<String, dynamic> json) {
    return CurrentStudyModel(
      learningPathId: json['learning_path_id'] as String,
      learningPathTitle: json['learning_path_title'] as String?,
      currentGuideIndex: (json['current_guide_index'] as num).toInt(),
      startedAt: json['started_at'] as String,
      completedAt: json['completed_at'] as String?,
    );
  }

  /// Converts this model to a [CurrentStudyEntity] for use in the domain layer.
  CurrentStudyEntity toEntity() => CurrentStudyEntity(
        learningPathId: learningPathId,
        learningPathTitle: learningPathTitle,
        currentGuideIndex: currentGuideIndex,
        startedAt: startedAt,
        completedAt: completedAt,
      );
}
