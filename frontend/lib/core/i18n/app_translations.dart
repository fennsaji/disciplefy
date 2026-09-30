import 'dart:async';

import '../models/app_language.dart';
import 'translations_en.dart';
import 'translations_hi.dart' deferred as hindi;
import 'translations_ml.dart' deferred as malayalam;

/// Translation maps for all supported languages.
///
/// English is always available. Hindi and Malayalam are deferred imports so
/// web builds put them in separate chunks that download only when that
/// language is used. Call [ensureLoaded] before switching to a language; until
/// then [translations] has no entry for it and lookups fall back to English.
/// On mobile/desktop deferred loading completes immediately.
class AppTranslations {
  AppTranslations._();

  static final Map<AppLanguage, Map<String, dynamic>> _loaded = {
    AppLanguage.english: englishTranslations,
  };

  static final Map<AppLanguage, Future<void>> _pending = {};

  /// Loaded translation maps, keyed by language.
  static Map<AppLanguage, Map<String, dynamic>> get translations =>
      Map.unmodifiable(_loaded);

  /// Whether [language]'s map is available synchronously.
  static bool isLoaded(AppLanguage language) => _loaded.containsKey(language);

  /// Loads [language]'s translations (no-op when already loaded). Concurrent
  /// calls share one load; a failed load can be retried.
  static Future<void> ensureLoaded(AppLanguage language) {
    if (_loaded.containsKey(language)) return Future.value();
    return _pending[language] ??= _load(language).whenComplete(() {
      _pending.remove(language);
    });
  }

  /// Loads every language (tests and tools that iterate all maps).
  static Future<void> ensureAllLoaded() =>
      Future.wait(AppLanguage.values.map(ensureLoaded));

  static Future<void> _load(AppLanguage language) async {
    switch (language) {
      case AppLanguage.english:
        return;
      case AppLanguage.hindi:
        await hindi.loadLibrary();
        _loaded[language] = hindi.hindiTranslations;
      case AppLanguage.malayalam:
        await malayalam.loadLibrary();
        _loaded[language] = malayalam.malayalamTranslations;
    }
  }
}
