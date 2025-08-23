import '../../../../core/models/app_language.dart';
import '../entities/daily_verse_entity.dart';

/// Extension to convert AppLanguage to VerseLanguage
extension AppLanguageToVerseLanguage on AppLanguage {
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
}

/// Extension to convert VerseLanguage to AppLanguage
extension VerseLanguageToAppLanguage on VerseLanguage {
  /// Convert to AppLanguage for compatibility with core services
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
