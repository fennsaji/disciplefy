import '../../domain/entities/memory_verse_entity.dart';

/// Data model for MemoryVerse with JSON serialization.
///
/// Handles conversion between JSON (API/Hive) and domain entities.
/// Follows Clean Architecture - data layer models know about entities.
class MemoryVerseModel extends MemoryVerseEntity {
  const MemoryVerseModel({
    required super.id,
    required super.verseReference,
    required super.verseText,
    required super.language,
    required super.sourceType,
    super.sourceId,
    required super.easeFactor,
    required super.intervalDays,
    required super.repetitions,
    required super.nextReviewDate,
    required super.addedDate,
    super.lastReviewed,
    required super.totalReviews,
    required super.createdAt,
  });

  /// Creates a model from domain entity
  factory MemoryVerseModel.fromEntity(MemoryVerseEntity entity) {
    return MemoryVerseModel(
      id: entity.id,
      verseReference: entity.verseReference,
      verseText: entity.verseText,
      language: entity.language,
      sourceType: entity.sourceType,
      sourceId: entity.sourceId,
      easeFactor: entity.easeFactor,
      intervalDays: entity.intervalDays,
      repetitions: entity.repetitions,
      nextReviewDate: entity.nextReviewDate,
      addedDate: entity.addedDate,
      lastReviewed: entity.lastReviewed,
      totalReviews: entity.totalReviews,
      createdAt: entity.createdAt,
    );
  }

  /// Creates a model from JSON (API response or Hive)
  factory MemoryVerseModel.fromJson(Map<String, dynamic> json) {
    return MemoryVerseModel(
      id: json['id'] as String,
      verseReference: json['verse_reference'] as String,
      verseText: json['verse_text'] as String,
      language: json['language'] as String,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String?,
      easeFactor: (json['ease_factor'] as num).toDouble(),
      intervalDays: json['interval_days'] as int,
      repetitions: json['repetitions'] as int,
      nextReviewDate: DateTime.parse(json['next_review_date'] as String),
      addedDate: DateTime.parse(json['added_date'] as String),
      lastReviewed: json['last_reviewed'] != null
          ? DateTime.parse(json['last_reviewed'] as String)
          : null,
      totalReviews: json['total_reviews'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts model to JSON (for API requests or Hive storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_reference': verseReference,
      'verse_text': verseText,
      'language': language,
      'source_type': sourceType,
      'source_id': sourceId,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'next_review_date': nextReviewDate.toIso8601String(),
      'added_date': addedDate.toIso8601String(),
      'last_reviewed': lastReviewed?.toIso8601String(),
      'total_reviews': totalReviews,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts model to entity (domain layer)
  MemoryVerseEntity toEntity() {
    return MemoryVerseEntity(
      id: id,
      verseReference: verseReference,
      verseText: verseText,
      language: language,
      sourceType: sourceType,
      sourceId: sourceId,
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      repetitions: repetitions,
      nextReviewDate: nextReviewDate,
      addedDate: addedDate,
      lastReviewed: lastReviewed,
      totalReviews: totalReviews,
      createdAt: createdAt,
    );
  }

  /// Creates a copy with updated fields
  @override
  MemoryVerseModel copyWith({
    String? id,
    String? verseReference,
    String? verseText,
    String? language,
    String? sourceType,
    String? sourceId,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? addedDate,
    DateTime? lastReviewed,
    int? totalReviews,
    DateTime? createdAt,
  }) {
    return MemoryVerseModel(
      id: id ?? this.id,
      verseReference: verseReference ?? this.verseReference,
      verseText: verseText ?? this.verseText,
      language: language ?? this.language,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      addedDate: addedDate ?? this.addedDate,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
