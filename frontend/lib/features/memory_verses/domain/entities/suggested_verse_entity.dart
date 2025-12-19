import 'package:equatable/equatable.dart';

/// Categories for suggested verses
enum SuggestedVerseCategory {
  salvation,
  comfort,
  strength,
  wisdom,
  promise,
  guidance,
  faith,
  love;

  /// Get category from string
  static SuggestedVerseCategory fromString(String value) {
    return SuggestedVerseCategory.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SuggestedVerseCategory.faith,
    );
  }
}

/// Entity representing a suggested Bible verse that users can add to their memory deck.
///
/// This is a curated verse from the suggested_verses table with multi-language support.
class SuggestedVerseEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// English canonical reference (e.g., "John 3:16")
  final String reference;

  /// Localized reference in user's language (e.g., "यूहन्ना 3:16" for Hindi)
  final String localizedReference;

  /// Full verse text in user's language
  final String verseText;

  /// Book name
  final String book;

  /// Chapter number
  final int chapter;

  /// Starting verse number
  final int verseStart;

  /// Ending verse number (null for single verse)
  final int? verseEnd;

  /// Category for filtering
  final SuggestedVerseCategory category;

  /// Additional tags for flexible filtering
  final List<String> tags;

  /// Whether this verse is already in the user's memory deck
  final bool isAlreadyAdded;

  const SuggestedVerseEntity({
    required this.id,
    required this.reference,
    required this.localizedReference,
    required this.verseText,
    required this.book,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
    required this.category,
    this.tags = const [],
    this.isAlreadyAdded = false,
  });

  /// Get a short preview of the verse text (first 100 chars)
  String get versePreview {
    if (verseText.length <= 100) return verseText;
    return '${verseText.substring(0, 100)}...';
  }

  /// Check if this is a verse range (e.g., John 3:16-17)
  bool get isVerseRange => verseEnd != null && verseEnd != verseStart;

  /// Get verse range string (e.g., "16" or "16-17")
  String get verseRangeString {
    if (verseEnd == null || verseEnd == verseStart) {
      return verseStart.toString();
    }
    return '$verseStart-$verseEnd';
  }

  @override
  List<Object?> get props => [
        id,
        reference,
        localizedReference,
        verseText,
        book,
        chapter,
        verseStart,
        verseEnd,
        category,
        tags,
        isAlreadyAdded,
      ];

  /// Create a copy with updated fields
  SuggestedVerseEntity copyWith({
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
    return SuggestedVerseEntity(
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

/// Response wrapper for suggested verses API
class SuggestedVersesResponse extends Equatable {
  /// List of suggested verses
  final List<SuggestedVerseEntity> verses;

  /// Available categories for filtering
  final List<SuggestedVerseCategory> categories;

  /// Total count of verses
  final int total;

  const SuggestedVersesResponse({
    required this.verses,
    required this.categories,
    required this.total,
  });

  @override
  List<Object?> get props => [verses, categories, total];
}
