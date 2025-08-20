import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/recommended_guide_topic.dart';

part 'recommended_guide_topic_model.g.dart';

/// Data model for recommended guide topic API responses.
///
/// This model handles the serialization/deserialization of recommended guide topics
/// from the backend API and converts them to domain entities.
@JsonSerializable(fieldRename: FieldRename.snake)
class RecommendedGuideTopicModel extends RecommendedGuideTopic {
  @JsonKey(name: 'key_verses')
  final List<String> keyVerses;

  RecommendedGuideTopicModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required this.keyVerses,
    required super.tags,
    super.isFeatured = false, // Default to false if not provided
    DateTime? createdAt, // Allow null parameter
  }) : super(
          scriptureCount: keyVerses.length,
          createdAt: createdAt ?? DateTime.now(),
        );

  /// Creates a [RecommendedGuideTopicModel] from JSON.
  factory RecommendedGuideTopicModel.fromJson(Map<String, dynamic> json) =>
      _$RecommendedGuideTopicModelFromJson(json);

  /// Converts this model to JSON.
  Map<String, dynamic> toJson() => _$RecommendedGuideTopicModelToJson(this);

  /// Converts this model to a domain entity.
  RecommendedGuideTopic toEntity() => RecommendedGuideTopic(
        id: id,
        title: title,
        description: description,
        category: category,
        scriptureCount: scriptureCount,
        tags: tags,
        isFeatured: isFeatured,
        createdAt: createdAt,
      );

  /// Creates a model from a domain entity.
  factory RecommendedGuideTopicModel.fromEntity(RecommendedGuideTopic entity) =>
      RecommendedGuideTopicModel(
        id: entity.id,
        title: entity.title,
        description: entity.description,
        category: entity.category,
        keyVerses: List.generate(entity.scriptureCount,
            (index) => 'Verse ${index + 1}'), // Placeholder
        tags: entity.tags,
        isFeatured: entity.isFeatured,
        createdAt: entity.createdAt,
      );
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
  List<RecommendedGuideTopic> toEntities() =>
      topics.map((model) => model.toEntity()).toList();
}
