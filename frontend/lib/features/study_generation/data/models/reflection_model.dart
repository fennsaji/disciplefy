import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';

/// Model for serializing/deserializing reflection data from the API.
///
/// This model handles the conversion between the API's JSONB format
/// and the domain [ReflectionSession] entity.
class ReflectionModel {
  final String? id;
  final String userId;
  final String studyGuideId;
  final String studyMode;
  final Map<String, dynamic> responses;
  final int timeSpentSeconds;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReflectionModel({
    this.id,
    required this.userId,
    required this.studyGuideId,
    required this.studyMode,
    required this.responses,
    this.timeSpentSeconds = 0,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a model from JSON response.
  factory ReflectionModel.fromJson(Map<String, dynamic> json) {
    return ReflectionModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      studyGuideId: json['study_guide_id'] as String,
      studyMode: json['study_mode'] as String,
      responses: Map<String, dynamic>.from(json['responses'] as Map? ?? {}),
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts model to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'study_guide_id': studyGuideId,
      'study_mode': studyMode,
      'responses': responses,
      'time_spent_seconds': timeSpentSeconds,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts model to request body for saving.
  Map<String, dynamic> toSaveRequest() {
    return {
      'study_guide_id': studyGuideId,
      'study_mode': studyMode,
      'responses': responses,
      'time_spent_seconds': timeSpentSeconds,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  /// Converts to domain entity.
  ReflectionSession toEntity() {
    return ReflectionSession(
      id: id,
      studyGuideId: studyGuideId,
      studyMode: studyModeFromString(studyMode) ?? StudyMode.standard,
      responses: _parseResponses(),
      timeSpentSeconds: timeSpentSeconds,
      completedAt: completedAt,
      createdAt: createdAt,
    );
  }

  /// Creates a model from domain entity.
  factory ReflectionModel.fromEntity(ReflectionSession session, String userId) {
    final now = DateTime.now();
    return ReflectionModel(
      id: session.id,
      userId: userId,
      studyGuideId: session.studyGuideId,
      studyMode: session.studyMode.value,
      responses: session.toResponsesJson(),
      timeSpentSeconds: session.timeSpentSeconds,
      completedAt: session.completedAt,
      createdAt: session.createdAt,
      updatedAt: now,
    );
  }

  /// Parses the JSONB responses into domain entities.
  List<ReflectionResponse> _parseResponses() {
    final List<ReflectionResponse> result = [];
    int index = 0;

    // Parse summary theme
    if (responses.containsKey('summary_theme')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.tapSelection,
        cardIndex: index++,
        sectionTitle: 'Summary',
        value: responses['summary_theme'],
        respondedAt: completedAt,
      ));
    }

    // Parse interpretation relevance
    if (responses.containsKey('interpretation_relevance')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.slider,
        cardIndex: index++,
        sectionTitle: 'Interpretation',
        value: (responses['interpretation_relevance'] as num?)?.toDouble(),
        respondedAt: completedAt,
      ));
    }

    // Parse context related
    if (responses.containsKey('context_related')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.yesNo,
        cardIndex: index++,
        sectionTitle: 'Context',
        value: responses['context_related'],
        additionalText: responses['context_note'] as String?,
        respondedAt: completedAt,
      ));
    }

    // Parse saved verses
    if (responses.containsKey('saved_verses')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.verseSelection,
        cardIndex: index++,
        sectionTitle: 'Related Verses',
        value: List<String>.from(responses['saved_verses'] as List? ?? []),
        respondedAt: completedAt,
      ));
    }

    // Parse life areas
    if (responses.containsKey('life_areas')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.multiSelect,
        cardIndex: index++,
        sectionTitle: 'Reflection',
        value: List<String>.from(responses['life_areas'] as List? ?? []),
        respondedAt: completedAt,
      ));
    }

    // Parse prayer
    if (responses.containsKey('prayer_mode')) {
      result.add(ReflectionResponse(
        interactionType: ReflectionInteractionType.prayer,
        cardIndex: index++,
        sectionTitle: 'Prayer',
        value: {
          'mode': responses['prayer_mode'],
          'duration': responses['prayer_duration_seconds'],
        },
        respondedAt: completedAt,
      ));
    }

    return result;
  }
}

/// Statistics model for reflection analytics.
class ReflectionStatsModel {
  final int totalReflections;
  final int totalTimeSpentSeconds;
  final Map<String, int> reflectionsByMode;
  final List<String> mostCommonLifeAreas;

  const ReflectionStatsModel({
    required this.totalReflections,
    required this.totalTimeSpentSeconds,
    required this.reflectionsByMode,
    required this.mostCommonLifeAreas,
  });

  factory ReflectionStatsModel.fromJson(Map<String, dynamic> json) {
    return ReflectionStatsModel(
      totalReflections: json['total_reflections'] as int? ?? 0,
      totalTimeSpentSeconds: json['total_time_spent_seconds'] as int? ?? 0,
      reflectionsByMode:
          Map<String, int>.from(json['reflections_by_mode'] as Map? ?? {}),
      mostCommonLifeAreas:
          List<String>.from(json['most_common_life_areas'] as List? ?? []),
    );
  }

  /// Total time formatted as hours and minutes.
  String get formattedTotalTime {
    final hours = totalTimeSpentSeconds ~/ 3600;
    final minutes = (totalTimeSpentSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Paginated list response model.
class ReflectionListModel {
  final List<ReflectionModel> reflections;
  final int total;
  final int page;
  final int perPage;
  final bool hasMore;

  const ReflectionListModel({
    required this.reflections,
    required this.total,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });

  factory ReflectionListModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final pagination = data['pagination'] as Map<String, dynamic>?;

    final reflectionsList = data['reflections'] as List? ?? [];

    return ReflectionListModel(
      reflections: reflectionsList
          .map((e) => ReflectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination?['total'] as int? ?? reflectionsList.length,
      page: pagination?['page'] as int? ?? 1,
      perPage: pagination?['per_page'] as int? ?? 20,
      hasMore: pagination?['has_more'] as bool? ?? false,
    );
  }

  /// Converts to domain entities.
  List<ReflectionSession> toEntities() {
    return reflections.map((m) => m.toEntity()).toList();
  }
}
