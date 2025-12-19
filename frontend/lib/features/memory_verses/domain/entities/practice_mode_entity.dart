import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Enum representing available practice modes for memory verse review.
///
/// Each mode provides a different approach to verse memorization:
/// - **flipCard**: Traditional flip card (front/back)
/// - **wordBank**: Tap words in correct order from a shuffled word bank
/// - **cloze**: Fill in missing words (cloze deletion)
/// - **firstLetter**: First letter hints for each word
/// - **progressive**: Progressive reveal (word by word/phrase by phrase)
/// - **wordScramble**: Drag and drop PHRASES to correct order (higher-level structure)
/// - **audio**: Listen and repeat with TTS integration
/// - **typeItOut**: Type the entire verse from memory (romanized for Hindi/Malayalam)
enum PracticeModeType {
  flipCard,
  wordBank,
  cloze,
  firstLetter,
  progressive,
  wordScramble,
  audio,
  typeItOut,
}

/// Extension to convert PracticeModeType to string and vice versa.
extension PracticeModeTypeExtension on PracticeModeType {
  /// Converts enum to string format matching database column
  String toJson() {
    switch (this) {
      case PracticeModeType.flipCard:
        return 'flip_card';
      case PracticeModeType.wordBank:
        return 'word_bank';
      case PracticeModeType.cloze:
        return 'cloze';
      case PracticeModeType.firstLetter:
        return 'first_letter';
      case PracticeModeType.progressive:
        return 'progressive';
      case PracticeModeType.wordScramble:
        return 'word_scramble';
      case PracticeModeType.audio:
        return 'audio';
      case PracticeModeType.typeItOut:
        return 'type_it_out';
    }
  }

  /// Parses string from database to enum
  static PracticeModeType fromJson(String value) {
    switch (value) {
      case 'flip_card':
        return PracticeModeType.flipCard;
      case 'word_bank':
        return PracticeModeType.wordBank;
      case 'cloze':
        return PracticeModeType.cloze;
      case 'first_letter':
        return PracticeModeType.firstLetter;
      case 'progressive':
        return PracticeModeType.progressive;
      case 'word_scramble':
        return PracticeModeType.wordScramble;
      case 'audio':
        return PracticeModeType.audio;
      case 'type_it_out':
        return PracticeModeType.typeItOut;
      default:
        return PracticeModeType.flipCard;
    }
  }
}

/// Difficulty level for practice modes
enum Difficulty {
  easy,
  medium,
  hard,
}

/// Constants for practice mode progression system
class PracticeModeProgression {
  PracticeModeProgression._();

  /// Threshold accuracy to be considered "proficient" and unlock next mode
  static const double proficiencyThreshold = 70.0;

  /// Threshold accuracy to be considered "mastered"
  static const double masteryThreshold = 80.0;

  /// Minimum practices required for mastery status
  static const int masteryMinPractices = 5;

  /// Ordered progression from easiest to hardest.
  /// Users should achieve proficiency in each mode before moving to the next.
  ///
  /// Progression logic:
  /// 1. Flip Card - Passive recognition (see reference, recall verse)
  /// 2. Progressive Reveal - Guided recall (words appear one by one)
  /// 3. First Letter Hints - Minimal scaffolding (just first letters)
  /// 4. Word Bank - Recognition + ordering (tap words in sequence)
  /// 5. Cloze - Partial recall (fill missing words)
  /// 6. Word Scramble - Structure recognition (arrange phrase chunks)
  /// 7. Audio - Auditory + verbal (listen and speak)
  /// 8. Type It Out - Full recall (type entire verse from memory)
  static const List<PracticeModeType> progressionOrder = [
    PracticeModeType.flipCard,
    PracticeModeType.progressive,
    PracticeModeType.firstLetter,
    PracticeModeType.wordBank,
    PracticeModeType.cloze,
    PracticeModeType.wordScramble,
    PracticeModeType.audio,
    PracticeModeType.typeItOut,
  ];

  /// Get the progression index for a mode (0-7)
  static int getProgressionIndex(PracticeModeType modeType) {
    return progressionOrder.indexOf(modeType);
  }

  /// Get the next mode in progression, or null if at the end
  static PracticeModeType? getNextMode(PracticeModeType currentMode) {
    final index = getProgressionIndex(currentMode);
    if (index < 0 || index >= progressionOrder.length - 1) {
      return null;
    }
    return progressionOrder[index + 1];
  }

  /// Get the previous mode in progression, or null if at the start
  static PracticeModeType? getPreviousMode(PracticeModeType currentMode) {
    final index = getProgressionIndex(currentMode);
    if (index <= 0) {
      return null;
    }
    return progressionOrder[index - 1];
  }
}

/// Domain entity representing a specific practice mode's performance for a memory verse.
///
/// Tracks performance metrics per mode to help users understand which practice
/// methods work best for their learning style and to provide mode-specific
/// recommendations.
class PracticeModeEntity extends Equatable {
  /// The type of practice mode (typing, cloze, etc.)
  final PracticeModeType modeType;

  /// Number of times this mode has been practiced for this verse
  final int timesPracticed;

  /// Success rate percentage (0.0 - 100.0)
  final double successRate;

  /// Average time in seconds to complete practice in this mode
  /// Null if no practices completed yet
  final int? averageTimeSeconds;

  /// Whether user has marked this mode as favorite
  final bool isFavorite;

  const PracticeModeEntity({
    required this.modeType,
    required this.timesPracticed,
    required this.successRate,
    this.averageTimeSeconds,
    required this.isFavorite,
  });

