import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/fetched_verse_entity.dart';
import '../entities/memory_verse_entity.dart';
import '../entities/review_session_entity.dart';
import '../entities/review_statistics_entity.dart';
import '../entities/practice_mode_entity.dart';
import '../entities/memory_streak_entity.dart';
import '../entities/mastery_progress_entity.dart';
import '../entities/daily_goal_entity.dart';
import '../entities/memory_challenge_entity.dart';
import '../entities/memory_champion_entry.dart';
import '../entities/suggested_verse_entity.dart';
import '../usecases/submit_practice_session.dart';

/// Repository interface for memory verse operations.
///
/// Defines the contract for accessing memory verse data.
/// Implementations handle data sources (Supabase API, Hive cache).
/// Follows Clean Architecture - domain layer defines interfaces.
abstract class MemoryVerseRepository {
  /// Adds a verse from Daily Verse to the memory deck
  ///
  /// [dailyVerseId] - UUID of the Daily Verse to add
  /// [language] - Optional language code ('en', 'hi', 'ml') - if not provided, auto-detects
  ///
  /// Returns the created MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> addVerseFromDaily({
    required String dailyVerseId,
    String? language,
  });

  /// Adds a custom verse manually to the memory deck
  ///
  /// Returns the created MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  });

  /// Fetches all verses that are due for review
  ///
  /// [limit] - Maximum number of verses to fetch (default: 20)
  /// [offset] - Number of verses to skip for pagination (default: 0)
  /// [language] - Optional language filter ('en', 'hi', 'ml')
  ///
  /// Returns a tuple of (verses, statistics) on success, or Failure on error.
  Future<Either<Failure, (List<MemoryVerseEntity>, ReviewStatisticsEntity)>>
      getDueVerses({
    int limit = 20,
    int offset = 0,
    String? language,
  });

  /// Submits a review for a memory verse
  ///
  /// [memoryVerseId] - ID of the verse being reviewed
  /// [qualityRating] - Quality rating (0-5 SM-2 scale)
  /// [timeSpentSeconds] - Optional time spent on review
  ///
  /// Returns updated MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> submitReview({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  });

  /// Fetches review statistics for the user
  ///
  /// Returns ReviewStatisticsEntity on success, or Failure on error.
  Future<Either<Failure, ReviewStatisticsEntity>> getStatistics();

  /// Fetches a single memory verse by ID
  ///
  /// Returns MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> getVerseById(String id);

  /// Fetches all memory verses (for backup/export)
  ///
  /// Returns list of all verses on success, or Failure on error.
  Future<Either<Failure, List<MemoryVerseEntity>>> getAllVerses();

  /// Deletes a memory verse
  ///
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> deleteVerse(String id);

  /// Fetches review history for a specific verse
  ///
  /// [memoryVerseId] - ID of the verse
  /// [limit] - Maximum number of sessions to fetch
  ///
  /// Returns list of ReviewSessionEntity on success, or Failure on error.
  Future<Either<Failure, List<ReviewSessionEntity>>> getReviewHistory({
    required String memoryVerseId,
    int limit = 50,
  });

  /// Syncs local cache with remote data
  ///
  /// Uploads pending local changes and downloads remote updates.
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> syncWithRemote();

  /// Clears local cache (for logout or data reset)
  ///
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> clearLocalCache();

  /// Fetches verse text from Bible API
  ///
  /// [book] - Book name (e.g., "John", "Genesis")
  /// [chapter] - Chapter number
  /// [verseStart] - Starting verse number
  /// [verseEnd] - Optional ending verse for ranges
  /// [language] - Language code ('en', 'hi', 'ml')
  ///
  /// Returns FetchedVerseEntity with text and localized reference on success.
  Future<Either<Failure, FetchedVerseEntity>> fetchVerseText({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    required String language,
  });

  // ==========================================================================
  // PRACTICE MODE METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Selects a practice mode for a verse
  ///
  /// Loads practice mode statistics and sets the selected mode
  /// for the upcoming practice session.
  ///
  /// [verseId] - UUID of the verse to practice
  /// [practiceMode] - Selected practice mode type
  ///
  /// Returns PracticeModeEntity with statistics on success.
  Future<Either<Failure, PracticeModeEntity>> selectPracticeMode({
    required String verseId,
    required PracticeModeType practiceMode,
  });

  /// Submits a practice session with mode-specific data
  ///
  /// Triggers SM-2 update, mode statistics update, mastery progress,
  /// daily goal update, streak update, XP calculation, and achievement checks.
  ///
  /// [params] - Practice session parameters
  ///
  /// Returns SubmitPracticeSessionResponse with updated data on success.
  Future<Either<Failure, SubmitPracticeSessionResponse>> submitPracticeSession(
    SubmitPracticeSessionParams params,
  );

  /// Fetches practice mode statistics for user
  ///
  /// Returns list of all practice modes with performance data.
  Future<Either<Failure, List<PracticeModeEntity>>> getPracticeModeStatistics();

  // ==========================================================================
  // STREAK METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Fetches memory streak data
  ///
  /// Returns current streak, longest streak, milestones,
  /// freeze days available, and practice history.
  Future<Either<Failure, MemoryStreakEntity>> getMemoryStreak();

  /// Uses a streak freeze day to protect the streak
  ///
  /// [freezeDate] - Date to protect (must be yesterday or today)
  ///
  /// Returns updated MemoryStreakEntity on success.
  Future<Either<Failure, MemoryStreakEntity>> useStreakFreeze({
    required DateTime freezeDate,
  });

  /// Checks for streak milestone achievement
  ///
  /// Returns true if a milestone was reached, along with milestone details.
  Future<Either<Failure, (bool, int?)>> checkStreakMilestone();

  // ==========================================================================
  // MASTERY METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Fetches mastery progress for a verse
  ///
  /// [verseId] - UUID of the verse
  ///
  /// Returns mastery level, percentage, modes mastered,
  /// and perfect recall count.
  Future<Either<Failure, MasteryProgressEntity>> getMasteryProgress({
    required String verseId,
  });

  /// Updates mastery level for a verse
  ///
  /// [verseId] - UUID of the verse
  /// [newMasteryLevel] - New mastery level
  ///
  /// Returns updated MasteryProgressEntity on success.
  Future<Either<Failure, MasteryProgressEntity>> updateMasteryLevel({
    required String verseId,
    required MasteryLevel newMasteryLevel,
  });

  // ==========================================================================
  // DAILY GOAL METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Fetches today's daily goal progress
  ///
  /// Returns goal targets and completion status.
  Future<Either<Failure, DailyGoalEntity>> getDailyGoal();

  /// Updates daily goal progress after practice
  ///
  /// [isNewVerse] - True if adding a new verse, false if reviewing
  ///
  /// Returns updated DailyGoalEntity on success.
  Future<Either<Failure, DailyGoalEntity>> updateDailyGoalProgress({
    required bool isNewVerse,
  });

  /// Sets custom daily goal targets
  ///
  /// [targetReviews] - Number of reviews to complete daily
  /// [targetNewVerses] - Number of new verses to add daily
  ///
  /// Returns updated DailyGoalEntity on success.
  Future<Either<Failure, DailyGoalEntity>> setDailyGoalTargets({
    required int targetReviews,
    required int targetNewVerses,
  });

  // ==========================================================================
  // CHALLENGE METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Fetches active challenges
  ///
  /// Returns ongoing weekly/monthly challenges with
  /// progress tracking and time remaining.
  Future<Either<Failure, List<MemoryChallengeEntity>>> getActiveChallenges();

  /// Claims challenge reward
  ///
  /// [challengeId] - UUID of the challenge to claim
  ///
  /// Returns updated challenge and XP bonus on success.
  Future<Either<Failure, (MemoryChallengeEntity, int)>> claimChallengeReward({
    required String challengeId,
  });

  /// Fetches Memory Champions Leaderboard
  ///
  /// [period] - Time period: 'weekly', 'monthly', 'all_time'
  /// [limit] - Maximum number of entries to fetch (default: 100)
  ///
  /// Returns tuple of (leaderboard entries, user's stats and rank).
  Future<Either<Failure, (List<MemoryChampionEntry>, UserMemoryStats)>>
      getMemoryChampionsLeaderboard({
    required String period,
    int limit = 100,
  });

  /// Fetches comprehensive memory verse statistics
  ///
  /// Includes:
  /// - Activity heat map data (practice sessions by date)
  /// - Mastery distribution (count per level)
  /// - Practice mode statistics
  /// - Overall statistics (total verses, reviews, streaks)
  ///
  /// Returns statistics data map.
  Future<Either<Failure, Map<String, dynamic>>> getMemoryStatistics();

  // ==========================================================================
  // SUGGESTED VERSES METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  /// Fetches suggested/popular Bible verses
  ///
  /// [category] - Optional category filter (salvation, comfort, strength, etc.)
  /// [language] - Language code ('en', 'hi', 'ml')
  ///
  /// Returns SuggestedVersesResponse with verses, categories, and total count.
  /// Each verse indicates if it's already in the user's memory deck.
  Future<Either<Failure, SuggestedVersesResponse>> getSuggestedVerses({
    SuggestedVerseCategory? category,
    String language = 'en',
  });
}
