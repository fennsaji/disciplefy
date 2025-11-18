import 'package:equatable/equatable.dart';

import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/review_statistics_entity.dart';

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
