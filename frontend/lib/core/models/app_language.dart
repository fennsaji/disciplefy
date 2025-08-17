import '../../features/daily_verse/domain/entities/daily_verse_entity.dart';
import '../../features/study_generation/presentation/pages/generate_study_screen.dart';

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

  /// Convert to VerseLanguage for Daily Verse compatibility
  VerseLanguage toVerseLanguage() {
    switch (this) {
      case AppLanguage.english:
        return VerseLanguage.english;
      case AppLanguage.hindi:
        return VerseLanguage.hindi;
      case AppLanguage.malayalam:
        return VerseLanguage.malayalam;
    }
  }

  /// Convert to StudyLanguage for Study Generation compatibility
  StudyLanguage toStudyLanguage() {
    switch (this) {
      case AppLanguage.english:
        return StudyLanguage.english;
      case AppLanguage.hindi:
        return StudyLanguage.hindi;
      case AppLanguage.malayalam:
        return StudyLanguage.malayalam;
    }
  }

  /// Get all available languages
  static List<AppLanguage> get all => AppLanguage.values;

  @override
  String toString() => displayName;
}

/// Extension for VerseLanguage compatibility
extension VerseLanguageToAppLanguage on VerseLanguage {
  AppLanguage toAppLanguage() {
    switch (this) {
      case VerseLanguage.english:
        return AppLanguage.english;
      case VerseLanguage.hindi:
        return AppLanguage.hindi;
      case VerseLanguage.malayalam:
        return AppLanguage.malayalam;
    }
  }
}

/// Extension for StudyLanguage compatibility
extension StudyLanguageToAppLanguage on StudyLanguage {
  AppLanguage toAppLanguage() {
    switch (this) {
      case StudyLanguage.english:
        return AppLanguage.english;
      case StudyLanguage.hindi:
        return AppLanguage.hindi;
      case StudyLanguage.malayalam:
        return AppLanguage.malayalam;
    }
  }
}
