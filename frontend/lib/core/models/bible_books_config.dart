/// Configuration model for Bible book names loaded from the remote API.
///
/// This is the data shape returned by the `get-bible-books` Edge Function
/// and stored in SharedPreferences cache.
class BibleBooksConfig {
  final List<String> english;
  final List<String> hindi;
  final List<String> malayalam;
  final List<String> englishAbbreviations;
  final List<String> hindiAlternates;
  final List<String> malayalamAlternates;
  final int version;

  const BibleBooksConfig({
    required this.english,
    required this.hindi,
    required this.malayalam,
    required this.englishAbbreviations,
    required this.hindiAlternates,
    required this.malayalamAlternates,
    required this.version,
  });

  factory BibleBooksConfig.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value == null) return [];
      return (value as List<dynamic>).cast<String>();
    }

    return BibleBooksConfig(
      english: toStringList(json['english']),
      hindi: toStringList(json['hindi']),
      malayalam: toStringList(json['malayalam']),
      englishAbbreviations: toStringList(json['englishAbbreviations']),
      hindiAlternates: toStringList(json['hindiAlternates']),
      malayalamAlternates: toStringList(json['malayalamAlternates']),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'english': english,
        'hindi': hindi,
        'malayalam': malayalam,
        'englishAbbreviations': englishAbbreviations,
        'hindiAlternates': hindiAlternates,
        'malayalamAlternates': malayalamAlternates,
        'version': version,
      };
}
