import 'package:equatable/equatable.dart';

/// A single verse with its number, used for verse ranges.
class VerseItem extends Equatable {
  final int number;
  final String text;

  const VerseItem({required this.number, required this.text});

  @override
  List<Object?> get props => [number, text];
}

/// Entity representing a fetched verse text from the API.
///
/// Contains the verse text and localized reference returned
/// from the fetch-verse endpoint. For verse ranges, [verses]
/// provides per-verse breakdown with verse numbers.
class FetchedVerseEntity extends Equatable {
  /// The actual verse text content (all verses joined)
  final String text;

  /// The localized reference (e.g., "यशायाह 26:3" for Hindi)
  final String localizedReference;

  /// Per-verse breakdown for ranges (null for single verses)
  final List<VerseItem>? verses;

  const FetchedVerseEntity({
    required this.text,
    required this.localizedReference,
    this.verses,
  });

  @override
  List<Object?> get props => [text, localizedReference, verses];
}
