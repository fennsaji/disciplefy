import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/recommended_guide_topic.dart';

part 'recommended_guide_topic_model.g.dart';

/// Data model for recommended guide topic API responses.
/// 
/// This model handles the serialization/deserialization of recommended guide topics
/// from the backend API and converts them to domain entities.
@JsonSerializable(fieldRename: FieldRename.snake)
class RecommendedGuideTopicModel extends RecommendedGuideTopic {
  @JsonKey(name: 'difficulty_level')
  final String difficultyLevel;
  
  @JsonKey(name: 'estimated_duration')
  final String estimatedDuration;
  
  @JsonKey(name: 'key_verses')
  final List<String> keyVerses;

  const RecommendedGuideTopicModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required this.difficultyLevel,
    required this.estimatedDuration,
    required this.keyVerses,
    required super.tags,
    required super.isFeatured,
    required super.createdAt,
  }) : super(
          difficulty: difficultyLevel,
          estimatedMinutes: _parseDuration(estimatedDuration),
          scriptureCount: keyVerses.length,
        );
  
  /// Parses duration string like "45 minutes" to integer minutes
  static int _parseDuration(String duration) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(duration);
    return int.tryParse(match?.group(1) ?? '30') ?? 30;
  }

  /// Creates a [RecommendedGuideTopicModel] from JSON.
  factory RecommendedGuideTopicModel.fromJson(Map<String, dynamic> json) =>
      _$RecommendedGuideTopicModelFromJson(json);

  /// Converts this model to JSON.
  Map<String, dynamic> toJson() => _$RecommendedGuideTopicModelToJson(this);

  /// Converts this model to a domain entity.
  RecommendedGuideTopic toEntity() {
    return RecommendedGuideTopic(
      id: id,
      title: title,
      description: description,
      category: category,
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
      scriptureCount: scriptureCount,
      tags: tags,
      isFeatured: isFeatured,
      createdAt: createdAt,
    );
  }

  /// Creates a model from a domain entity.
  factory RecommendedGuideTopicModel.fromEntity(RecommendedGuideTopic entity) {
    return RecommendedGuideTopicModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      category: entity.category,
      difficulty: entity.difficulty,
      estimatedMinutes: entity.estimatedMinutes,
      scriptureCount: entity.scriptureCount,
      tags: entity.tags,
      isFeatured: entity.isFeatured,
      createdAt: entity.createdAt,
    );
  }

  /// Creates a model with mock data for testing/fallback purposes.
  factory RecommendedGuideTopicModel.mock({
    String? id,
    String? title,
    String? description,
    String? category,
    String? difficulty,
  }) {
    return RecommendedGuideTopicModel(
      id: id ?? 'mock-topic-${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Sample Topic',
      description: description ?? 'This is a sample topic description for testing purposes.',
      category: category ?? 'Faith Foundations',
      difficulty: difficulty ?? 'beginner',
      estimatedMinutes: 30,
      scriptureCount: 5,
      tags: ['faith', 'foundation', 'beginner'],
      isFeatured: true,
      createdAt: DateTime.now(),
    );
  }
}

/// Response model for the recommended guide topics API endpoint.
@JsonSerializable()
class RecommendedGuideTopicsResponse {
  /// List of topics returned by the API
  final List<RecommendedGuideTopicModel> topics;
  
  /// Total number of topics available (for pagination)
  final int total;
  
  /// Current page number (if paginated)
  final int? page;
  
  /// Total number of pages (if paginated)
  final int? totalPages;

  const RecommendedGuideTopicsResponse({
    required this.topics,
    required this.total,
    this.page,
    this.totalPages,
  });

  /// Creates a [RecommendedGuideTopicsResponse] from JSON.
  factory RecommendedGuideTopicsResponse.fromJson(Map<String, dynamic> json) =>
      _$RecommendedGuideTopicsResponseFromJson(json);

  /// Converts this response to JSON.
  Map<String, dynamic> toJson() => _$RecommendedGuideTopicsResponseToJson(this);

  /// Converts topics to domain entities.
  List<RecommendedGuideTopic> toEntities() {
    return topics.map((model) => model.toEntity()).toList();
  }

  /// Creates a mock response for testing/fallback purposes.
  factory RecommendedGuideTopicsResponse.mock() {
    return RecommendedGuideTopicsResponse(
      topics: [
        RecommendedGuideTopicModel.mock(
          id: 'topic-faith',
          title: 'Understanding Faith',
          description: 'Explore the biblical foundations of faith and trust in God.',
          category: 'Faith Foundations',
          difficulty: 'beginner',
        ),
        RecommendedGuideTopicModel.mock(
          id: 'topic-prayer',
          title: 'The Power of Prayer',
          description: 'Learn how to communicate effectively with God through prayer.',
          category: 'Spiritual Disciplines',
          difficulty: 'beginner',
        ),
        RecommendedGuideTopicModel.mock(
          id: 'topic-grace',
          title: 'God\'s Amazing Grace',
          description: 'Understand the depth and breadth of God\'s unmerited favor.',
          category: 'Salvation',
          difficulty: 'intermediate',
        ),
        RecommendedGuideTopicModel.mock(
          id: 'topic-discipleship',
          title: 'Following Jesus',
          description: 'What it means to be a disciple in today\'s world.',
          category: 'Christian Living',
          difficulty: 'intermediate',
        ),
        RecommendedGuideTopicModel.mock(
          id: 'topic-love',
          title: 'God\'s Love',
          description: 'Experience and understand the depth of God\'s love for humanity.',
          category: 'Character of God',
          difficulty: 'beginner',
        ),
        RecommendedGuideTopicModel.mock(
          id: 'topic-forgiveness',
          title: 'Forgiveness and Healing',
          description: 'Learn to forgive others as God has forgiven us.',
          category: 'Relationships',
          difficulty: 'intermediate',
        ),
      ],
      total: 6,
      page: 1,
      totalPages: 1,
    );
  }
}