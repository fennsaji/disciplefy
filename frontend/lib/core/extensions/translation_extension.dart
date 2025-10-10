import 'package:flutter/material.dart';

import '../di/injection_container.dart';
import '../i18n/translation_service.dart';

/// Extension on BuildContext for easy translation access
extension TranslationExtension on BuildContext {
  /// Get translation for a key
  ///
  /// Example:
  /// ```dart
  /// Text(context.tr('study_guide.sections.summary'))
  /// Text(context.tr('common.messages.error', {'error': 'Network error'}))
  /// ```
  String tr(String key, [Map<String, dynamic>? args]) {
    return sl<TranslationService>().getTranslation(key, args);
  }

  /// Get the current translation service instance
  TranslationService get translationService => sl<TranslationService>();
}
