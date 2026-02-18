import 'package:equatable/equatable.dart';

import '../../domain/entities/fetched_verse_entity.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/review_statistics_entity.dart';
import '../../domain/entities/memory_champion_entry.dart';
import '../../domain/entities/suggested_verse_entity.dart';

/// Base class for all Memory Verse states.
///
/// States represent the current condition of the Memory Verse feature,
/// including loading states, success states with data, and error states.
/// All states extend Equatable for proper comparison in UI rebuilds.
abstract class MemoryVerseState extends Equatable {
  const MemoryVerseState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any operations.
///
/// UI should display empty or placeholder content.
class MemoryVerseInitial extends MemoryVerseState {
  const MemoryVerseInitial();
}

/// Loading state during async operations.
///
/// **Parameters:**
/// - [message] - Optional loading message for UI display
/// - [isRefreshing] - True if this is a pull-to-refresh operation
///
/// UI should display:
/// - Progress indicator
/// - Shimmer loading for verse cards
/// - Optional loading message
class MemoryVerseLoading extends MemoryVerseState {
  final String? message;
  final bool isRefreshing;

  const MemoryVerseLoading({
    this.message,
    this.isRefreshing = false,
  });

  @override
  List<Object?> get props => [message, isRefreshing];
}

/// State after successfully loading due verses.
///
/// **Parameters:**
/// - [verses] - List of memory verses due for review
/// - [statistics] - Aggregate statistics for dashboard
/// - [hasMore] - True if more verses available for pagination
///
/// UI should display:
/// - List of verse cards with due indicators
/// - Statistics cards (total, due, mastered)
/// - Load more button if hasMore is true
class DueVersesLoaded extends MemoryVerseState {
  final List<MemoryVerseEntity> verses;
  final ReviewStatisticsEntity statistics;
  final bool hasMore;

