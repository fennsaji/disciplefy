/// Study Mode Preference Constants
///
/// Centralized constants for study mode preference values to ensure
/// consistency across the app and alignment with backend database schema.
///
/// These values map directly to database column constraints:
/// - `default_study_mode` in user_profiles (general study mode)
/// - `learning_path_study_mode` in user_preferences (learning path mode)
library;

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

  /// For general study guides: null means "ask every time"
  /// This is stored as NULL in the database default_study_mode column
  ///
  /// Database constraint: default_study_mode IS NULL OR IN ('quick', 'standard', 'deep', 'lectio', 'sermon', 'recommended')
  static const String? generalAskEveryTime = null;

  // ============================================================================
  // Learning Path Study Mode (learning_path_study_mode in user_preferences)
  // ============================================================================

  /// For learning path topics: 'ask' means "ask every time"
  /// This is stored as 'ask' in the database learning_path_study_mode column
  ///
  /// Database constraint: learning_path_study_mode IN ('ask', 'recommended', 'quick', 'standard', 'deep', 'lectio', 'sermon')
  static const String learningPathDefault = 'recommended';

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Check if a general mode preference means "ask every time"
  static bool isGeneralAskEveryTime(String? value) {
    return value == null;
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
    if (isLearningPath && value == learningPathDefault) return false;

    // Must be one of the actual study modes
    const validModes = ['quick', 'standard', 'deep', 'lectio', 'sermon'];
    return validModes.contains(value);
  }
}
