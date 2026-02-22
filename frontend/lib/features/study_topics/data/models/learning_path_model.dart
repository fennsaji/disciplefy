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
    super.recommendedMode,
    super.allowNonSequentialAccess,
    super.isFeatured,
    super.topicsCount,
    super.isEnrolled,
    super.progressPercentage,
    super.category,
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
      recommendedMode: json['recommended_mode'] as String?,
      allowNonSequentialAccess:
          json['allow_non_sequential_access'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      topicsCount: json['topics_count'] as int? ?? 0,
      isEnrolled: json['is_enrolled'] as bool? ?? false,
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      category: json['category'] as String? ?? '',
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
      'recommended_mode': recommendedMode,
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
    super.inputType,
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
      inputType: json['input_type'] as String? ?? 'topic',
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
    super.recommendedMode,
    super.allowNonSequentialAccess,
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
      recommendedMode: json['recommended_mode'] as String?,
      allowNonSequentialAccess:
          json['allow_non_sequential_access'] as bool? ?? false,
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
    final enrolledAtStr = json['enrolled_at'] as String;
    final enrolledAt = DateTime.parse(enrolledAtStr);

    return EnrollmentResultModel(
      id: json['id'] as String,
      learningPathId: json['learning_path_id'] as String,
      enrolledAt: enrolledAt,
      startedAt:
          enrolledAt, // Use enrolled_at for both since database only has enrolled_at
    );
  }
}

/// Model for parsing learning paths response from API.
class LearningPathsResponseModel {
  final List<LearningPathModel> paths;
  final int total;
  final bool hasMore;

  const LearningPathsResponseModel({
    required this.paths,
    required this.total,
    this.hasMore = false,
  });

  factory LearningPathsResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pathsJson = data['paths'] as List<dynamic>? ?? [];

    return LearningPathsResponseModel(
      paths: pathsJson
          .map((p) => LearningPathModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      hasMore: data['has_more'] as bool? ?? false,
    );
  }

  LearningPathsResult toEntity() {
    return LearningPathsResult(
      paths: paths,
      total: total,
      hasMore: hasMore,
    );
  }
}

/// Model for parsing a single category entry from the category-grouped API.
class LearningPathCategoryModel {
  final String name;
  final List<LearningPathModel> paths;
  final int totalInCategory;
  final bool hasMoreInCategory;
  final bool isCompleted;

  const LearningPathCategoryModel({
    required this.name,
    required this.paths,
    required this.totalInCategory,
    required this.hasMoreInCategory,
    this.isCompleted = false,
  });

  factory LearningPathCategoryModel.fromJson(Map<String, dynamic> json) {
    final pathsJson = json['paths'] as List<dynamic>? ?? [];
    final rawPaths = pathsJson
        .map((p) => LearningPathModel.fromJson(p as Map<String, dynamic>))
        .toList();

    // Sort: completed paths sink to the bottom within the category
    final sortedPaths = List<LearningPathModel>.from(rawPaths)
      ..sort((a, b) {
        if (a.isCompleted == b.isCompleted) return 0;
        return a.isCompleted ? 1 : -1;
      });

    return LearningPathCategoryModel(
      name: json['name'] as String? ?? '',
      paths: sortedPaths,
      totalInCategory: json['total_in_category'] as int? ?? sortedPaths.length,
      hasMoreInCategory: json['has_more_in_category'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  LearningPathCategory toEntity() {
    return LearningPathCategory(
      name: name,
      paths: paths,
      totalInCategory: totalInCategory,
      hasMoreInCategory: hasMoreInCategory,
      isCompleted: isCompleted,
      nextPathOffset: paths.length,
    );
  }
}

/// Model for parsing the category-grouped learning paths response from API.
class LearningPathCategoriesResponseModel {
  final List<LearningPathCategoryModel> categories;
  final bool hasMoreCategories;
  final int nextCategoryOffset;

  const LearningPathCategoriesResponseModel({
    required this.categories,
    this.hasMoreCategories = false,
    this.nextCategoryOffset = 0,
  });

  factory LearningPathCategoriesResponseModel.fromJson(
      Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final catsJson = data['categories'] as List<dynamic>? ?? [];
    return LearningPathCategoriesResponseModel(
      categories: catsJson
          .map((c) =>
              LearningPathCategoryModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      hasMoreCategories: data['has_more_categories'] as bool? ?? false,
      nextCategoryOffset: data['next_category_offset'] as int? ?? 0,
    );
  }

  LearningPathCategoriesResult toEntity() {
    return LearningPathCategoriesResult(
      categories: categories.map((c) => c.toEntity()).toList(),
      hasMoreCategories: hasMoreCategories,
      nextCategoryOffset: nextCategoryOffset,
    );
  }
}

/// Model for parsing the per-category paths response from API.
class LearningPathCategoryPathsResponseModel {
  final List<LearningPathModel> paths;
  final bool hasMore;
  final String category;
  final int offset;

  const LearningPathCategoryPathsResponseModel({
    required this.paths,
    required this.hasMore,
    required this.category,
    required this.offset,
  });

  factory LearningPathCategoryPathsResponseModel.fromJson(
      Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pathsJson = data['paths'] as List<dynamic>? ?? [];
    final rawPaths = pathsJson
        .map((p) => LearningPathModel.fromJson(p as Map<String, dynamic>))
        .toList();
    // Completed paths sink to the bottom
    final sortedPaths = List<LearningPathModel>.from(rawPaths)
      ..sort((a, b) {
        if (a.isCompleted == b.isCompleted) return 0;
        return a.isCompleted ? 1 : -1;
      });
    return LearningPathCategoryPathsResponseModel(
      paths: sortedPaths,
      hasMore: data['has_more'] as bool? ?? false,
      category: data['category'] as String? ?? '',
      offset: data['offset'] as int? ?? 0,
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
