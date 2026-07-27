import 'package:flutter/material.dart';

import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';

/// Maps a reset-progress failure to a localized, user-facing message.
///
/// Both the learning-paths reset (`LearningPathsResetError`) and the
/// memory-verses reset (`MemoryProgressResetError`) carry the same shape —
/// `message`, `code`, `isNetworkError` — sourced from the same backend
/// contract (the `reset-progress` Edge Function) and the same exception
/// mapping (`mapExceptionToFailure`). Centralizing the code -> translation-key
/// mapping here keeps both screens in sync and, most importantly, keeps
/// hi/ml users from ever seeing the hardcoded English strings that the data
/// layer throws (e.g. `RateLimitException`'s message).
///
/// [fallbackMessage] (the raw failure message) is used only if the
/// translation for the resolved key is missing entirely — i.e. the
/// translation service returned the key itself instead of a translated
/// string, which only happens for a key with no entry in any language map.
String localizeResetProgressError(
  BuildContext context, {
  required String code,
  required bool isNetworkError,
  required String fallbackMessage,
}) {
  final key = isNetworkError
      ? TranslationKeys.resetProgressErrorNetwork
      : switch (code) {
          'RATE_LIMIT_EXCEEDED' =>
            TranslationKeys.resetProgressErrorRateLimited,
          'UNAUTHORIZED' => TranslationKeys.resetProgressErrorAuth,
          'AUTHENTICATION_ERROR' => TranslationKeys.resetProgressErrorAuth,
          // These three are what HttpService actually throws on a real 401
          // (see http_service.dart) — 'UNAUTHORIZED' above is only produced
          // by the datasources' own 401 branches, which HttpService
          // intercepts before they can ever fire.
          'SESSION_EXPIRED' => TranslationKeys.resetProgressErrorAuth,
          'AUTHENTICATION_REQUIRED' => TranslationKeys.resetProgressErrorAuth,
          'TOKEN_INVALID' => TranslationKeys.resetProgressErrorAuth,
          _ => TranslationKeys.resetProgressErrorGeneric,
        };

  final translated = context.tr(key);
  return translated == key ? fallbackMessage : translated;
}
