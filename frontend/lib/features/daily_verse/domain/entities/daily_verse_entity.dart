import 'package:equatable/equatable.dart';

/// Domain entity for daily Bible verse
class DailyVerseEntity extends Equatable {
  final String reference;
  final DailyVerseTranslations translations;
  final DateTime date;

  const DailyVerseEntity({
    required this.reference,
    required this.translations,
    required this.date,
  });

  /// Get the verse text for a specific language
  String getVerseText(VerseLanguage language) {
    switch (language) {
      case VerseLanguage.english:
        return translations.esv;
      case VerseLanguage.hindi:
        return translations.hindi;
      case VerseLanguage.malayalam:
        return translations.malayalam;
    }
  }

  /// Get language name for display
  String getLanguageName(VerseLanguage language) {
    switch (language) {
      case VerseLanguage.english:
        return 'English';
      case VerseLanguage.hindi:
        return 'हिन्दी';
      case VerseLanguage.malayalam:
        return 'മലയാളം';
    }
  }

  /// Check if verse is for today
  bool get isToday {
    final today = DateTime.now();
    return date.year == today.year &&
           date.month == today.month &&
           date.day == today.day;
  }

  /// Get formatted date string
  String get formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  List<Object?> get props => [reference, translations, date];
}

/// Available verse translations
class DailyVerseTranslations extends Equatable {
  final String esv;      // English Standard Version
  final String hindi;    // Hindi translation
  final String malayalam; // Malayalam translation

  const DailyVerseTranslations({
    required this.esv,
    required this.hindi,
    required this.malayalam,
  });

  @override
  List<Object?> get props => [esv, hindi, malayalam];
}

/// Supported verse languages
enum VerseLanguage {
  english,
  hindi,
  malayalam,
}

/// Extension for language utilities
extension VerseLanguageExtension on VerseLanguage {
  /// Get language code
  String get code {
    switch (this) {
      case VerseLanguage.english:
        return 'en';
      case VerseLanguage.hindi:
        return 'hi';
      case VerseLanguage.malayalam:
        return 'ml';
    }
  }

  /// Get language display name
  String get displayName {
    switch (this) {
      case VerseLanguage.english:
        return 'English';
      case VerseLanguage.hindi:
        return 'हिन्दी';
      case VerseLanguage.malayalam:
        return 'മലയാളം';
    }
  }

  /// Get language flag emoji
  String get flag {
    switch (this) {
      case VerseLanguage.english:
        return '🇺🇸';
      case VerseLanguage.hindi:
        return '🇮🇳';
      case VerseLanguage.malayalam:
        return '🇮🇳';
    }
  }
}