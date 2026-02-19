import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Sentinel class for copyWith method to distinguish between null and unset values.
const unsetValue = _CopyWithSentinel();

class _CopyWithSentinel {
  const _CopyWithSentinel();
}

/// Enum representing the 5 mastery levels for verse memorization.
///
/// Progression path: Beginner → Intermediate → Advanced → Expert → Master
enum MasteryLevel {
  beginner,
  intermediate,
  advanced,
  expert,
  master,
}

/// Extension to convert MasteryLevel to string and vice versa.
extension MasteryLevelExtension on MasteryLevel {
  /// Converts enum to string format matching database column
  String toJson() {
    switch (this) {
      case MasteryLevel.beginner:
        return 'beginner';
      case MasteryLevel.intermediate:
        return 'intermediate';
      case MasteryLevel.advanced:
        return 'advanced';
      case MasteryLevel.expert:
        return 'expert';
      case MasteryLevel.master:
        return 'master';
    }
  }

  /// Parses string from database to enum
  static MasteryLevel fromJson(String value) {
    switch (value) {
      case 'beginner':
        return MasteryLevel.beginner;
      case 'intermediate':
        return MasteryLevel.intermediate;
      case 'advanced':
        return MasteryLevel.advanced;
      case 'expert':
        return MasteryLevel.expert;
      case 'master':
        return MasteryLevel.master;
      default:
        return MasteryLevel.beginner;
    }
  }
}

/// Domain entity representing mastery progression for a memory verse.
///
/// Tracks performance across multiple practice modes to determine overall
/// mastery level. Uses composite metrics (mode mastery, perfect recalls,
/// confidence) to provide accurate progression assessment.
class MasteryProgressEntity extends Equatable {
  /// Current mastery level (Beginner → Master)
  final MasteryLevel masteryLevel;

  /// Progress percentage to next level (0.0 - 100.0)
  final double masteryPercentage;

  /// Number of practice modes mastered (80%+ success rate)
  final int modesMastered;

  /// Total number of perfect recalls (quality rating = 5)
  final int perfectRecalls;

  /// Average confidence rating (1.0 - 5.0)
  /// Null if no confidence ratings recorded yet
  final double? confidenceRating;

  const MasteryProgressEntity({
    required this.masteryLevel,
    required this.masteryPercentage,
    required this.modesMastered,
    required this.perfectRecalls,
    this.confidenceRating,
  });

  /// Total number of practice modes available
  static const int totalModes = 8;

