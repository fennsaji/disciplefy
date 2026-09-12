import '../utils/logger.dart';

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

  /// Get AppLanguage from language code.
  ///
  /// Falls back to English for anything unrecognized (a regional variant
  /// like `en-IN`, the study-content sentinel `default` leaking in, a typo).
  /// That fallback used to be silent, which is exactly what let a real bug
  /// hide: push notifications were sending the UI language where the study
  /// content language belonged, and every call site here just quietly
  /// rendered English with nothing in the logs to point at why. Logging the
  /// fallback doesn't fix a caller passing the wrong value, but it stops the
  /// next one from being invisible.
  static AppLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return AppLanguage.english;
      case 'hi':
        return AppLanguage.hindi;
      case 'ml':
        return AppLanguage.malayalam;
      default:
        Logger.warning(
            '⚠️ [AppLanguage] Unrecognized language code "$code" — defaulting to English');
        return AppLanguage.english;
    }
  }

  /// Get all available languages
  static List<AppLanguage> get all => AppLanguage.values;

  @override
  String toString() => displayName;
}