  const DueVersesLoaded({
    required this.verses,
    required this.statistics,
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [verses, statistics, hasMore];

  /// Creates a copy with updated values (for pagination).
  DueVersesLoaded copyWith({
    List<MemoryVerseEntity>? verses,
    ReviewStatisticsEntity? statistics,
    bool? hasMore,
  }) {
    return DueVersesLoaded(
      verses: verses ?? this.verses,
      statistics: statistics ?? this.statistics,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// State after successfully adding a verse.
///
/// **Parameters:**
/// - [verse] - The newly added memory verse
/// - [message] - Success message for user feedback
///
/// UI should:
/// - Show success snackbar/toast
/// - Navigate to verse review or back to list
/// - Update verse list if visible
class VerseAdded extends MemoryVerseState {
  final MemoryVerseEntity verse;
  final String message;

  const VerseAdded({
    required this.verse,
    required this.message,
  });

  @override
  List<Object?> get props => [verse, message];
}

/// State after successfully submitting a review.
///
/// **Parameters:**
/// - [verse] - The updated memory verse with new SM-2 state
/// - [message] - Success message with next review info
/// - [qualityRating] - The quality rating that was submitted (0-5)
///
/// UI should:
/// - Show success feedback with next review date
/// - Display updated verse state (interval, ease factor)
/// - Navigate to next verse or back to list
/// - Update statistics if visible
class ReviewSubmitted extends MemoryVerseState {
  final MemoryVerseEntity verse;
  final String message;
  final int qualityRating;

  const ReviewSubmitted({
    required this.verse,
    required this.message,
    required this.qualityRating,
  });

  @override
  List<Object?> get props => [verse, message, qualityRating];
}

/// State after successfully loading statistics.
///
/// **Parameters:**
/// - [statistics] - Review statistics entity with counts and metrics
///
/// UI should:
/// - Display statistics cards
/// - Show mastery percentage
/// - Display motivational message
/// - Show progress bars/charts
class StatisticsLoaded extends MemoryVerseState {
  final ReviewStatisticsEntity statistics;

  const StatisticsLoaded(this.statistics);

  @override
  List<Object?> get props => [statistics];
}

/// State after successfully loading a single verse.
///
/// **Parameters:**
/// - [verse] - The loaded memory verse
///
/// UI should:
/// - Display verse details
/// - Show SM-2 state info (interval, ease, repetitions)
/// - Enable review actions
class VerseLoaded extends MemoryVerseState {
  final MemoryVerseEntity verse;

  const VerseLoaded(this.verse);

  @override
  List<Object?> get props => [verse];
}

/// State after successfully deleting a verse.
///
/// **Parameters:**
/// - [message] - Success message for user feedback
///
/// UI should:
/// - Show success snackbar/toast
/// - Remove verse from list
/// - Update statistics
class VerseDeleted extends MemoryVerseState {
  final String message;

  const VerseDeleted(this.message);

  @override
  List<Object?> get props => [message];
}

/// State after successfully syncing with remote.
///
/// **Parameters:**
/// - [message] - Success message with sync count
/// - [syncedOperations] - Number of operations synced
///
/// UI should:
/// - Show success snackbar/toast
/// - Refresh verse list
/// - Update statistics
class SyncCompleted extends MemoryVerseState {
  final String message;
  final int syncedOperations;

  const SyncCompleted({
    required this.message,
    required this.syncedOperations,
  });

  @override
  List<Object?> get props => [message, syncedOperations];
}

/// State after successfully clearing cache.
///
/// **Parameters:**
/// - [message] - Success message for user feedback
///
/// UI should:
/// - Show success snackbar/toast
/// - Clear all local data
/// - Navigate to initial screen
class CacheCleared extends MemoryVerseState {
  final String message;

  const CacheCleared(this.message);

  @override
  List<Object?> get props => [message];
}

/// Error state when operations fail.
///
/// **Parameters:**
/// - [message] - User-friendly error message
/// - [code] - Technical error code for debugging
/// - [isNetworkError] - True if error is network-related (for offline indicator)
///
/// UI should:
/// - Show error snackbar/toast
/// - Display retry button if applicable
/// - Show offline indicator if isNetworkError is true
/// - Log error code for debugging
class MemoryVerseError extends MemoryVerseState {
  final String message;
  final String code;
  final bool isNetworkError;

  const MemoryVerseError({
    required this.message,
    required this.code,
    this.isNetworkError = false,
  });

  @override
  List<Object?> get props => [message, code, isNetworkError];

  /// Creates a copy with updated values.
  MemoryVerseError copyWith({
    String? message,
    String? code,
    bool? isNetworkError,
  }) {
    return MemoryVerseError(
      message: message ?? this.message,
      code: code ?? this.code,
      isNetworkError: isNetworkError ?? this.isNetworkError,
    );
  }
}

/// State when an operation is queued for offline sync.
///
/// **Parameters:**
/// - [message] - Message explaining operation was queued
/// - [operationType] - Type of operation queued (add, review, delete)
///
/// UI should:
/// - Show info snackbar/toast
/// - Display offline indicator
/// - Show sync pending indicator
class OperationQueued extends MemoryVerseState {
  final String message;
  final String operationType;

  const OperationQueued({
    required this.message,
    required this.operationType,
  });

  @override
  List<Object?> get props => [message, operationType];
}

/// Loading state while fetching verse text from API.
///
/// UI should display loading indicator in the verse text field.
class FetchingVerseText extends MemoryVerseState {
  const FetchingVerseText();
}

/// State after successfully fetching verse text.
///
/// **Parameters:**
/// - [fetchedVerse] - The fetched verse entity with text and localized reference
///
/// UI should:
/// - Populate verse text field
/// - Update reference with localized version
class VerseTextFetched extends MemoryVerseState {
  final FetchedVerseEntity fetchedVerse;

  const VerseTextFetched(this.fetchedVerse);

  @override
  List<Object?> get props => [fetchedVerse];
}

/// Error state when fetching verse text fails.
///
/// **Parameters:**
/// - [message] - User-friendly error message
/// - [code] - Technical error code for debugging
///
/// UI should:
/// - Show error message near the verse text field
/// - Allow user to retry
class FetchVerseTextError extends MemoryVerseState {
  final String message;
  final String code;

  const FetchVerseTextError({
    required this.message,
    required this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

// =============================================================================
// PRACTICE MODE STATES (Sprint 2 - Memory Verses Enhancement)
// =============================================================================

/// State after successfully selecting a practice mode.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse to practice
/// - [practiceMode] - Selected practice mode type
/// - [modeStatistics] - Statistics for the selected mode
///
/// UI should:
/// - Navigate to appropriate practice page
/// - Display mode-specific instructions
class PracticeModeSelected extends MemoryVerseState {
  final String verseId;
  final String practiceMode;
  final Map<String, dynamic>? modeStatistics;

  const PracticeModeSelected({
    required this.verseId,
    required this.practiceMode,
    this.modeStatistics,
  });

  @override
  List<Object?> get props => [verseId, practiceMode, modeStatistics];
}

/// State after successfully submitting a practice session.
///
/// **Parameters:**
/// - [verse] - Updated verse with new SM-2 state (optional - backend may not return full verse)
/// - [message] - Success message with XP earned
/// - [xpEarned] - XP points earned from practice
/// - [newAchievements] - List of newly unlocked achievements
/// - [dailyGoalProgress] - Updated daily goal status
/// - [streakUpdated] - True if streak was updated
/// - [masteryLevelUp] - True if mastery level increased
///
/// UI should:
/// - Show success feedback with XP
/// - Display achievement unlock animations
/// - Show daily goal progress
/// - Show streak milestone if applicable
/// - Show mastery level up celebration
class PracticeSessionSubmitted extends MemoryVerseState {
  final MemoryVerseEntity? verse;
  final String message;
  final int xpEarned;
  final List<String> newAchievements;
  final Map<String, dynamic>? dailyGoalProgress;
  final bool streakUpdated;
  final bool masteryLevelUp;

  const PracticeSessionSubmitted({
    this.verse,
    required this.message,
    required this.xpEarned,
    this.newAchievements = const [],
    this.dailyGoalProgress,
    this.streakUpdated = false,
    this.masteryLevelUp = false,
  });

  @override
  List<Object?> get props => [
        verse,
        message,
        xpEarned,
        newAchievements,
        dailyGoalProgress,
        streakUpdated,
        masteryLevelUp,
      ];
}

/// State after successfully loading practice mode statistics.
///
/// **Parameters:**
/// - [modeStatistics] - Map of mode type to statistics
///
/// UI should:
/// - Display practice mode cards with stats
/// - Show success rates and practice counts
/// - Highlight favorite modes
class PracticeModeStatsLoaded extends MemoryVerseState {
  final Map<String, Map<String, dynamic>> modeStatistics;

  const PracticeModeStatsLoaded({required this.modeStatistics});

  @override
  List<Object?> get props => [modeStatistics];
}

// =============================================================================
// STREAK STATES
// =============================================================================

/// State after successfully loading memory streak.
///
/// **Parameters:**
/// - [currentStreak] - Current consecutive days practiced
/// - [longestStreak] - All-time longest streak
/// - [lastPracticeDate] - Date of last practice
/// - [totalPracticeDays] - Total days practiced
/// - [freezeDaysAvailable] - Number of freeze days available
/// - [freezeDaysUsed] - Total freeze days used
/// - [milestones] - Map of milestone days to achievement dates
///
/// UI should:
/// - Display streak counter with flame icon
/// - Show freeze days available
/// - Display milestone progress
/// - Show motivational messages
class MemoryStreakLoaded extends MemoryVerseState {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastPracticeDate;
  final int totalPracticeDays;
  final int freezeDaysAvailable;
  final int freezeDaysUsed;
  final Map<int, DateTime?> milestones;

  const MemoryStreakLoaded({
    required this.currentStreak,
    required this.longestStreak,
    this.lastPracticeDate,
    required this.totalPracticeDays,
    required this.freezeDaysAvailable,
    required this.freezeDaysUsed,
    required this.milestones,
  });

  @override
  List<Object?> get props => [
        currentStreak,
        longestStreak,
        lastPracticeDate,
        totalPracticeDays,
        freezeDaysAvailable,
        freezeDaysUsed,
        milestones,
      ];
}

/// State after successfully using a streak freeze.
///
/// **Parameters:**
/// - [message] - Success message
/// - [freezeDaysRemaining] - Freeze days remaining after use
/// - [protectedDate] - Date that was protected
///
/// UI should:
/// - Show success message
/// - Update freeze days counter
/// - Show protected date on calendar
class StreakFreezeUsed extends MemoryVerseState {
  final String message;
  final int freezeDaysRemaining;
  final DateTime protectedDate;

  const StreakFreezeUsed({
    required this.message,
    required this.freezeDaysRemaining,
    required this.protectedDate,
  });

  @override
  List<Object?> get props => [message, freezeDaysRemaining, protectedDate];
}

/// State after reaching a streak milestone.
///
/// **Parameters:**
/// - [milestone] - Milestone days reached (10, 30, 100, 365)
/// - [achievementUnlocked] - Name of achievement unlocked
/// - [xpEarned] - XP bonus for milestone
///
/// UI should:
/// - Show celebration animation
/// - Display achievement unlock
/// - Show XP earned
class StreakMilestoneReached extends MemoryVerseState {
  final int milestone;
  final String achievementUnlocked;
  final int xpEarned;

  const StreakMilestoneReached({
    required this.milestone,
    required this.achievementUnlocked,
    required this.xpEarned,
  });

  @override
  List<Object?> get props => [milestone, achievementUnlocked, xpEarned];
}

// =============================================================================
// MASTERY STATES
// =============================================================================

/// State after successfully loading mastery progress.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse
/// - [masteryLevel] - Current mastery level
/// - [masteryPercentage] - Progress to next level (0-100)
/// - [modesMastered] - Number of modes mastered
/// - [perfectRecalls] - Count of perfect recalls
/// - [confidenceRating] - Average confidence rating
///
/// UI should:
/// - Display mastery badge
/// - Show progress bar to next level
/// - Display modes mastered count
/// - Show perfect recall count
class MasteryProgressLoaded extends MemoryVerseState {
  final String verseId;
  final String masteryLevel;
  final double masteryPercentage;
  final int modesMastered;
  final int perfectRecalls;
  final double? confidenceRating;

  const MasteryProgressLoaded({
    required this.verseId,
    required this.masteryLevel,
    required this.masteryPercentage,
    required this.modesMastered,
    required this.perfectRecalls,
    this.confidenceRating,
  });

  @override
  List<Object?> get props => [
        verseId,
        masteryLevel,
        masteryPercentage,
        modesMastered,
        perfectRecalls,
        confidenceRating,
      ];
}

/// State after successfully updating mastery level.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse
/// - [newMasteryLevel] - New mastery level achieved
/// - [message] - Success message
/// - [xpEarned] - XP bonus for level up
///
/// UI should:
/// - Show level up animation
/// - Display new mastery badge
/// - Show XP earned
class MasteryLevelUpdated extends MemoryVerseState {
  final String verseId;
  final String newMasteryLevel;
  final String message;
  final int xpEarned;

  const MasteryLevelUpdated({
    required this.verseId,
    required this.newMasteryLevel,
    required this.message,
    required this.xpEarned,
  });

  @override
  List<Object?> get props => [verseId, newMasteryLevel, message, xpEarned];
}

// =============================================================================
// DAILY GOAL STATES
// =============================================================================

/// State after successfully loading daily goal.
///
/// **Parameters:**
/// - [targetReviews] - Target number of reviews
/// - [completedReviews] - Completed reviews count
/// - [targetNewVerses] - Target new verses to add
/// - [addedNewVerses] - New verses added count
/// - [goalAchieved] - True if both targets met
/// - [bonusXpAwarded] - XP bonus for completion
///
/// UI should:
/// - Display circular progress
/// - Show completion percentages
/// - Display motivational message
/// - Show bonus XP if achieved
class DailyGoalLoaded extends MemoryVerseState {
  final int targetReviews;
  final int completedReviews;
  final int targetNewVerses;
  final int addedNewVerses;
  final bool goalAchieved;
  final int bonusXpAwarded;

  const DailyGoalLoaded({
    required this.targetReviews,
    required this.completedReviews,
    required this.targetNewVerses,
    required this.addedNewVerses,
    required this.goalAchieved,
    required this.bonusXpAwarded,
  });

  @override
  List<Object?> get props => [
        targetReviews,
        completedReviews,
        targetNewVerses,
        addedNewVerses,
        goalAchieved,
        bonusXpAwarded,
      ];
}

/// State after successfully updating daily goal progress.
///
/// **Parameters:**
/// - [message] - Success message
/// - [newProgress] - Updated daily goal entity
/// - [goalJustCompleted] - True if goal completed with this update
///
/// UI should:
/// - Update progress indicators
/// - Show celebration if goal completed
/// - Display updated counts
class DailyGoalProgressUpdated extends MemoryVerseState {
  final String message;
  final Map<String, dynamic> newProgress;
  final bool goalJustCompleted;

  const DailyGoalProgressUpdated({
    required this.message,
    required this.newProgress,
    this.goalJustCompleted = false,
  });

  @override
  List<Object?> get props => [message, newProgress, goalJustCompleted];
}

/// State after successfully setting daily goal targets.
///
/// **Parameters:**
/// - [message] - Success message
/// - [targetReviews] - New review target
/// - [targetNewVerses] - New verse target
///
/// UI should:
/// - Show success message
/// - Update target displays
/// - Refresh daily goal widget
class DailyGoalTargetsSet extends MemoryVerseState {
  final String message;
  final int targetReviews;
  final int targetNewVerses;

  const DailyGoalTargetsSet({
    required this.message,
    required this.targetReviews,
    required this.targetNewVerses,
  });

  @override
  List<Object?> get props => [message, targetReviews, targetNewVerses];
}

// =============================================================================
// CHALLENGE STATES
// =============================================================================

/// State after successfully loading active challenges.
///
/// **Parameters:**
/// - [challenges] - List of active challenge entities
///
/// UI should:
/// - Display challenge cards
/// - Show progress bars
/// - Display time remaining
/// - Show XP rewards
class ActiveChallengesLoaded extends MemoryVerseState {
  final List<Map<String, dynamic>> challenges;

  const ActiveChallengesLoaded({required this.challenges});

  @override
  List<Object?> get props => [challenges];
}

/// State after successfully claiming a challenge reward.
///
/// **Parameters:**
/// - [challengeId] - UUID of completed challenge
/// - [message] - Success message
/// - [xpEarned] - XP reward claimed
/// - [achievementUnlocked] - Optional achievement name
///
/// UI should:
/// - Show success message
/// - Display XP earned
/// - Show achievement unlock if applicable
/// - Remove challenge from active list
class ChallengeRewardClaimed extends MemoryVerseState {
  final String challengeId;
  final String message;
  final int xpEarned;
  final String? achievementUnlocked;

  const ChallengeRewardClaimed({
    required this.challengeId,
    required this.message,
    required this.xpEarned,
    this.achievementUnlocked,
  });

  @override
  List<Object?> get props =>
      [challengeId, message, xpEarned, achievementUnlocked];
}

// ==========================================================================
// LEADERBOARD AND STATISTICS STATES
// ==========================================================================

/// State after successfully loading Memory Champions Leaderboard.
///
/// **Parameters:**
/// - [leaderboard] - List of top Memory Champions ranked by master verses
/// - [userStats] - Current user's statistics and rank
/// - [period] - Time period: 'weekly', 'monthly', or 'all_time'
///
/// UI should:
/// - Display leaderboard with rank badges for top 3
/// - Show user's rank card (even if not in top 100)
/// - Highlight current user in leaderboard if they're in top 100
/// - Show trophy icons for top 10
class MemoryChampionsLeaderboardLoaded extends MemoryVerseState {
  final List<MemoryChampionEntry> leaderboard;
  final UserMemoryStats userStats;
  final String period;

  const MemoryChampionsLeaderboardLoaded({
    required this.leaderboard,
    required this.userStats,
    required this.period,
  });

  @override
  List<Object?> get props => [leaderboard, userStats, period];
}

/// State after successfully loading memory verse statistics.
///
/// **Parameters:**
/// - [statistics] - Map containing:
///   - activity_heat_map: Practice sessions by date
///   - mastery_distribution: Count per mastery level
///   - practice_mode_stats: Performance by mode
///   - overall_stats: Total verses, reviews, streaks
///
/// UI should:
/// - Display activity heat map calendar
/// - Show mastery distribution chart
/// - Display practice mode statistics
/// - Show overall statistics cards
class MemoryStatisticsLoaded extends MemoryVerseState {
  final Map<String, dynamic> statistics;

  const MemoryStatisticsLoaded({required this.statistics});

  @override
  List<Object?> get props => [statistics];
}

// ==========================================================================
// SUGGESTED VERSES STATES
// ==========================================================================

/// Loading state while fetching suggested verses.
///
/// UI should display shimmer loading for verse cards.
class SuggestedVersesLoading extends MemoryVerseState {
  const SuggestedVersesLoading();
}

/// State after successfully loading suggested verses.
///
/// **Parameters:**
/// - [verses] - List of suggested verse entities
/// - [categories] - Available categories for filtering
/// - [selectedCategory] - Currently selected category (null for 'All')
/// - [total] - Total number of verses
///
/// UI should:
/// - Display category filter chips
/// - Show verse cards with add buttons
/// - Show 'Already Added' badge for verses in user's deck
class SuggestedVersesLoaded extends MemoryVerseState {
  final List<SuggestedVerseEntity> verses;
  final List<SuggestedVerseCategory> categories;
  final SuggestedVerseCategory? selectedCategory;
  final int total;

  const SuggestedVersesLoaded({
    required this.verses,
    required this.categories,
    this.selectedCategory,
    required this.total,
  });

  @override
  List<Object?> get props => [verses, categories, selectedCategory, total];

  /// Creates a copy with updated values.
  SuggestedVersesLoaded copyWith({
    List<SuggestedVerseEntity>? verses,
    List<SuggestedVerseCategory>? categories,
    SuggestedVerseCategory? selectedCategory,
    int? total,
  }) {
    return SuggestedVersesLoaded(
      verses: verses ?? this.verses,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      total: total ?? this.total,
    );
  }
}

/// Error state when loading suggested verses fails.
///
/// **Parameters:**
/// - [message] - User-friendly error message
/// - [code] - Technical error code for debugging
///
/// UI should:
/// - Show error message
/// - Display retry button
class SuggestedVersesError extends MemoryVerseState {
  final String message;
  final String code;

  const SuggestedVersesError({
    required this.message,
    required this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

// =============================================================================
// PRACTICE MODE UNLOCK RESTRICTION STATES
// =============================================================================

/// State when practice mode is tier-locked (not available in user's tier).
///
/// **Parameters:**
/// - [mode] - The locked practice mode
/// - [currentTier] - User's current subscription tier
/// - [availableModes] - List of modes available in user's tier
/// - [requiredTier] - Minimum tier required to access this mode
/// - [message] - User-friendly error message
///
/// UI should:
/// - Show tier-lock overlay on mode card
/// - Display upgrade dialog explaining tier restriction
/// - Show available modes for current tier
class MemoryVersePracticeModeTierLocked extends MemoryVerseState {
  final String mode;
  final String currentTier;
  final List<String> availableModes;
  final String requiredTier;
  final String message;

  const MemoryVersePracticeModeTierLocked({
    required this.mode,
    required this.currentTier,
    required this.availableModes,
    required this.requiredTier,
    required this.message,
  });

  @override
  List<Object?> get props =>
      [mode, currentTier, availableModes, requiredTier, message];
}

/// State when daily unlock limit is exceeded for a verse.
///
/// **Parameters:**
/// - [unlockedModes] - List of modes already unlocked today for this verse
/// - [unlockedCount] - Number of modes unlocked
/// - [limit] - Maximum unlocked modes allowed per verse per day
/// - [tier] - User's current subscription tier
/// - [verseId] - UUID of the memory verse
/// - [date] - Current date (YYYY-MM-DD)
/// - [message] - User-friendly error message
///
/// UI should:
/// - Show unlock limit exceeded dialog
/// - Display which modes are already unlocked
/// - Show upgrade options for more unlock slots
/// - Allow practicing already unlocked modes
class MemoryVerseUnlockLimitExceeded extends MemoryVerseState {
  final List<String> unlockedModes;
  final int unlockedCount;
  final int limit;
  final String tier;
  final String verseId;
  final String date;
  final String message;

  const MemoryVerseUnlockLimitExceeded({
    required this.unlockedModes,
    required this.unlockedCount,
    required this.limit,
    required this.tier,
    required this.verseId,
    required this.date,
    required this.message,
  });

  @override
  List<Object?> get props => [
        unlockedModes,
        unlockedCount,
        limit,
        tier,
        verseId,
        date,
        message,
      ];
}
