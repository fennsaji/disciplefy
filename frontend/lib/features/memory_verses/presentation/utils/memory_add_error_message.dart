import '../../../../core/i18n/translation_keys.dart';

/// Returns the translation key for a user-facing message explaining why
/// adding a memory verse failed, or `null` when the error code is not a
/// known add-verse outcome (callers then fall back to their generic message).
String? memoryAddErrorKey(String? code) {
  if (code == null) return null;
  if (code == 'VERSE_ALREADY_EXISTS') {
    return TranslationKeys.memoryAddFeedbackAlreadyExists;
  }
  if (code == 'OFFLINE_QUEUED') return TranslationKeys.memoryAddFeedbackQueued;
  // 403 responses from add-memory-verse-* carry a plan/limit code
  // (FORBIDDEN by default, or a specific *_LIMIT_* / subscription code).
  final isRateLimit = code == 'RATE_LIMIT_EXCEEDED';
  if (!isRateLimit &&
      (code == 'FORBIDDEN' ||
          code.contains('LIMIT') ||
          code.contains('SUBSCRIPTION') ||
          code.contains('UPGRADE'))) {
    return TranslationKeys.memoryAddFeedbackLimitReached;
  }
  return null;
}
