import 'package:equatable/equatable.dart';

/// Entity representing a recommended study guide topic from the backend API.
class RecommendedGuideTopic extends Equatable {
  /// Unique identifier for the topic
  final String id;

  /// Topic title/name
  final String title;

  /// Detailed description of the topic
  final String description;

  /// Category this topic belongs to (e.g., "Faith Foundations", "Spiritual Growth")
  final String category;

  /// English category name for consistent styling (fallback to category if null)
  final String? englishCategory;

  /// Number of related scripture passages
  final int scriptureCount;

  /// Keywords or tags associated with this topic
  final List<String> tags;

  /// Whether this topic is featured/recommended
  final bool isFeatured;

  /// When this topic was created
  final DateTime createdAt;

  // Learning path fields (optional - only present for learning path topics)
  /// ID of the learning path this topic belongs to
  final String? learningPathId;

  /// Name of the learning path
  final String? learningPathName;

  /// Position of this topic in the learning path (1-indexed)
  final int? positionInPath;

  /// Total number of topics in the learning path
  final int? totalTopicsInPath;

  const RecommendedGuideTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.englishCategory,
    this.scriptureCount = 0,
    this.tags = const <String>[],
    this.isFeatured = false,
    required this.createdAt,
    this.learningPathId,
    this.learningPathName,
    this.positionInPath,
    this.totalTopicsInPath,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        englishCategory,
        scriptureCount,
        tags,
        isFeatured,
        createdAt,
        learningPathId,
        learningPathName,
        positionInPath,
        totalTopicsInPath,
      ];

  /// Creates a copy of this topic with updated fields
  RecommendedGuideTopic copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? englishCategory,
    int? scriptureCount,
    List<String>? tags,
    bool? isFeatured,
    DateTime? createdAt,
    String? learningPathId,
    String? learningPathName,
    int? positionInPath,
    int? totalTopicsInPath,
  }) =>
      RecommendedGuideTopic(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        englishCategory: englishCategory ?? this.englishCategory,
        scriptureCount: scriptureCount ?? this.scriptureCount,
        tags: tags ?? this.tags,
        isFeatured: isFeatured ?? this.isFeatured,
        createdAt: createdAt ?? this.createdAt,
        learningPathId: learningPathId ?? this.learningPathId,
        learningPathName: learningPathName ?? this.learningPathName,
        positionInPath: positionInPath ?? this.positionInPath,
        totalTopicsInPath: totalTopicsInPath ?? this.totalTopicsInPath,
      );

  /// Get the English category name for styling purposes
  String get categoryForStyling => englishCategory ?? category;

  /// Whether this topic is from a learning path
  bool get isFromLearningPath =>
      learningPathId != null && learningPathId!.isNotEmpty;

  /// Formatted position in path (e.g., "3 of 10")
  String get formattedPositionInPath {
    if (positionInPath == null || totalTopicsInPath == null) return '';
    return '$positionInPath of $totalTopicsInPath';
  }

  @override
  String toString() =>
      'RecommendedGuideTopic(id: $id, title: $title, category: $category, englishCategory: $englishCategory, learningPathName: $learningPathName)';
}
