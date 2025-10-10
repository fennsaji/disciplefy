import 'package:flutter/material.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';

/// Mock translation provider for tests
/// Provides translations without requiring full DI setup
class MockTranslationProvider extends InheritedWidget {
  final Map<String, dynamic> translations;

  MockTranslationProvider({
    super.key,
    required super.child,
    Map<String, dynamic>? translations,
  }) : translations = translations ?? _getDefaultTranslations();

  static Map<String, dynamic> _getDefaultTranslations() {
    // Extract English translations from the AppTranslations map
    final englishTranslations =
        AppTranslations.translations[AppLanguage.english];
    if (englishTranslations == null) {
      return <String, dynamic>{};
    }
    // Wrap in a 'en' key to match the structure expected by the translation extension
    return {'en': englishTranslations};
  }

  static MockTranslationProvider? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MockTranslationProvider>();
  }

  @override
  bool updateShouldNotify(MockTranslationProvider oldWidget) {
    return translations != oldWidget.translations;
  }
}

/// Extension to provide translation access in tests
extension MockTranslationExtension on BuildContext {
  String mockTr(String key, [Map<String, dynamic>? args]) {
    final provider = MockTranslationProvider.of(this);
    if (provider == null) {
      return key; // Fallback to key if no provider
    }

    // Navigate through nested map using dot notation
    final keys = key.split('.');
    dynamic value = provider.translations['en']; // Use English for tests

    for (final k in keys) {
      if (value is Map<String, dynamic>) {
        value = value[k];
      } else {
        return key; // Return key if path not found
      }
    }

    if (value is String) {
      // Simple placeholder replacement if args provided
      if (args != null) {
        String result = value;
        args.forEach((key, val) {
          result = result.replaceAll('{$key}', val.toString());
        });
        return result;
      }
      return value;
    }

    return key; // Fallback
  }
}
