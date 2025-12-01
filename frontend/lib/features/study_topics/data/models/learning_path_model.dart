import '../../domain/entities/learning_path.dart';

/// Model for parsing learning path data from API.
class LearningPathModel extends LearningPath {
  const LearningPathModel({
    required super.id,
    required super.slug,
    required super.title,
    required super.description,
    required super.iconName,
    required super.color,
    required super.totalXp,
    required super.estimatedDays,
    required super.discipleLevel,
    super.isFeatured,
    super.topicsCount,
    super.isEnrolled,
    super.progressPercentage,
  });

  factory LearningPathModel.fromJson(Map<String, dynamic> json) {
    return LearningPathModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'school',
      color: json['color'] as String? ?? '#6A4FB6',
      totalXp: json['total_xp'] as int? ?? 0,
      estimatedDays: json['estimated_days'] as int? ?? 7,
      discipleLevel: json['disciple_level'] as String? ?? 'believer',
      isFeatured: json['is_featured'] as bool? ?? false,
      topicsCount: json['topics_count'] as int? ?? 0,
      isEnrolled: json['is_enrolled'] as bool? ?? false,
      progressPercentage: json['progress_percentage'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'color': color,
      'total_xp': totalXp,
      'estimated_days': estimatedDays,
      'disciple_level': discipleLevel,
      'is_featured': isFeatured,
      'topics_count': topicsCount,
      'is_enrolled': isEnrolled,
      'progress_percentage': progressPercentage,
    };
  }
}

/// Model for parsing learning path topic data from API.
class LearningPathTopicModel extends LearningPathTopic {
  const LearningPathTopicModel({
    required super.position,
    required super.isMilestone,
    required super.topicId,
    required super.title,
    required super.description,
    required super.category,
    required super.xpValue,
    super.isCompleted,
    super.isInProgress,
  });

  factory LearningPathTopicModel.fromJson(Map<String, dynamic> json) {
    return LearningPathTopicModel(
      position: json['position'] as int? ?? 0,
      isMilestone: json['is_milestone'] as bool? ?? false,
      topicId: json['topic_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      xpValue: json['xp_value'] as int? ?? 50,
      isCompleted: json['is_completed'] as bool? ?? false,
      isInProgress: json['is_in_progress'] as bool? ?? false,
    );
  }
}

/// Model for parsing learning path detail data from API.
class LearningPathDetailModel extends LearningPathDetail {
  const LearningPathDetailModel({
    required super.id,
    required super.slug,
    required super.title,
    required super.description,
    required super.iconName,
    required super.color,
    required super.totalXp,
    required super.estimatedDays,
    required super.discipleLevel,
    super.isFeatured,
    super.topicsCount,
    super.isEnrolled,
    super.progressPercentage,
    super.topicsCompleted,
    super.enrolledAt,
    super.topics,
  });

  factory LearningPathDetailModel.fromJson(Map<String, dynamic> json) {
    final topicsJson = json['topics'] as List<dynamic>? ?? [];
    final topics = topicsJson
        .map((t) => LearningPathTopicModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return LearningPathDetailModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'school',
      color: json['color'] as String? ?? '#6A4FB6',
      totalXp: json['total_xp'] as int? ?? 0,
      estimatedDays: json['estimated_days'] as int? ?? 7,
      discipleLevel: json['disciple_level'] as String? ?? 'believer',
      isFeatured: json['is_featured'] as bool? ?? false,
      topicsCount: topics.length,
      isEnrolled: json['is_enrolled'] as bool? ?? false,
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      topicsCompleted: json['topics_completed'] as int? ?? 0,
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.parse(json['enrolled_at'] as String)
          : null,
      topics: topics,
    );
  }
}

/// Model for parsing enrollment result from API.
class EnrollmentResultModel extends EnrollmentResult {
  const EnrollmentResultModel({
    required super.id,
    required super.learningPathId,
    required super.enrolledAt,
    required super.startedAt,
  });

  factory EnrollmentResultModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentResultModel(
      id: json['id'] as String,
      learningPathId: json['learning_path_id'] as String,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      startedAt: DateTime.parse(json['started_at'] as String),
    );
  }
}

/// Model for parsing learning paths response from API.
class LearningPathsResponseModel {
  final List<LearningPathModel> paths;
  final int total;

  const LearningPathsResponseModel({
    required this.paths,
    required this.total,
  });

  factory LearningPathsResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pathsJson = data['paths'] as List<dynamic>? ?? [];

    return LearningPathsResponseModel(
      paths: pathsJson
          .map((p) => LearningPathModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  LearningPathsResult toEntity() {
    return LearningPathsResult(
      paths: paths,
      total: total,
    );
  }
}

/// Model for parsing recommended learning path response from API.
class RecommendedPathResponseModel {
  final LearningPathModel? path;
  final String reason;

  const RecommendedPathResponseModel({
    required this.path,
    required this.reason,
  });

  factory RecommendedPathResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pathJson = data['path'] as Map<String, dynamic>?;

    return RecommendedPathResponseModel(
      path: pathJson != null ? LearningPathModel.fromJson(pathJson) : null,
      reason: data['reason'] as String? ?? 'featured',
    );
  }

  RecommendedPathResult? toEntity() {
    if (path == null) return null;
    return RecommendedPathResult(
      path: path!,
      reason: RecommendedPathResult.parseReason(reason),
    );
  }
}
