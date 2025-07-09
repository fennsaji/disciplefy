import '../../domain/entities/recommended_guide_topic.dart';

/// Simple model to handle the actual recommended guide topics API response
class RecommendedGuideTopicResponse {
  final String id;
  final String title;
  final String description;
  final String difficultyLevel;
  final String estimatedDuration;
  final List<String> keyVerses;
  final String category;
  final List<String> tags;

  const RecommendedGuideTopicResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.difficultyLevel,
    required this.estimatedDuration,
    required this.keyVerses,
    required this.category,
    required this.tags,
  });

  /// Creates a [RecommendedGuideTopicResponse] from JSON.
  factory RecommendedGuideTopicResponse.fromJson(Map<String, dynamic> json) {
    return RecommendedGuideTopicResponse(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      difficultyLevel: json['difficulty_level'] ?? 'beginner',
      estimatedDuration: json['estimated_duration'] ?? '30 minutes',
      keyVerses: List<String>.from(json['key_verses'] ?? []),
      category: json['category'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  /// Converts this response to a domain entity.
  RecommendedGuideTopic toEntity() {
    return RecommendedGuideTopic(
      id: id,
      title: title,
      description: description,
      category: category,
      difficulty: difficultyLevel,
      estimatedMinutes: _parseDuration(estimatedDuration),
      scriptureCount: keyVerses.length,
      tags: tags,
      isFeatured: false, // This info is not in the API response
      createdAt: DateTime.now(), // This info is not in the API response
    );
  }

  /// Parses duration string like "45 minutes" to integer minutes
  int _parseDuration(String duration) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(duration);
    return int.tryParse(match?.group(1) ?? '30') ?? 30;
  }
}

/// Response model for the recommended guide topics API endpoint.
class RecommendedGuideTopicsApiResponse {
  final bool success;
  final RecommendedGuideTopicsData data;

  const RecommendedGuideTopicsApiResponse({
    required this.success,
    required this.data,
  });

  /// Creates a [RecommendedGuideTopicsApiResponse] from JSON.
  factory RecommendedGuideTopicsApiResponse.fromJson(Map<String, dynamic> json) {
    return RecommendedGuideTopicsApiResponse(
      success: json['success'] ?? false,
      data: RecommendedGuideTopicsData.fromJson(json['data'] ?? {}),
    );
  }

  /// Converts topics to domain entities.
  List<RecommendedGuideTopic> toEntities() {
    return data.topics.map((topic) => topic.toEntity()).toList();
  }
}

/// Data section of the API response
class RecommendedGuideTopicsData {
  final List<RecommendedGuideTopicResponse> topics;
  final List<String> categories;
  final int total;

  const RecommendedGuideTopicsData({
    required this.topics,
    required this.categories,
    required this.total,
  });

  /// Creates a [RecommendedGuideTopicsData] from JSON.
  factory RecommendedGuideTopicsData.fromJson(Map<String, dynamic> json) {
    final topicsJson = json['topics'] as List<dynamic>? ?? [];
    final topics = topicsJson
        .map((topicJson) => RecommendedGuideTopicResponse.fromJson(topicJson as Map<String, dynamic>))
        .toList();

    return RecommendedGuideTopicsData(
      topics: topics,
      categories: List<String>.from(json['categories'] ?? []),
      total: json['total'] ?? 0,
    );
  }
}