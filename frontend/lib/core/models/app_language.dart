/// Unified language model for the application
/// Supports English, Hindi, and Malayalam languages
enum AppLanguage {
  english('en', 'English'),
  hindi('hi', 'हिन्दी'),
  malayalam('ml', 'മലയാളം');

  const AppLanguage(this.code, this.displayName);

  /// Language code (ISO 639-1)
  final String code;

  /// Display name in the native language
  final String displayName;

  /// Get AppLanguage from language code
  static AppLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return AppLanguage.english;
      case 'hi':
        return AppLanguage.hindi;
      case 'ml':
        return AppLanguage.malayalam;
      default:
        return AppLanguage.english; // Default fallback
    }
  }

  /// Get all available languages
  static List<AppLanguage> get all => AppLanguage.values;

  @override
  String toString() => displayName;
}
