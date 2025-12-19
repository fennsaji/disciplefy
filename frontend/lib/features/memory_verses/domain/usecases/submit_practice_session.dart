import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/practice_mode_entity.dart';
import '../entities/memory_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Parameters for submitting a practice session.
class SubmitPracticeSessionParams {
  final String memoryVerseId;
  final PracticeModeType practiceMode;
  final int qualityRating; // SM-2 quality rating (0-5)
  final int confidenceRating; // Self-assessed confidence (1-5)
  final double? accuracyPercentage; // For typing/cloze modes (0-100)
  final int timeSpentSeconds;
  final int? hintsUsed; // For first_letter mode

  const SubmitPracticeSessionParams({
    required this.memoryVerseId,
    required this.practiceMode,
    required this.qualityRating,
    required this.confidenceRating,
    this.accuracyPercentage,
    required this.timeSpentSeconds,
    this.hintsUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'memory_verse_id': memoryVerseId,
      // Use toJson() extension to get snake_case format expected by backend
      'practice_mode': practiceMode.toJson(),
      'quality_rating': qualityRating,
      'confidence_rating': confidenceRating,
      'accuracy_percentage': accuracyPercentage,
      'time_spent_seconds': timeSpentSeconds,
      'hints_used': hintsUsed,
    };
  }
}

/// Response from submitting a practice session.
class SubmitPracticeSessionResponse {
  /// Updated verse entity (optional - backend may not return full verse data)
  final MemoryVerseEntity? updatedVerse;
  final List<String> newAchievements; // IDs of newly unlocked achievements
  final int xpEarned;
  final Map<String, dynamic>? dailyGoalProgress;
  final Map<String, dynamic>? challengeProgress;

  const SubmitPracticeSessionResponse({
    this.updatedVerse,
    required this.newAchievements,
    required this.xpEarned,
    this.dailyGoalProgress,
    this.challengeProgress,
  });
}

/// Use case for submitting a practice session with mode-specific data.
///
/// Triggers SM-2 update, mode statistics update, mastery progress,
/// daily goal update, streak update, XP calculation, and achievement checks.
class SubmitPracticeSession {
  final MemoryVerseRepository repository;

  SubmitPracticeSession(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [params] - Practice session parameters
  ///
  /// **Returns:**
  /// - Right: SubmitPracticeSessionResponse with updated data
  /// - Left: Failure if operation fails
  Future<Either<Failure, SubmitPracticeSessionResponse>> call(
    SubmitPracticeSessionParams params,
  ) async {
    // Validate parameters
    if (params.qualityRating < 0 || params.qualityRating > 5) {
      return const Left(ValidationFailure(
        message: 'Quality rating must be between 0 and 5',
        code: 'INVALID_QUALITY_RATING',
      ));
    }

    if (params.confidenceRating < 1 || params.confidenceRating > 5) {
      return const Left(ValidationFailure(
        message: 'Confidence rating must be between 1 and 5',
        code: 'INVALID_CONFIDENCE_RATING',
      ));
    }

    if (params.accuracyPercentage != null &&
        (params.accuracyPercentage! < 0 || params.accuracyPercentage! > 100)) {
      return const Left(ValidationFailure(
        message: 'Accuracy percentage must be between 0 and 100',
        code: 'INVALID_ACCURACY',
      ));
    }

    if (params.timeSpentSeconds < 0) {
      return const Left(ValidationFailure(
        message: 'Time spent must be non-negative',
        code: 'INVALID_TIME',
      ));
    }

    return await repository.submitPracticeSession(params);
  }
}
