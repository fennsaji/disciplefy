import 'package:equatable/equatable.dart';

/// Entity representing a fetched verse text from the API.
///
/// Contains the verse text and localized reference returned
/// from the fetch-verse endpoint.
class FetchedVerseEntity extends Equatable {
  /// The actual verse text content
  final String text;

  /// The localized reference (e.g., "यशायाह 26:3" for Hindi)
  final String localizedReference;

  const FetchedVerseEntity({
    required this.text,
    required this.localizedReference,
  });

  @override
  List<Object?> get props => [text, localizedReference];
}
