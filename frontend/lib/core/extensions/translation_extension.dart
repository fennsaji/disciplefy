import 'package:flutter/material.dart';

import '../di/injection_container.dart';
import '../i18n/translation_service.dart';

/// Extension on BuildContext for easy translation access
extension TranslationExtension on BuildContext {
  /// Subscribes this widget to the ambient locale so it rebuilds when the
  /// language changes.
  ///
  /// [TranslationService] is reached through the service locator, not through
  /// the widget tree, so a `tr` call on its own registers no dependency and
  /// Flutter has no reason to rebuild the widget. Translations then only
  /// refreshed where something unrelated happened to trigger a rebuild, which
  /// is why a language switch used to leave screens — and even parts of one
  /// screen — on the previous language.
  ///
  /// `LocaleService` already drives `MaterialApp.locale` off the same language
  /// stream the service listens to, so depending on the locale is enough to
  /// converge both i18n runtimes on one rebuild signal.
  ///
  /// `maybeLocaleOf` keeps this safe where there is no `Localizations`
  /// ancestor (isolated widgets, tests): no dependency, no throw.
  void _dependOnLocale() => Localizations.maybeLocaleOf(this);

  /// Get translation for a key
  ///
  /// Example:
  /// ```dart
  /// Text(context.tr('study_guide.sections.summary'))
  /// Text(context.tr('common.messages.error', {'error': 'Network error'}))
  /// ```
  String tr(String key, [Map<String, dynamic>? args]) {
    _dependOnLocale();
    return sl<TranslationService>().getTranslation(key, args);
  }

  /// Get translation list for a key
  ///
  /// Example:
  /// ```dart
  /// context.trList('generate_study.scripture_suggestions')
  /// ```
  List<String> trList(String key) {
    _dependOnLocale();
    return sl<TranslationService>().getTranslationList(key);
  }

  /// Get the current translation service instance
  TranslationService get translationService => sl<TranslationService>();
}
