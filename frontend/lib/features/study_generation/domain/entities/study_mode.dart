import 'package:flutter/material.dart';

/// Represents the different study modes available for generating study guides.
///
/// Each mode offers a different depth and duration of study experience:
/// - [quick]: 3-minute condensed study with key insight and one reflection
/// - [standard]: 8-minute full study with all 6 sections (default)
/// - [deep]: 12-minute extended study with word studies and cross-references
/// - [lectio]: 9-minute meditative Lectio Divina format with silence timers
enum StudyMode {
  /// Quick Read mode (3 minutes)
  /// Sections: Key Insight, Key Verse, Quick Reflection
  quick,

  /// Standard Study mode (8 minutes)
  /// Sections: Summary, Interpretation, Context, Related Verses, Reflection Questions, Prayer Points
  standard,

  /// Deep Dive mode (12 minutes)
  /// Standard sections plus: Word Study, Historical Context, Cross References, Journal Prompt
  deep,

  /// Lectio Divina mode (9 minutes)
  /// 4 steps: Lectio (Read), Meditatio (Meditate), Oratio (Pray), Contemplatio (Rest)
  lectio,

  /// Sermon Outline mode (50-60 minutes)
  /// Sections: Sermon Thesis, Main Body (with timing), Altar Call, Supporting Verses
  sermon,
}

/// Extension methods for [StudyMode] to provide display information and utilities.
extension StudyModeExtension on StudyMode {
  /// Returns the display name for this study mode.
  String get displayName {
    switch (this) {
      case StudyMode.quick:
        return 'Quick Read';
      case StudyMode.standard:
        return 'Standard Study';
      case StudyMode.deep:
        return 'Deep Dive';
      case StudyMode.lectio:
        return 'Lectio Divina';
      case StudyMode.sermon:
        return 'Sermon Outline';
    }
  }

  /// Returns the estimated duration in minutes.
  int get durationMinutes {
    switch (this) {
      case StudyMode.quick:
        return 3;
      case StudyMode.standard:
        return 8;
      case StudyMode.deep:
        return 12;
      case StudyMode.lectio:
        return 9;
      case StudyMode.sermon:
        return 55; // 50-60 minute average
    }
  }

  /// Returns a formatted duration string.
  String get durationText {
    return '$durationMinutes min';
  }

  /// Returns the Material icon for this study mode.
  IconData get iconData {
    switch (this) {
      case StudyMode.quick:
        return Icons.bolt;
      case StudyMode.standard:
        return Icons.menu_book;
      case StudyMode.deep:
        return Icons.search;
      case StudyMode.lectio:
        return Icons.self_improvement;
      case StudyMode.sermon:
        return Icons.church;
    }
  }

  /// Returns the emoji icon for this study mode (for use in Text widgets).
  String get icon {
    switch (this) {
      case StudyMode.quick:
        return '⚡';
      case StudyMode.standard:
        return '📖';
      case StudyMode.deep:
        return '🔍';
      case StudyMode.lectio:
        return '🕯️';
      case StudyMode.sermon:
        return '⛪';
    }
  }

  /// Returns a brief description of this study mode.
  String get description {
    switch (this) {
      case StudyMode.quick:
        return 'Key insight + verse + 1 reflection';
      case StudyMode.standard:
        return 'Full guide with 6 sections';
      case StudyMode.deep:
        return '+ Word studies + Extended context';
      case StudyMode.lectio:
        return 'Meditative reading with silence';
      case StudyMode.sermon:
        return 'Full sermon with timing + illustrations';
    }
  }

  /// Returns whether this mode supports Reflect Mode interactive cards.
  bool get supportsReflectMode {
    switch (this) {
      case StudyMode.quick:
        return false; // Quick read has built-in simple interaction
      case StudyMode.standard:
        return true;
      case StudyMode.deep:
        return true;
      case StudyMode.lectio:
        return false; // Lectio has its own step-by-step format
      case StudyMode.sermon:
        return false; // Read-only mode for sermon outlines
    }
  }

  /// Returns the string value for API/database.
  String get value => name;
}

/// Creates a StudyMode from a string value.
///
/// Returns null for:
/// - 'recommended' sentinel (use StudyModePreferences.recommended instead)
/// - Unknown/invalid values
/// - Null input
///
/// This is a top-level function because Dart doesn't support static methods in extensions.
StudyMode? studyModeFromString(String? value) {
  if (value == null) return null;

  switch (value.toLowerCase()) {
    case 'quick':
      return StudyMode.quick;
    case 'standard':
      return StudyMode.standard;
    case 'deep':
      return StudyMode.deep;
    case 'lectio':
      return StudyMode.lectio;
    case 'sermon':
      return StudyMode.sermon;
    case 'recommended':
      // Explicitly reject 'recommended' sentinel - caller should handle this
      // using StudyModePreferences.recommended instead
      return null;
    default:
      // Unknown value - return null instead of defaulting to standard
      return null;
  }
}

/// Represents the view mode within a study guide (Read vs Reflect).
///
/// Only applicable for modes that support Reflect Mode ([StudyMode.standard] and [StudyMode.deep]).
enum StudyViewMode {
  /// Read Mode: Traditional scrollable content with all sections visible
  read,

  /// Reflect Mode: One section at a time with interactive prompts
  reflect,
}

/// Extension methods for [StudyViewMode].
extension StudyViewModeExtension on StudyViewMode {
  /// Returns the display name for this view mode.
  String get displayName {
    switch (this) {
      case StudyViewMode.read:
        return 'Read';
      case StudyViewMode.reflect:
        return 'Reflect';
    }
  }

  /// Returns the icon for this view mode.
  IconData get icon {
    switch (this) {
      case StudyViewMode.read:
        return Icons.menu_book;
      case StudyViewMode.reflect:
        return Icons.edit_note;
    }
  }
}
