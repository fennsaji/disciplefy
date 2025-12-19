import 'package:equatable/equatable.dart';

/// Base class for all Memory Verse events.
///
/// Events represent user actions or system triggers that cause state changes
/// in the Memory Verse feature. All events extend Equatable for proper
/// comparison in BLoC testing and state management.
abstract class MemoryVerseEvent extends Equatable {
  const MemoryVerseEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load verses that are due for review.
///
/// Triggers fetching of verses whose next_review_date has passed,
/// along with review statistics for dashboard display.
///
/// **Parameters:**
/// - [limit] - Maximum verses to fetch (default: 20)
/// - [offset] - Pagination offset (default: 0)
/// - [language] - Optional language filter
/// - [forceRefresh] - If true, bypasses cache and fetches from remote
class LoadDueVerses extends MemoryVerseEvent {
  final int limit;
  final int offset;
  final String? language;
  final bool forceRefresh;

  const LoadDueVerses({
    this.limit = 20,
    this.offset = 0,
    this.language,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [limit, offset, language, forceRefresh];
}

/// Event to add a Daily Verse to the memory deck.
///
/// Triggers conversion of a daily verse into a memory verse with
/// initial SM-2 state for spaced repetition review.
///
/// **Parameters:**
/// - [dailyVerseId] - UUID of the Daily Verse to add
/// - [language] - Optional language code ('en', 'hi', 'ml') - if not provided, auto-detects
class AddVerseFromDaily extends MemoryVerseEvent {
  final String dailyVerseId;
  final String? language;

  const AddVerseFromDaily(this.dailyVerseId, {this.language});

  @override
  List<Object?> get props => [dailyVerseId, language];
}

/// Event to manually add a custom verse to the memory deck.
///
/// Triggers creation of a memory verse from user-provided reference
/// and text, with initial SM-2 state.
///
/// **Parameters:**
/// - [verseReference] - Bible verse reference (e.g., "John 3:16")
/// - [verseText] - Full text of the verse to memorize
/// - [language] - Optional language code ('en', 'hi', 'ml')
class AddVerseManually extends MemoryVerseEvent {
  final String verseReference;
  final String verseText;
  final String? language;

  const AddVerseManually({
    required this.verseReference,
    required this.verseText,
    this.language,
  });

  @override
  List<Object?> get props => [verseReference, verseText, language];
}

/// Event to submit a review for a memory verse.
///
/// Triggers SM-2 algorithm calculation to update verse's learning state
/// (ease factor, interval, repetitions, next review date).
///
/// **Parameters:**
/// - [memoryVerseId] - UUID of the verse being reviewed
/// - [qualityRating] - Quality of recall on 0-5 SM-2 scale:
///   - 0: Complete blackout
///   - 1: Incorrect, but recognized
///   - 2: Incorrect, but remembered parts
///   - 3: Correct with difficulty
///   - 4: Correct with hesitation
///   - 5: Perfect recall
/// - [timeSpentSeconds] - Optional time spent on review (for analytics)
class SubmitReview extends MemoryVerseEvent {
  final String memoryVerseId;
  final int qualityRating;
  final int? timeSpentSeconds;

  const SubmitReview({
    required this.memoryVerseId,
    required this.qualityRating,
    this.timeSpentSeconds,
  });

  @override
  List<Object?> get props => [memoryVerseId, qualityRating, timeSpentSeconds];
}

/// Event to load review statistics.
///
/// Triggers fetching of aggregate statistics about the user's memory
/// verse progress (total verses, due count, mastery percentage, etc.).
class LoadStatistics extends MemoryVerseEvent {
  const LoadStatistics();
}

/// Event to delete a memory verse.
///
/// Triggers removal of a verse from the memory deck. If offline,
/// the deletion is queued for sync when connection is restored.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse to delete
class DeleteVerse extends MemoryVerseEvent {
  final String verseId;

  const DeleteVerse(this.verseId);

  @override
  List<Object?> get props => [verseId];
}

/// Event to sync local changes with remote server.
///
/// Triggers processing of the sync queue, uploading all pending
/// operations (add verse, submit review, delete verse) that were
/// performed while offline.
///
/// **Parameters:**
/// - [language] - Optional language filter to maintain current selection after sync
class SyncWithRemote extends MemoryVerseEvent {
  final String? language;

  const SyncWithRemote({this.language});

  @override
  List<Object?> get props => [language];
}

/// Event to clear local cache.
///
/// Triggers deletion of all locally cached memory verses and sync queue.
/// Typically used on logout or data reset.
class ClearCache extends MemoryVerseEvent {
  const ClearCache();
}

/// Event to refresh the current verse list.
///
/// Convenience event that triggers a force refresh of due verses
/// with current pagination settings. Used for pull-to-refresh.
///
/// **Parameters:**
/// - [language] - Optional language filter to maintain current selection
class RefreshVerses extends MemoryVerseEvent {
  final String? language;

  const RefreshVerses({this.language});

  @override
  List<Object?> get props => [language];
}

/// Event to fetch verse text from Bible API.
///
/// Triggers fetching of verse text and localized reference from the
/// Bible API for use in manual verse addition.
///
/// **Parameters:**
/// - [book] - Book name (e.g., "John", "Genesis")
/// - [chapter] - Chapter number
/// - [verseStart] - Starting verse number
/// - [verseEnd] - Optional ending verse for ranges
/// - [language] - Language code ('en', 'hi', 'ml')
class FetchVerseTextRequested extends MemoryVerseEvent {
  final String book;
  final int chapter;
  final int verseStart;
  final int? verseEnd;
  final String language;

  const FetchVerseTextRequested({
    required this.book,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
    required this.language,
  });

  @override
  List<Object?> get props => [book, chapter, verseStart, verseEnd, language];
}

// =============================================================================
// PRACTICE MODE EVENTS (Sprint 2 - Memory Verses Enhancement)
// =============================================================================

/// Event to select a practice mode for a verse.
///
/// Triggers loading of practice mode statistics and sets the selected mode
/// for the upcoming practice session.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse to practice
/// - [practiceMode] - Selected practice mode type
class SelectPracticeModeEvent extends MemoryVerseEvent {
  final String verseId;
  final String practiceMode;

  const SelectPracticeModeEvent({
    required this.verseId,
    required this.practiceMode,
  });

  @override
  List<Object?> get props => [verseId, practiceMode];
}

/// Event to submit a practice session with mode-specific data.
///
/// Triggers SM-2 update, mode statistics update, mastery progress,
/// daily goal update, streak update, XP calculation, and achievement checks.
///
/// **Parameters:**
/// - [memoryVerseId] - UUID of the verse practiced
/// - [practiceMode] - Mode used for practice (typing, cloze, first_letter, etc.)
/// - [qualityRating] - SM-2 quality rating (0-5)
/// - [confidenceRating] - Self-assessed confidence (1-5)
/// - [accuracyPercentage] - Percentage accuracy for typing/cloze modes (0-100)
/// - [timeSpentSeconds] - Time spent on practice session
/// - [hintsUsed] - Number of hints used (for first_letter mode)
class SubmitPracticeSessionEvent extends MemoryVerseEvent {
  final String memoryVerseId;
  final String practiceMode;
  final int qualityRating;
  final int confidenceRating;
  final double? accuracyPercentage;
  final int timeSpentSeconds;
  final int? hintsUsed;

  const SubmitPracticeSessionEvent({
    required this.memoryVerseId,
    required this.practiceMode,
    required this.qualityRating,
    required this.confidenceRating,
    this.accuracyPercentage,
    required this.timeSpentSeconds,
    this.hintsUsed,
  });

  @override
  List<Object?> get props => [
        memoryVerseId,
        practiceMode,
        qualityRating,
        confidenceRating,
        accuracyPercentage,
        timeSpentSeconds,
        hintsUsed,
      ];
}

/// Event to load practice mode statistics for user.
///
/// Triggers fetching of all practice mode performance data
/// (success rates, times practiced, favorite modes).
class LoadPracticeModeStatsEvent extends MemoryVerseEvent {
  const LoadPracticeModeStatsEvent();
}

// =============================================================================
// STREAK EVENTS
// =============================================================================

/// Event to load memory streak data.
///
/// Triggers fetching of current streak, longest streak, milestones,
/// freeze days available, and practice history.
class LoadMemoryStreakEvent extends MemoryVerseEvent {
  const LoadMemoryStreakEvent();
}

/// Event to use a streak freeze day.
///
/// Triggers application of a freeze day to protect the streak on a missed day.
///
/// **Parameters:**
/// - [freezeDate] - Date to protect (must be yesterday or today)
class UseStreakFreezeEvent extends MemoryVerseEvent {
  final DateTime freezeDate;

  const UseStreakFreezeEvent({required this.freezeDate});

  @override
  List<Object?> get props => [freezeDate];
}

/// Event to check for streak milestone achievement.
///
/// Triggers checking if user reached 10, 30, 100, or 365-day milestone.
class CheckStreakMilestoneEvent extends MemoryVerseEvent {
  const CheckStreakMilestoneEvent();
}

// =============================================================================
// MASTERY EVENTS
// =============================================================================

/// Event to load mastery progress for a verse.
///
/// Triggers fetching of mastery level, percentage, modes mastered,
/// and perfect recall count for a specific verse.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse
class LoadMasteryProgressEvent extends MemoryVerseEvent {
  final String verseId;

  const LoadMasteryProgressEvent({required this.verseId});

  @override
  List<Object?> get props => [verseId];
}

/// Event to update mastery level for a verse.
///
/// Triggers recalculation and update of mastery level based on
/// recent performance and mode diversity.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse
/// - [newMasteryLevel] - New mastery level (beginner/intermediate/advanced/expert/master)
class UpdateMasteryLevelEvent extends MemoryVerseEvent {
  final String verseId;
  final String newMasteryLevel;

  const UpdateMasteryLevelEvent({
    required this.verseId,
    required this.newMasteryLevel,
  });

  @override
  List<Object?> get props => [verseId, newMasteryLevel];
}

// =============================================================================
// DAILY GOAL EVENTS
// =============================================================================

/// Event to load daily goal progress.
///
/// Triggers fetching of today's goal targets and completion status.
class LoadDailyGoalEvent extends MemoryVerseEvent {
  const LoadDailyGoalEvent();
}

/// Event to update daily goal progress after practice.
///
/// Triggers incrementing review count or new verse count and checking
/// for goal completion with bonus XP award.
///
/// **Parameters:**
/// - [isNewVerse] - True if this was adding a new verse, false if review
class UpdateDailyGoalProgressEvent extends MemoryVerseEvent {
  final bool isNewVerse;

  const UpdateDailyGoalProgressEvent({required this.isNewVerse});

  @override
  List<Object?> get props => [isNewVerse];
}

/// Event to set custom daily goal targets.
///
/// Triggers updating user's preferred daily review and new verse targets.
///
/// **Parameters:**
/// - [targetReviews] - Number of reviews to complete daily
/// - [targetNewVerses] - Number of new verses to add daily
class SetDailyGoalTargetsEvent extends MemoryVerseEvent {
  final int targetReviews;
  final int targetNewVerses;

  const SetDailyGoalTargetsEvent({
    required this.targetReviews,
    required this.targetNewVerses,
  });

  @override
  List<Object?> get props => [targetReviews, targetNewVerses];
}

// =============================================================================
// CHALLENGE EVENTS
// =============================================================================

/// Event to load active challenges.
///
/// Triggers fetching of ongoing weekly/monthly challenges with
/// progress tracking and time remaining.
class LoadActiveChallengesEvent extends MemoryVerseEvent {
  const LoadActiveChallengesEvent();
}

/// Event to claim challenge reward.
///
/// Triggers marking challenge as complete and awarding XP bonus.
///
/// **Parameters:**
/// - [challengeId] - UUID of the challenge to claim
class ClaimChallengeRewardEvent extends MemoryVerseEvent {
  final String challengeId;

  const ClaimChallengeRewardEvent({required this.challengeId});

  @override
  List<Object?> get props => [challengeId];
}

// ==========================================================================
// LEADERBOARD AND STATISTICS EVENTS
// ==========================================================================

/// Event to load Memory Champions Leaderboard.
///
/// Triggers fetching the leaderboard entries and user's stats.
///
/// **Parameters:**
/// - [period] - Time period: 'weekly', 'monthly', or 'all_time'
/// - [limit] - Maximum number of entries to fetch (default: 100)
class LoadMemoryChampionsLeaderboardEvent extends MemoryVerseEvent {
  final String period;
  final int limit;

  const LoadMemoryChampionsLeaderboardEvent({
    required this.period,
    this.limit = 100,
  });

  @override
  List<Object?> get props => [period, limit];
}

/// Event to load comprehensive memory verse statistics.
///
/// Triggers fetching activity heat map, mastery distribution,
/// practice mode stats, and overall statistics.
class LoadMemoryStatisticsEvent extends MemoryVerseEvent {
  const LoadMemoryStatisticsEvent();

  @override
  List<Object?> get props => [];
}

// ==========================================================================
// SUGGESTED VERSES EVENTS
// ==========================================================================

/// Event to load suggested/popular Bible verses.
///
/// Triggers fetching curated verses organized by category that users can
/// browse and add to their memory deck.
///
/// **Parameters:**
/// - [category] - Optional category filter (salvation, comfort, strength, etc.)
/// - [language] - Language code ('en', 'hi', 'ml')
class LoadSuggestedVersesEvent extends MemoryVerseEvent {
  final String? category;
  final String language;

  const LoadSuggestedVersesEvent({
    this.category,
    this.language = 'en',
  });

  @override
  List<Object?> get props => [category, language];
}

/// Event to add a suggested verse to the memory deck.
///
/// Triggers conversion of a suggested verse into a memory verse with
/// initial SM-2 state for spaced repetition review.
///
/// **Parameters:**
/// - [verseReference] - Bible verse reference (e.g., "John 3:16")
/// - [verseText] - Full text of the verse
/// - [language] - Language code ('en', 'hi', 'ml')
class AddSuggestedVerseEvent extends MemoryVerseEvent {
  final String verseReference;
  final String verseText;
  final String language;

  const AddSuggestedVerseEvent({
    required this.verseReference,
    required this.verseText,
    required this.language,
  });

  @override
  List<Object?> get props => [verseReference, verseText, language];
}
