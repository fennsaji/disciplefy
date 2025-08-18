import '../../../../core/models/app_language.dart';
import '../../presentation/pages/generate_study_screen.dart';

/// Extension to convert AppLanguage to StudyLanguage
extension AppLanguageToStudyLanguage on AppLanguage {
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
}

/// Extension to convert StudyLanguage to AppLanguage
extension StudyLanguageToAppLanguage on StudyLanguage {
  /// Convert to AppLanguage for compatibility with core services
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
