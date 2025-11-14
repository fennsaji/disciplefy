import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/add_verse_from_daily.dart' as add_from_daily_uc;
import '../../domain/usecases/add_verse_manually.dart' as add_manually_uc;
import '../../domain/usecases/get_due_verses.dart';
import '../../domain/usecases/get_statistics.dart';
import '../../domain/usecases/submit_review.dart' as submit_review_uc;
import 'memory_verse_event.dart';
import 'memory_verse_state.dart';

/// BLoC for managing Memory Verse feature state.
///
/// Connects UI events to domain use cases and emits appropriate states
/// based on operation results. Handles all business logic for memory
/// verse operations including offline-first patterns and error handling.
///
/// **Dependencies:**
/// - GetDueVerses: Fetches verses due for review
/// - AddVerseFromDaily: Adds verse from Daily Verse feature
/// - AddVerseManually: Adds custom verse
/// - SubmitReview: Processes verse reviews with SM-2
/// - GetStatistics: Fetches review statistics
///
/// **State Management:**
/// - Initial → Loading → Loaded/Error
/// - Optimistic updates for better UX
/// - Network error handling with offline indicators
/// - Pagination support for verse lists
class MemoryVerseBloc extends Bloc<MemoryVerseEvent, MemoryVerseState> {
  final GetDueVerses getDueVerses;
  final add_from_daily_uc.AddVerseFromDaily addVerseFromDaily;
  final add_manually_uc.AddVerseManually addVerseManually;
  final submit_review_uc.SubmitReview submitReview;
  final GetStatistics getStatistics;

  MemoryVerseBloc({
    required this.getDueVerses,
    required this.addVerseFromDaily,
    required this.addVerseManually,
    required this.submitReview,
    required this.getStatistics,
  }) : super(const MemoryVerseInitial()) {
    on<LoadDueVerses>(_onLoadDueVerses);
    on<AddVerseFromDaily>(_onAddVerseFromDaily);
    on<AddVerseManually>(_onAddVerseManually);
    on<SubmitReview>(_onSubmitReview);
    on<LoadStatistics>(_onLoadStatistics);
    on<RefreshVerses>(_onRefreshVerses);
  }

  /// Handles LoadDueVerses event.
  ///
  /// Fetches verses due for review along with statistics.
  /// Supports pagination and force refresh.
  Future<void> _onLoadDueVerses(
    LoadDueVerses event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Loading due verses (limit: ${event.limit}, offset: ${event.offset})');
      }

      // Show loading state (unless refreshing with existing data)
      if (!event.forceRefresh || state is! DueVersesLoaded) {
        emit(MemoryVerseLoading(
          message: 'Loading verses...',
          isRefreshing: event.forceRefresh,
        ));
      }