  /// Returns user-friendly display name for the practice mode
  String get displayName {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return 'Flip Card';
      case PracticeModeType.wordBank:
        return 'Word Bank';
      case PracticeModeType.cloze:
        return 'Fill in the Blanks';
      case PracticeModeType.firstLetter:
        return 'First Letter Hints';
      case PracticeModeType.progressive:
        return 'Progressive Reveal';
      case PracticeModeType.wordScramble:
        return 'Phrase Scramble';
      case PracticeModeType.audio:
        return 'Audio Practice';
      case PracticeModeType.typeItOut:
        return 'Type It Out';
    }
  }

  /// Returns appropriate icon for the practice mode
  IconData get icon {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return Icons.flip;
      case PracticeModeType.wordBank:
        return Icons.touch_app;
      case PracticeModeType.cloze:
        return Icons.article_outlined;
      case PracticeModeType.firstLetter:
        return Icons.format_size;
      case PracticeModeType.progressive:
        return Icons.visibility_outlined;
      case PracticeModeType.wordScramble:
        return Icons.shuffle;
      case PracticeModeType.audio:
        return Icons.headphones;
      case PracticeModeType.typeItOut:
        return Icons.keyboard;
    }
  }

  /// Returns brief description of how the mode works
  String get description {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return 'Traditional flip card - see reference, recall verse';
      case PracticeModeType.wordBank:
        return 'Tap words in the correct order to build the verse';
      case PracticeModeType.cloze:
        return 'Fill in missing words in the verse text';
      case PracticeModeType.firstLetter:
        return 'First letter of each word shown as hints';
      case PracticeModeType.progressive:
        return 'Reveal verse progressively word by word';
      case PracticeModeType.wordScramble:
        return 'Arrange phrase chunks in the correct order';
      case PracticeModeType.audio:
        return 'Listen and repeat with text-to-speech';
      case PracticeModeType.typeItOut:
        return 'Type the entire verse from memory';
    }
  }

  /// Returns difficulty level based on mode complexity
  ///
  /// Easy: Flip Card, First Letter, Progressive Reveal
  /// Medium: Fill in the Blanks (Cloze), Phrase Scramble, Word Bank
  /// Hard: Audio, Type It Out
  Difficulty get difficulty {
    switch (modeType) {
      case PracticeModeType.flipCard:
      case PracticeModeType.firstLetter:
      case PracticeModeType.progressive:
        return Difficulty.easy;
      case PracticeModeType.cloze:
      case PracticeModeType.wordScramble:
      case PracticeModeType.wordBank:
        return Difficulty.medium;
      case PracticeModeType.audio:
      case PracticeModeType.typeItOut:
        return Difficulty.hard;
    }
  }

  /// Returns difficulty as a string for UI display
  String get difficultyLabel {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  /// Returns color for difficulty badge
  Color get difficultyColor {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  /// Checks if this mode has been tried at least once
  bool get hasBeenTried => timesPracticed > 0;

  /// Checks if this mode is proficient
  /// Proficiency unlocks the next mode in progression
  ///
  /// Criteria:
  /// - 1 repetition with 100% accuracy (using >= 99.5 for floating point safety), OR
  /// - 3 repetitions with 70%+ accuracy
  bool get isProficient =>
      (timesPracticed >= 1 && successRate >= 99.5) ||
      (timesPracticed >= 3 &&
          successRate >= PracticeModeProgression.proficiencyThreshold);

  /// Checks if this mode is mastered (80%+ success rate with 5+ practices)
  bool get isMastered =>
      timesPracticed >= PracticeModeProgression.masteryMinPractices &&
      successRate >= PracticeModeProgression.masteryThreshold;

  /// Returns proficiency level based on success rate
  /// - 'beginner': < 50%
  /// - 'learning': 50-79%
  /// - 'proficient': 80-94%
  /// - 'mastered': >= 95%
  String get proficiencyLevel {
    if (successRate < 50.0) return 'beginner';
    if (successRate < 80.0) return 'learning';
    if (successRate < 95.0) return 'proficient';
    return 'mastered';
  }

  /// Returns formatted average time display (e.g., "2m 30s")
  String get formattedAverageTime {
    if (averageTimeSeconds == null) return 'N/A';

    final minutes = averageTimeSeconds! ~/ 60;
    final seconds = averageTimeSeconds! % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Returns a recommendation message based on performance
  String get recommendationMessage {
    if (!hasBeenTried) {
      return 'Try this mode to test your memory!';
    }

    if (isMastered) {
      return 'Excellent! You\'ve mastered this mode.';
    }

    if (successRate < 50.0 && timesPracticed >= 3) {
      return 'Keep practicing - consistency is key!';
    }

    if (successRate >= 70.0 && timesPracticed < 5) {
      return 'Great progress! Practice more to master it.';
    }

    return 'Good work! Continue practicing regularly.';
  }

  /// Creates a copy of this entity with updated fields
  PracticeModeEntity copyWith({
    PracticeModeType? modeType,
    int? timesPracticed,
    double? successRate,
    int? averageTimeSeconds,
    bool? isFavorite,
  }) {
    return PracticeModeEntity(
      modeType: modeType ?? this.modeType,
      timesPracticed: timesPracticed ?? this.timesPracticed,
      successRate: successRate ?? this.successRate,
      averageTimeSeconds: averageTimeSeconds ?? this.averageTimeSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
        modeType,
        timesPracticed,
        successRate,
        averageTimeSeconds,
        isFavorite,
      ];

  @override
  bool get stringify => true;
}