  /// Returns the next mastery level to achieve
  /// Returns null if already at Master level
  MasteryLevel? get nextLevel {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return MasteryLevel.intermediate;
      case MasteryLevel.intermediate:
        return MasteryLevel.advanced;
      case MasteryLevel.advanced:
        return MasteryLevel.expert;
      case MasteryLevel.expert:
        return MasteryLevel.master;
      case MasteryLevel.master:
        return null; // Already at max level
    }
  }

  /// Returns display name for current mastery level
  String get levelDisplayName {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return 'Beginner';
      case MasteryLevel.intermediate:
        return 'Intermediate';
      case MasteryLevel.advanced:
        return 'Advanced';
      case MasteryLevel.expert:
        return 'Expert';
      case MasteryLevel.master:
        return 'Master';
    }
  }

  /// Returns display name for next mastery level
  String get nextLevelDisplayName {
    final next = nextLevel;
    if (next == null) return 'Master'; // Already at max

    switch (next) {
      case MasteryLevel.beginner:
        return 'Beginner';
      case MasteryLevel.intermediate:
        return 'Intermediate';
      case MasteryLevel.advanced:
        return 'Advanced';
      case MasteryLevel.expert:
        return 'Expert';
      case MasteryLevel.master:
        return 'Master';
    }
  }

  /// Returns requirements needed to reach next level
  String get nextLevelRequirements {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return 'Master 2 practice modes & achieve 5 perfect recalls';
      case MasteryLevel.intermediate:
        return 'Master 4 practice modes & achieve 15 perfect recalls';
      case MasteryLevel.advanced:
        return 'Master 6 practice modes & achieve 30 perfect recalls';
      case MasteryLevel.expert:
        return 'Master all 8 practice modes & achieve 50 perfect recalls';
      case MasteryLevel.master:
        return 'You\'ve achieved mastery! Keep practicing to maintain it.';
    }
  }

  /// Checks if requirements for next level are met
  bool get canLevelUp {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return modesMastered >= 2 && perfectRecalls >= 5;
      case MasteryLevel.intermediate:
        return modesMastered >= 4 && perfectRecalls >= 15;
      case MasteryLevel.advanced:
        return modesMastered >= 6 && perfectRecalls >= 30;
      case MasteryLevel.expert:
        return modesMastered >= 8 && perfectRecalls >= 50;
      case MasteryLevel.master:
        return false; // Already at max level
    }
  }

  /// Returns color associated with mastery level
  Color get levelColor {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return AppColors.masteryBeginner;
      case MasteryLevel.intermediate:
        return AppColors.masteryIntermediate;
      case MasteryLevel.advanced:
        return AppColors.masteryAdvanced;
      case MasteryLevel.expert:
        return AppColors.masteryExpert;
      case MasteryLevel.master:
        return AppColors.masteryMaster;
    }
  }

  /// Returns icon for mastery level badge
  IconData get levelIcon {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return Icons.school;
      case MasteryLevel.intermediate:
        return Icons.menu_book;
      case MasteryLevel.advanced:
        return Icons.auto_stories;
      case MasteryLevel.expert:
        return Icons.workspace_premium;
      case MasteryLevel.master:
        return Icons.emoji_events; // Trophy for master
    }
  }

  /// Returns numerical level (1-5) for UI display
  int get levelNumber {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return 1;
      case MasteryLevel.intermediate:
        return 2;
      case MasteryLevel.advanced:
        return 3;
      case MasteryLevel.expert:
        return 4;
      case MasteryLevel.master:
        return 5;
    }
  }

  /// Returns percentage of modes mastered (0.0 - 1.0)
  double get modesMasteredPercentage =>
      (modesMastered / totalModes).clamp(0.0, 1.0);

  /// Returns formatted confidence rating (e.g., "4.2/5.0")
  String get formattedConfidenceRating {
    if (confidenceRating == null) return 'N/A';
    return '${confidenceRating!.toStringAsFixed(1)}/5.0';
  }

  /// Returns confidence level label
  String get confidenceLabel {
    if (confidenceRating == null) return 'No data';

    if (confidenceRating! >= 4.5) return 'Very confident';
    if (confidenceRating! >= 3.5) return 'Confident';
    if (confidenceRating! >= 2.5) return 'Somewhat confident';
    if (confidenceRating! >= 1.5) return 'Not very confident';
    return 'Not confident';
  }

  /// Returns motivational message based on progress
  String get motivationalMessage {
    if (masteryLevel == MasteryLevel.master) {
      return 'Outstanding! You\'ve mastered this verse.';
    }

    if (canLevelUp) {
      return 'Ready to level up! Keep up the excellent work.';
    }

    if (masteryPercentage >= 75.0) {
      return 'Almost there! You\'re close to the next level.';
    }

    if (masteryPercentage >= 50.0) {
      return 'Great progress! You\'re halfway to $nextLevelDisplayName.';
    }

    if (masteryPercentage >= 25.0) {
      return 'Good start! Keep practicing to reach $nextLevelDisplayName.';
    }

    return 'You\'re on your way! Practice regularly to improve.';
  }

  /// Returns detailed progress summary
  String get progressSummary {
    return '$modesMastered/$totalModes modes mastered • $perfectRecalls perfect recalls';
  }

  /// Checks if verse is considered "mastered" (Expert or Master level)
  bool get isFullyMastered {
    return masteryLevel == MasteryLevel.expert ||
        masteryLevel == MasteryLevel.master;
  }

  /// Returns XP reward for reaching this mastery level
  int get xpRewardForLevel {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return 0; // Starting level
      case MasteryLevel.intermediate:
        return 100;
      case MasteryLevel.advanced:
        return 300;
      case MasteryLevel.expert:
        return 600;
      case MasteryLevel.master:
        return 1000;
    }
  }

  /// Creates a copy of this entity with updated fields
  MasteryProgressEntity copyWith({
    MasteryLevel? masteryLevel,
    double? masteryPercentage,
    int? modesMastered,
    int? perfectRecalls,
    Object? confidenceRating = unsetValue,
  }) {
    return MasteryProgressEntity(
      masteryLevel: masteryLevel ?? this.masteryLevel,
      masteryPercentage: masteryPercentage ?? this.masteryPercentage,
      modesMastered: modesMastered ?? this.modesMastered,
      perfectRecalls: perfectRecalls ?? this.perfectRecalls,
      confidenceRating: confidenceRating == unsetValue
          ? this.confidenceRating
          : confidenceRating as double?,
    );
  }

  @override
  List<Object?> get props => [
        masteryLevel,
        masteryPercentage,
        modesMastered,
        perfectRecalls,
        confidenceRating,
      ];

  @override
  bool get stringify => true;
}
