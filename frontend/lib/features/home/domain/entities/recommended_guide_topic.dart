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

  /// Number of related scripture passages
  final int scriptureCount;

  /// Keywords or tags associated with this topic
  final List<String> tags;

  /// Whether this topic is featured/recommended
  final bool isFeatured;

  /// When this topic was created
  final DateTime createdAt;

  const RecommendedGuideTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.scriptureCount,
    required this.tags,
    required this.isFeatured,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        scriptureCount,
        tags,
        isFeatured,
        createdAt,
      ];

  /// Creates a copy of this topic with updated fields
  RecommendedGuideTopic copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? scriptureCount,
    List<String>? tags,
    bool? isFeatured,
    DateTime? createdAt,
  }) =>
      RecommendedGuideTopic(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        scriptureCount: scriptureCount ?? this.scriptureCount,
        tags: tags ?? this.tags,
        isFeatured: isFeatured ?? this.isFeatured,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  String toString() =>
      'RecommendedGuideTopic(id: $id, title: $title, category: $category)';
}
