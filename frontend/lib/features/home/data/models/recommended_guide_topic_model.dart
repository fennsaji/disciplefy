import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/recommended_guide_topic.dart';

part 'recommended_guide_topic_model.g.dart';

/// Data model for recommended guide topic API responses.
///
/// This model handles the serialization/deserialization of recommended guide topics
/// from the backend API and converts them to domain entities. Now supports multilingual
/// content with English fallback data for search functionality.
@JsonSerializable(fieldRename: FieldRename.snake)
class RecommendedGuideTopicModel extends RecommendedGuideTopic {
  @JsonKey(name: 'key_verses')
  final List<String> keyVerses;

  /// English fallback fields for search functionality (null for English language responses)
  @JsonKey(name: 'english_title')
  final String? englishTitle;

  @JsonKey(name: 'english_description')
  final String? englishDescription;

  @override
  @JsonKey(name: 'english_category')
  final String? englishCategory;

  RecommendedGuideTopicModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required this.keyVerses,
    required super.tags,
    this.englishTitle,
    this.englishDescription,
    this.englishCategory,
    super.isFeatured = false, // Default to false if not provided
    DateTime? createdAt, // Allow null parameter
  }) : super(
          englishCategory: englishCategory,
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
        englishCategory: englishCategory,
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

  /// Gets the English content for searching, falling back to current content
  String get searchableTitle => englishTitle ?? title;
  String get searchableDescription => englishDescription ?? description;
  String get searchableCategory => englishCategory ?? category;

  /// Checks if this topic matches a search query using both translated and English content
  bool matchesSearchQuery(String query) {
    if (query.trim().isEmpty) return true;

    final lowerQuery = query.toLowerCase();

    // Search in translated content
    if (title.toLowerCase().contains(lowerQuery) ||
        description.toLowerCase().contains(lowerQuery) ||
        category.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Search in English fallback content if available
    if (englishTitle?.toLowerCase().contains(lowerQuery) == true ||
        englishDescription?.toLowerCase().contains(lowerQuery) == true ||
        englishCategory?.toLowerCase().contains(lowerQuery) == true) {
      return true;
    }

    // Search in tags
    return tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
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
  List<RecommendedGuideTopic> toEntities() =>
      topics.map((model) => model.toEntity()).toList();
}
