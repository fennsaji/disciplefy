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
  
  /// Difficulty level (e.g., "beginner", "intermediate", "advanced")
  final String difficulty;
  
  /// Estimated study duration in minutes
  final int estimatedMinutes;
  
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
    required this.difficulty,
    required this.estimatedMinutes,
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
        difficulty,
        estimatedMinutes,
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
    String? difficulty,
    int? estimatedMinutes,
    int? scriptureCount,
    List<String>? tags,
    bool? isFeatured,
    DateTime? createdAt,
  }) => RecommendedGuideTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      scriptureCount: scriptureCount ?? this.scriptureCount,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
    );

  @override
  String toString() => 'RecommendedGuideTopic(id: $id, title: $title, category: $category, difficulty: $difficulty)';
}