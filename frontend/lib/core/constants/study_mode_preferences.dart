/// Study Mode Preference Constants
///
/// Centralized constants for study mode preference values to ensure
/// consistency across the app and alignment with backend database schema.
///
/// These values map directly to database column constraints:
/// - `default_study_mode` in user_profiles (general study mode)
/// - `learning_path_study_mode` in user_preferences (learning path mode)
library;

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Special preference values used across both general and learning path modes
class StudyModePreferences {
  // ============================================================================
  // Special Preference Values
  // ============================================================================

  /// Use the recommended mode for the context (scripture → deep, topic → standard)
  /// Valid for both general and learning path modes
  static const String recommended = 'recommended';

  // ============================================================================
  // General Study Mode (default_study_mode in user_profiles)
  // ============================================================================

  /// Explicit "ask every time" value for general study mode.
  /// Users who actively choose "Ask me every time" in settings get this stored.
  /// NULL also means "ask every time" (no preference set yet).
  ///
  /// Database constraint: default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon', 'recommended', 'ask')
  static const String generalAsk = 'ask';

  /// @deprecated Use generalAsk or check isGeneralAskEveryTime() instead.
  static const String? generalAskEveryTime = null;

  // ============================================================================
  // Learning Path Study Mode (learning_path_study_mode in user_preferences)
  // ============================================================================

  /// For learning path topics: 'ask' means "ask every time"
  /// This is stored as 'ask' in the database learning_path_study_mode column
  ///
  /// Database constraint: learning_path_study_mode IN ('ask', 'recommended', 'quick', 'standard', 'deep', 'lectio', 'sermon')
  static const String learningPathDefault = 'ask';

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Check if a general mode preference means "ask every time".
  /// Covers both null (no preference set) and the explicit 'ask' value.
  static bool isGeneralAskEveryTime(String? value) {
    return value == null || value == generalAsk;
  }

  /// Check if a learning path mode preference means "ask every time"
  static bool isLearningPathAskEveryTime(String? value) {
    return value == null || value == learningPathDefault;
  }

  /// Check if a preference means "use recommended mode"
  static bool isRecommended(String? value) {
    return value == recommended;
  }

  /// Check if a preference is a specific study mode (not ask/recommended)
  static bool isSpecificMode(String? value, {required bool isLearningPath}) {
    if (value == null) return false;
    if (value == recommended) return false;
    if (value == generalAsk) return false;
    if (isLearningPath && value == learningPathDefault) return false;

    // Must be one of the actual study modes
    const validModes = ['quick', 'standard', 'deep', 'lectio', 'sermon'];
    return validModes.contains(value);
  }
}

/// The one rule for the mode a path lesson starts in, shared by the Home and
/// Topics lesson cards, the path detail page and lesson complete:
/// - lesson 1 after the first-run goal → Quick Read;
/// - otherwise the saved concrete `learning_path_study_mode` ([savedRaw]);
/// - 'recommended', 'ask', nothing or an unknown value → Standard.
///
/// Decision (2026-10-10): 'recommended' means Standard everywhere. It no
/// longer means the path's own `recommended_mode` on the path detail page,
/// which the Home summary does not even carry, so a lesson opened from Home,
/// Topics or the path page now starts in the same mode.
StudyMode pathLessonMode({
  required int? lessonNumber,
  required bool hasFirstRunGoal,
  required String? savedRaw,
}) {
  if (lessonNumber == 1 && hasFirstRunGoal) return StudyMode.quick;
  return studyModeFromString(savedRaw) ?? StudyMode.standard;
}

/// Mode for lessons 2+ of a path: the user's concrete learning-path mode, or
/// Standard when they chose 'recommended', 'ask' or nothing.
Future<StudyMode> resolveNextLessonMode() async => nextLessonModeNow();

/// [resolveNextLessonMode], read synchronously (the preference is cached on
/// the profile or the device), so a lesson card starts on the saved mode.
StudyMode nextLessonModeNow() => pathLessonMode(
      lessonNumber: null,
      hasFirstRunGoal: false,
      savedRaw: sl<LanguagePreferenceService>()
          .getLearningPathStudyModePreferenceRaw(),
    );

/// The general "Default study mode" for a new study that names no mode
/// (a notification, a tapped verse, a link): the saved concrete mode, else
/// [fallback] for 'recommended', 'ask', nothing or an unreadable preference.
StudyMode savedStudyModeOr(StudyMode fallback) {
  try {
    final raw = sl<LanguagePreferenceService>().peekStudyModePreferenceRaw();
    return studyModeFromString(raw) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

/// Mode for a `/study-guide-v2` link: the mode it names, else — for a new
/// study that names none (a notification, a tapped verse) — the saved default
/// study mode, else Standard. Path lessons always name their mode.
StudyMode studyModeForLink(String? mode, {required bool isLesson}) =>
    studyModeFromString(mode) ??
    (isLesson ? StudyMode.standard : savedStudyModeOr(StudyMode.standard));
