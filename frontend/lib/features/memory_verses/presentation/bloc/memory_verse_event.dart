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
class SyncWithRemote extends MemoryVerseEvent {
  const SyncWithRemote();
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
class RefreshVerses extends MemoryVerseEvent {
  const RefreshVerses();
}

/// Event to load a specific verse by ID.
///
/// Triggers fetching of a single verse for detailed view.
///
/// **Parameters:**
/// - [verseId] - UUID of the verse to load
class LoadVerseById extends MemoryVerseEvent {
  final String verseId;

  const LoadVerseById(this.verseId);

  @override
  List<Object?> get props => [verseId];
}
