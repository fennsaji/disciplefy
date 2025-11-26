import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../services/language_preference_service.dart';
import 'app_translations.dart';

/// Service for managing translations throughout the app
class TranslationService {
  final LanguagePreferenceService _languagePreferenceService;
  final SharedPreferences _prefs;

  AppLanguage _currentLanguage = AppLanguage.english;
  final _languageChangeController = StreamController<AppLanguage>.broadcast();

  TranslationService(this._languagePreferenceService, this._prefs) {
    _initialize();
  }

  /// Stream of language changes
  Stream<AppLanguage> get languageChanges => _languageChangeController.stream;

  /// Current selected language
  AppLanguage get currentLanguage => _currentLanguage;

  void _initialize() {
    // Load initial language synchronously from SharedPreferences
    _loadInitialLanguageSync();

    // Listen to language preference changes
    _languagePreferenceService.languageChanges.listen((language) {
      if (language != _currentLanguage) {
        _currentLanguage = language;
        _languageChangeController.add(_currentLanguage);
      }
    });

    // Also load from service asynchronously to ensure we have the latest from DB
    _loadInitialLanguage();
  }

  void _loadInitialLanguageSync() {
    // Synchronously load from SharedPreferences for immediate availability
    final languageCode = _prefs.getString('user_language_preference');
    if (languageCode != null) {
      _currentLanguage = AppLanguage.fromCode(languageCode);
    }
  }

  Future<void> _loadInitialLanguage() async {
    final language = await _languagePreferenceService.getSelectedLanguage();
    if (language != _currentLanguage) {
      _currentLanguage = language;
      _languageChangeController.add(_currentLanguage);
    }
  }

  /// Get translation for a key with optional arguments
  ///
  /// Example:
  /// ```dart
  /// translationService.getTranslation('study_guide.sections.summary')
  /// translationService.getTranslation('common.messages.error', {'error': 'Network error'})
  /// ```
  String getTranslation(String key, [Map<String, dynamic>? args]) {
    final languageTranslations = AppTranslations.translations[_currentLanguage];

    if (languageTranslations == null) {
      return _getEnglishFallback(key, args);
    }

    final keys = key.split('.');
    dynamic value = languageTranslations;

    // Navigate through nested map
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        // Key not found, use English fallback
        return _getEnglishFallback(key, args);
      }
    }

    if (value is String) {
      return _interpolate(value, args);
    }

    // If final value is not a string, return the key itself
    return key;
  }

  /// Get translation list for a key
  ///
  /// Example:
  /// ```dart
  /// translationService.getTranslationList('generate_study.scripture_suggestions')
  /// ```
  List<String> getTranslationList(String key) {
    final languageTranslations = AppTranslations.translations[_currentLanguage];

    if (languageTranslations == null) {
      return _getEnglishFallbackList(key);
    }

    final keys = key.split('.');
    dynamic value = languageTranslations;

    // Navigate through nested map
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        // Key not found, use English fallback
        return _getEnglishFallbackList(key);
      }
    }

    if (value is List) {
      return value.cast<String>();
    }

    // If final value is not a list, return empty list
    return [];
  }

  /// Get English translation list as fallback
  List<String> _getEnglishFallbackList(String key) {
    final englishTranslations =
        AppTranslations.translations[AppLanguage.english];

    if (englishTranslations == null) return [];

    final keys = key.split('.');
    dynamic value = englishTranslations;

    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return []; // Return empty list if not found even in English
      }
    }

    if (value is List) {
      return value.cast<String>();
    }

    return [];
  }

  /// Get English translation as fallback
  String _getEnglishFallback(String key, [Map<String, dynamic>? args]) {
    final englishTranslations =
        AppTranslations.translations[AppLanguage.english];

    if (englishTranslations == null) return key;

    final keys = key.split('.');
    dynamic value = englishTranslations;

    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return key if not found even in English
      }
    }

    if (value is String) {
      return _interpolate(value, args);
    }

    return key;
  }

  /// Interpolate arguments into translation string
  ///
  /// Example: "Hello {name}" with args {'name': 'John'} → "Hello John"
  String _interpolate(String text, Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return text;

    String result = text;
    args.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });

    return result;
  }

  void dispose() {
    _languageChangeController.close();
  }
}