      // Execute use case
      final result = await getDueVerses(
        limit: event.limit,
        offset: event.offset,
        language: event.language,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load due verses failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (data) {
          final (verses, statistics) = data;

          if (kDebugMode) {
            print('✅ [BLOC] Loaded ${verses.length} due verses');
          }

          // Determine if more verses are available (basic pagination check)
          final hasMore = verses.length >= event.limit;

          emit(DueVersesLoaded(
            verses: verses,
            statistics: statistics,
            hasMore: hasMore,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading verses: $e');
      }
      emit(MemoryVerseError(
        message: 'An unexpected error occurred',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles AddVerseFromDaily event.
  ///
  /// Adds a Daily Verse to the memory deck.
  Future<void> _onAddVerseFromDaily(
    AddVerseFromDaily event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Adding verse from daily: ${event.dailyVerseId}');
      }

      emit(const MemoryVerseLoading(message: 'Adding verse...'));

      final result = await addVerseFromDaily(event.dailyVerseId);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Add verse from daily failed: ${failure.message}');
          }

          // Check if operation was queued for offline sync
          if (failure is NetworkFailure && failure.code == 'OFFLINE_QUEUED') {
            emit(OperationQueued(
              message: 'Verse will be added when online',
              operationType: 'add_from_daily',
            ));
          } else {
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
              isNetworkError: failure is NetworkFailure,
            ));
          }
        },
        (verse) {
          if (kDebugMode) {
            print('✅ [BLOC] Verse added: ${verse.verseReference}');
          }

          emit(VerseAdded(
            verse: verse,
            message: '${verse.verseReference} added to memory deck!',
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error adding verse: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to add verse',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles AddVerseManually event.
  ///
  /// Adds a custom verse to the memory deck.
  Future<void> _onAddVerseManually(
    AddVerseManually event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Adding manual verse: ${event.verseReference}');
      }

      emit(const MemoryVerseLoading(message: 'Adding verse...'));

      final result = await addVerseManually(
        verseReference: event.verseReference,
        verseText: event.verseText,
        language: event.language,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Add manual verse failed: ${failure.message}');
          }

          // Check if operation was queued for offline sync
          if (failure is NetworkFailure && failure.code == 'OFFLINE_QUEUED') {
            emit(OperationQueued(
              message: 'Verse will be added when online',
              operationType: 'add_manual',
            ));
          } else {
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
              isNetworkError: failure is NetworkFailure,
            ));
          }
        },
        (verse) {
          if (kDebugMode) {
            print('✅ [BLOC] Manual verse added: ${verse.verseReference}');
          }

          emit(VerseAdded(
            verse: verse,
            message: '${verse.verseReference} added to memory deck!',
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error adding manual verse: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to add verse',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles SubmitReview event.
  ///
  /// Processes a verse review and updates SM-2 state.
  Future<void> _onSubmitReview(
    SubmitReview event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Submitting review (quality: ${event.qualityRating})');
      }

      emit(const MemoryVerseLoading(message: 'Processing review...'));

      final result = await submitReview(
        memoryVerseId: event.memoryVerseId,
        qualityRating: event.qualityRating,
        timeSpentSeconds: event.timeSpentSeconds,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Submit review failed: ${failure.message}');
          }

          // Check if operation was queued for offline sync
          if (failure is NetworkFailure && failure.code == 'OFFLINE_QUEUED') {
            emit(OperationQueued(
              message: 'Review will be synced when online',
              operationType: 'submit_review',
            ));
          } else {
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
              isNetworkError: failure is NetworkFailure,
            ));
          }
        },
        (verse) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Review submitted. Next review: ${verse.nextReviewDate}');
          }

          // Generate success message based on quality rating
          final qualityMessage = _getQualityMessage(event.qualityRating);
          final nextReviewMessage = 'Next review in ${verse.intervalDays} days';

          emit(ReviewSubmitted(
            verse: verse,
            message: '$qualityMessage\n$nextReviewMessage',
            qualityRating: event.qualityRating,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error submitting review: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to submit review',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadStatistics event.
  ///
  /// Fetches review statistics for dashboard display.
  Future<void> _onLoadStatistics(
    LoadStatistics event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading statistics');
      }

      emit(const MemoryVerseLoading(message: 'Loading statistics...'));

      final result = await getStatistics();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load statistics failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (statistics) {
          if (kDebugMode) {
            print('✅ [BLOC] Statistics loaded');
          }
          emit(StatisticsLoaded(statistics));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading statistics: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load statistics',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles RefreshVerses event.
  ///
  /// Convenience handler for pull-to-refresh that triggers LoadDueVerses.
  Future<void> _onRefreshVerses(
    RefreshVerses event,
    Emitter<MemoryVerseState> emit,
  ) async {
    // Trigger LoadDueVerses with forceRefresh flag
    add(const LoadDueVerses(forceRefresh: true));
  }

  /// Returns user-friendly message based on quality rating.
  String _getQualityMessage(int qualityRating) {
    switch (qualityRating) {
      case 0:
        return "Keep practicing! You'll get it next time.";
      case 1:
        return 'Good effort! Review again soon.';
      case 2:
        return 'Getting there! Keep reviewing.';
      case 3:
        return "Well done! You're making progress.";
      case 4:
        return 'Great job! Almost perfect recall.';
      case 5:
        return 'Perfect! Excellent memory work!';
      default:
        return 'Review submitted successfully.';
    }
  }
}
