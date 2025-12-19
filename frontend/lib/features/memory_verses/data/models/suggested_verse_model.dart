import '../../domain/entities/suggested_verse_entity.dart';

/// Data model for SuggestedVerse with JSON serialization.
///
/// Handles conversion between JSON (API) and domain entities.
/// Follows Clean Architecture - data layer models know about entities.
class SuggestedVerseModel extends SuggestedVerseEntity {
  const SuggestedVerseModel({
    required super.id,
    required super.reference,
    required super.localizedReference,
    required super.verseText,
    required super.book,
    required super.chapter,
    required super.verseStart,
    super.verseEnd,
    required super.category,
    super.tags = const [],
    super.isAlreadyAdded = false,
  });

  /// Creates a model from domain entity
  factory SuggestedVerseModel.fromEntity(SuggestedVerseEntity entity) {
    return SuggestedVerseModel(
      id: entity.id,
      reference: entity.reference,
      localizedReference: entity.localizedReference,
      verseText: entity.verseText,
      book: entity.book,
      chapter: entity.chapter,
      verseStart: entity.verseStart,
      verseEnd: entity.verseEnd,
      category: entity.category,
      tags: entity.tags,
      isAlreadyAdded: entity.isAlreadyAdded,
    );
  }

  /// Creates a model from JSON (API response)
  factory SuggestedVerseModel.fromJson(Map<String, dynamic> json) {
    return SuggestedVerseModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      localizedReference: json['localized_reference'] as String,
      verseText: json['verse_text'] as String,
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verseStart: json['verse_start'] as int,
      verseEnd: json['verse_end'] as int?,
      category: SuggestedVerseCategory.fromString(json['category'] as String),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      isAlreadyAdded: json['is_already_added'] as bool? ?? false,
    );
  }

  /// Converts model to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'localized_reference': localizedReference,
      'verse_text': verseText,
      'book': book,
      'chapter': chapter,
      'verse_start': verseStart,
      'verse_end': verseEnd,
      'category': category.name,
      'tags': tags,
      'is_already_added': isAlreadyAdded,
    };
  }

  /// Converts model to entity (domain layer)
  SuggestedVerseEntity toEntity() {
    return SuggestedVerseEntity(
      id: id,
      reference: reference,
      localizedReference: localizedReference,
      verseText: verseText,
      book: book,
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
      category: category,
      tags: tags,
      isAlreadyAdded: isAlreadyAdded,
    );
  }

  /// Creates a copy with updated fields
  @override
  SuggestedVerseModel copyWith({
    String? id,
    String? reference,
    String? localizedReference,
    String? verseText,
    String? book,
    int? chapter,
    int? verseStart,
    int? verseEnd,
    SuggestedVerseCategory? category,
    List<String>? tags,
    bool? isAlreadyAdded,
  }) {
    return SuggestedVerseModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      localizedReference: localizedReference ?? this.localizedReference,
      verseText: verseText ?? this.verseText,
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verseStart: verseStart ?? this.verseStart,
      verseEnd: verseEnd ?? this.verseEnd,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isAlreadyAdded: isAlreadyAdded ?? this.isAlreadyAdded,
    );
  }
}

/// Response model for suggested verses API
class SuggestedVersesResponseModel {
  final List<SuggestedVerseModel> verses;
  final List<String> categories;
  final int total;

  const SuggestedVersesResponseModel({
    required this.verses,
    required this.categories,
    required this.total,
  });

  factory SuggestedVersesResponseModel.fromJson(Map<String, dynamic> json) {
    return SuggestedVersesResponseModel(
      verses: (json['verses'] as List<dynamic>)
          .map((e) => SuggestedVerseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      total: json['total'] as int,
    );
  }

  /// Convert to domain entity response
  SuggestedVersesResponse toEntity() {
    return SuggestedVersesResponse(
      verses: verses.map((v) => v.toEntity()).toList(),
      categories:
          categories.map((c) => SuggestedVerseCategory.fromString(c)).toList(),
      total: total,
    );
  }
}
