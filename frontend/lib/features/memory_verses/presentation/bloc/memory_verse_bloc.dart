import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/mastery_progress_entity.dart';
import '../../domain/entities/practice_mode_entity.dart';
import '../../domain/usecases/add_verse_from_daily.dart' as add_from_daily_uc;
import '../../domain/usecases/add_verse_manually.dart' as add_manually_uc;
import '../../domain/usecases/claim_challenge_reward.dart';
import '../../domain/usecases/delete_verse.dart' as delete_verse_uc;
import '../../domain/usecases/fetch_verse_text.dart';
import '../../domain/usecases/get_active_challenges.dart';
import '../../domain/usecases/get_daily_goal.dart';
import '../../domain/usecases/get_due_verses.dart';
import '../../domain/usecases/get_mastery_progress.dart';
import '../../domain/usecases/get_memory_streak.dart';
import '../../domain/usecases/get_practice_mode_statistics.dart';
import '../../domain/usecases/get_statistics.dart';
import '../../domain/usecases/get_memory_statistics.dart';
import '../../domain/usecases/get_suggested_verses.dart';
import '../../domain/entities/suggested_verse_entity.dart';
import '../../domain/usecases/select_practice_mode.dart';
import '../../domain/usecases/set_daily_goal_targets.dart';
import '../../domain/usecases/submit_practice_session.dart';
import '../../domain/usecases/submit_review.dart' as submit_review_uc;
import '../../domain/usecases/update_daily_goal_progress.dart';
import '../../domain/usecases/update_mastery_level.dart';
import '../../domain/usecases/use_streak_freeze.dart';
// Leaderboard and statistics use cases
import '../../domain/usecases/get_memory_champions_leaderboard.dart';
// Services
import '../../data/services/memory_verse_notification_service.dart';
import '../../data/services/suggested_verses_cache_service.dart';
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
  final FetchVerseText fetchVerseText;
  final delete_verse_uc.DeleteVerse deleteVerse;

  // Gamification use cases
  final SelectPracticeMode selectPracticeMode;
  final SubmitPracticeSession submitPracticeSession;
  final GetPracticeModeStatistics getPracticeModeStatistics;
  final GetMemoryStreak getMemoryStreak;
  final UseStreakFreeze useStreakFreeze;
  final GetMasteryProgress getMasteryProgress;
  final UpdateMasteryLevel updateMasteryLevel;
  final GetDailyGoal getDailyGoal;
  final UpdateDailyGoalProgress updateDailyGoalProgress;
  final SetDailyGoalTargets setDailyGoalTargets;
  final GetActiveChallenges getActiveChallenges;
  final ClaimChallengeReward claimChallengeReward;

  // Leaderboard and statistics use cases
  final GetMemoryChampionsLeaderboard getMemoryChampionsLeaderboard;
  final GetMemoryStatistics getMemoryStatistics;

  // Suggested verses use case
  final GetSuggestedVerses getSuggestedVerses;

  // Services
  final MemoryVerseNotificationService notificationService;
  final SuggestedVersesCacheService suggestedVersesCacheService;

  MemoryVerseBloc({
    required this.getDueVerses,
    required this.addVerseFromDaily,
    required this.addVerseManually,
    required this.submitReview,
    required this.getStatistics,
    required this.fetchVerseText,
    required this.deleteVerse,
    // Gamification use cases
    required this.selectPracticeMode,
    required this.submitPracticeSession,
    required this.getPracticeModeStatistics,
    required this.getMemoryStreak,
    required this.useStreakFreeze,
    required this.getMasteryProgress,
    required this.updateMasteryLevel,
    required this.getDailyGoal,
    required this.updateDailyGoalProgress,
    required this.setDailyGoalTargets,
    required this.getActiveChallenges,
    required this.claimChallengeReward,
    // Leaderboard and statistics use cases
    required this.getMemoryChampionsLeaderboard,
    required this.getMemoryStatistics,
    // Suggested verses use case
    required this.getSuggestedVerses,
    // Services
    required this.notificationService,
    required this.suggestedVersesCacheService,
  }) : super(const MemoryVerseInitial()) {
    on<LoadDueVerses>(_onLoadDueVerses);
    on<AddVerseFromDaily>(_onAddVerseFromDaily);
    on<AddVerseManually>(_onAddVerseManually);
    on<SubmitReview>(_onSubmitReview);
    on<LoadStatistics>(_onLoadStatistics);
    on<RefreshVerses>(_onRefreshVerses);
    on<SyncWithRemote>(_onSyncWithRemote);
    on<FetchVerseTextRequested>(_onFetchVerseTextRequested);
    on<DeleteVerse>(_onDeleteVerse);

    // Gamification event handlers
    on<SelectPracticeModeEvent>(_onSelectPracticeMode);
    on<SubmitPracticeSessionEvent>(_onSubmitPracticeSession);
    on<LoadPracticeModeStatsEvent>(_onLoadPracticeModeStats);
    on<PracticeModeTierLockedEvent>(_onPracticeModeTierLocked);
    on<PracticeUnlockLimitExceededEvent>(_onPracticeUnlockLimitExceeded);
    on<LoadMemoryStreakEvent>(_onLoadMemoryStreak);
    on<UseStreakFreezeEvent>(_onUseStreakFreeze);
    on<CheckStreakMilestoneEvent>(_onCheckStreakMilestone);
    on<LoadMasteryProgressEvent>(_onLoadMasteryProgress);
    on<UpdateMasteryLevelEvent>(_onUpdateMasteryLevel);
    on<LoadDailyGoalEvent>(_onLoadDailyGoal);
    on<UpdateDailyGoalProgressEvent>(_onUpdateDailyGoalProgress);
    on<SetDailyGoalTargetsEvent>(_onSetDailyGoalTargets);
    on<LoadActiveChallengesEvent>(_onLoadActiveChallenges);
    on<ClaimChallengeRewardEvent>(_onClaimChallengeReward);

    // Leaderboard and statistics event handlers
    on<LoadMemoryChampionsLeaderboardEvent>(_onLoadMemoryChampionsLeaderboard);
    on<LoadMemoryStatisticsEvent>(_onLoadMemoryStatistics);

    // Suggested verses event handlers
    on<LoadSuggestedVersesEvent>(_onLoadSuggestedVerses);
    on<AddSuggestedVerseEvent>(_onAddSuggestedVerse);
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

      final result = await addVerseFromDaily(
        event.dailyVerseId,
        language: event.language,
      );

      await result.fold(
        (failure) async {
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
        (verse) async {
          if (kDebugMode) {
            print('✅ [BLOC] Verse added: ${verse.verseReference}');
          }

          // Clear suggested verses cache to refresh "Already Added" status
          await suggestedVersesCacheService.clearCache();
          if (kDebugMode) {
            print('🗑️ [BLOC] Cleared suggested verses cache');
          }

          // Check if emit is still valid before emitting
          if (!emit.isDone) {
            emit(VerseAdded(
              verse: verse,
              message: '${verse.verseReference} added to memory deck!',
            ));
          }
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
    // Trigger LoadDueVerses with forceRefresh flag and preserve language filter
    add(LoadDueVerses(forceRefresh: true, language: event.language));
  }

  /// Handles SyncWithRemote event.
  ///
  /// Syncs local changes with remote server.
  /// Currently triggers a refresh to ensure data is up-to-date.
  Future<void> _onSyncWithRemote(
    SyncWithRemote event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 [BLOC] Syncing with remote server');
      }

      emit(const MemoryVerseLoading(message: 'Syncing with server...'));

      // For now, sync is handled by refreshing verses
      // This will fetch latest data from server
      final result = await getDueVerses(
        limit: 50,
        language: event.language,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Sync failed: ${failure.message}');
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
            print('✅ [BLOC] Sync completed. Loaded ${verses.length} verses');
          }

          emit(SyncCompleted(
            message: 'Sync completed successfully',
            syncedOperations: verses.length,
          ));

          // Reload the verses to show updated data with language filter preserved
          add(LoadDueVerses(forceRefresh: true, language: event.language));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error during sync: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to sync with server',
        code: 'SYNC_ERROR',
      ));
    }
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

  /// Handles FetchVerseTextRequested event.
  ///
  /// Fetches verse text from Bible API for manual verse addition.
  Future<void> _onFetchVerseTextRequested(
    FetchVerseTextRequested event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Fetching verse text: ${event.book} ${event.chapter}:${event.verseStart}${event.verseEnd != null ? '-${event.verseEnd}' : ''}');
      }

      emit(const FetchingVerseText());

      final result = await fetchVerseText(
        book: event.book,
        chapter: event.chapter,
        verseStart: event.verseStart,
        verseEnd: event.verseEnd,
        language: event.language,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Fetch verse text failed: ${failure.message}');
          }
          emit(FetchVerseTextError(
            message: failure.message,
            code: failure.code,
          ));
        },
        (fetchedVerse) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Verse text fetched: ${fetchedVerse.localizedReference}');
          }
          emit(VerseTextFetched(fetchedVerse));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error fetching verse text: $e');
      }
      emit(const FetchVerseTextError(
        message: 'Failed to fetch verse text',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles DeleteVerse event.
  ///
  /// Deletes a memory verse from the user's deck.
  Future<void> _onDeleteVerse(
    DeleteVerse event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('🗑️ [BLOC] Deleting verse: ${event.verseId}');
      }

      emit(const MemoryVerseLoading(message: 'Deleting verse...'));

      final result = await deleteVerse(event.verseId);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Delete verse failed: ${failure.message}');
          }

          // Check if operation was queued for offline sync
          if (failure is NetworkFailure && failure.code == 'OFFLINE_QUEUED') {
            emit(OperationQueued(
              message: 'Verse will be deleted when online',
              operationType: 'delete',
            ));
          } else {
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
              isNetworkError: failure is NetworkFailure,
            ));
          }
        },
        (_) {
          if (kDebugMode) {
            print('✅ [BLOC] Verse deleted successfully');
          }

          emit(const VerseDeleted('Verse removed from memory deck'));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error deleting verse: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to delete verse',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  // ===========================================================================
  // GAMIFICATION EVENT HANDLERS (Sprint 3 - Memory Verses Enhancement)
  // ===========================================================================

  /// Handles SelectPracticeModeEvent.
  ///
  /// Selects a practice mode for a verse and loads mode statistics.
  Future<void> _onSelectPracticeMode(
    SelectPracticeModeEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Selecting practice mode: ${event.practiceMode} for verse ${event.verseId}');
      }

      emit(const MemoryVerseLoading(message: 'Loading practice mode...'));

      final result = await selectPracticeMode(
        verseId: event.verseId,
        practiceMode: PracticeModeType.values.firstWhere(
          (e) => e.name == event.practiceMode,
        ),
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Select practice mode failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (practiceMode) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Practice mode selected: ${practiceMode.modeType.name}');
          }
          emit(PracticeModeSelected(
            verseId: event.verseId,
            practiceMode: event.practiceMode,
            modeStatistics: {
              'success_rate': practiceMode.successRate,
              'times_practiced': practiceMode.timesPracticed,
              'average_time_seconds': practiceMode.averageTimeSeconds,
            },
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error selecting practice mode: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to select practice mode',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles SubmitPracticeSessionEvent.
  ///
  /// Submits practice session with comprehensive gamification updates.
  Future<void> _onSubmitPracticeSession(
    SubmitPracticeSessionEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Submitting practice session: ${event.practiceMode}');
      }

      emit(const MemoryVerseLoading(message: 'Processing practice...'));

      final result = await submitPracticeSession(SubmitPracticeSessionParams(
        memoryVerseId: event.memoryVerseId,
        // Use fromJson to properly convert snake_case string to enum
        practiceMode: PracticeModeTypeExtension.fromJson(event.practiceMode),
        qualityRating: event.qualityRating,
        confidenceRating: event.confidenceRating,
        accuracyPercentage: event.accuracyPercentage,
        timeSpentSeconds: event.timeSpentSeconds,
        hintsUsed: event.hintsUsed,
      ));

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [BLOC] Submit practice session failed: ${failure.message}');
          }

          // Check for practice mode restriction errors
          if (failure.code == 'PRACTICE_MODE_TIER_LOCKED') {
            // Extract error details from failure message
            // Backend returns: { code, message, mode, tier, available_modes, required_tier }
            if (kDebugMode) {
              print('🔒 [BLOC] Practice mode tier-locked: ${failure.code}');
            }
            // Emit tier-locked state - UI will show upgrade dialog
            // Note: We need error details from the API response
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
            ));
            return;
          }

          if (failure.code == 'PRACTICE_UNLOCK_LIMIT_EXCEEDED') {
            // Extract error details from failure message
            // Backend returns: { code, message, details: { unlocked_modes, unlocked_count, unlock_limit, etc. } }
            if (kDebugMode) {
              print('⚠️ [BLOC] Daily unlock limit exceeded: ${failure.code}');
            }
            // Emit unlock-limit state - UI will show upgrade dialog
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
            ));
            return;
          }

          // Generic error for other failures
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (response) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Practice session submitted: ${response.xpEarned} XP earned');
          }
          emit(PracticeSessionSubmitted(
            verse: response.updatedVerse,
            message: 'Practice complete! +${response.xpEarned} XP',
            xpEarned: response.xpEarned,
            newAchievements: response.newAchievements,
            dailyGoalProgress: response.dailyGoalProgress,
            streakUpdated: response.dailyGoalProgress != null,
            masteryLevelUp: response.newAchievements.isNotEmpty,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error submitting practice session: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to submit practice session',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadPracticeModeStatsEvent.
  ///
  /// Loads statistics for all practice modes.
  Future<void> _onLoadPracticeModeStats(
    LoadPracticeModeStatsEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading practice mode statistics');
      }

      emit(const MemoryVerseLoading(message: 'Loading statistics...'));

      final result = await getPracticeModeStatistics();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [BLOC] Load practice mode stats failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (modes) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Practice mode statistics loaded: ${modes.length} modes');
          }

          final modeStats = <String, Map<String, dynamic>>{};
          for (final mode in modes) {
            modeStats[mode.modeType.name] = {
              'times_practiced': mode.timesPracticed,
              'success_rate': mode.successRate,
              'average_time_seconds': mode.averageTimeSeconds,
              'is_favorite': mode.isFavorite,
            };
          }

          emit(PracticeModeStatsLoaded(modeStatistics: modeStats));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading practice mode stats: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load practice mode statistics',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles PracticeModeTierLockedEvent.
  ///
  /// Emits state when user attempts to practice with a mode not available in their tier.
  /// Triggers upgrade dialog in UI.
  Future<void> _onPracticeModeTierLocked(
    PracticeModeTierLockedEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    if (kDebugMode) {
      print(
          '🔒 [BLOC] Practice mode tier-locked: ${event.mode} (current tier: ${event.currentTier})');
    }

    emit(MemoryVersePracticeModeTierLocked(
      mode: event.mode,
      currentTier: event.currentTier,
      availableModes: event.availableModes,
      requiredTier: event.requiredTier,
      message: event.message,
    ));
  }

  /// Handles PracticeUnlockLimitExceededEvent.
  ///
  /// Emits state when user exceeds daily unlock limit for a verse.
  /// Triggers upgrade dialog in UI showing unlocked modes and upgrade options.
  Future<void> _onPracticeUnlockLimitExceeded(
    PracticeUnlockLimitExceededEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    if (kDebugMode) {
      print(
          '⚠️ [BLOC] Daily unlock limit exceeded: ${event.unlockedCount}/${event.limit} modes unlocked (verse: ${event.verseId})');
    }

    emit(MemoryVerseUnlockLimitExceeded(
      unlockedModes: event.unlockedModes,
      unlockedCount: event.unlockedCount,
      limit: event.limit,
      tier: event.tier,
      verseId: event.verseId,
      date: event.date,
      message: event.message,
    ));
  }

  /// Handles LoadMemoryStreakEvent.
  ///
  /// Loads current memory streak data.
  Future<void> _onLoadMemoryStreak(
    LoadMemoryStreakEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading memory streak');
      }

      emit(const MemoryVerseLoading(message: 'Loading streak...'));

      final result = await getMemoryStreak();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load memory streak failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (streak) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Memory streak loaded: ${streak.currentStreak} days');
          }
          emit(MemoryStreakLoaded(
            currentStreak: streak.currentStreak,
            longestStreak: streak.longestStreak,
            lastPracticeDate: streak.lastPracticeDate,
            totalPracticeDays: streak.totalPracticeDays,
            freezeDaysAvailable: streak.freezeDaysAvailable,
            freezeDaysUsed: streak.freezeDaysUsed,
            milestones: streak.milestones,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading memory streak: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load memory streak',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles UseStreakFreezeEvent.
  ///
  /// Uses a streak freeze day to protect the streak.
  Future<void> _onUseStreakFreeze(
    UseStreakFreezeEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Using streak freeze for date: ${event.freezeDate}');
      }

      emit(const MemoryVerseLoading(message: 'Applying streak freeze...'));

      final result = await useStreakFreeze(freezeDate: event.freezeDate);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Use streak freeze failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (streak) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Streak freeze used: ${streak.freezeDaysAvailable} remaining');
          }
          emit(StreakFreezeUsed(
            message:
                'Streak protected! ${streak.freezeDaysAvailable} freeze days remaining',
            freezeDaysRemaining: streak.freezeDaysAvailable,
            protectedDate: event.freezeDate,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error using streak freeze: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to use streak freeze',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles CheckStreakMilestoneEvent.
  ///
  /// Checks if a streak milestone has been reached.
  Future<void> _onCheckStreakMilestone(
    CheckStreakMilestoneEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Checking streak milestone');
      }

      final result = await getMemoryStreak();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Check streak milestone failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (streak) {
          // Check for milestone achievements
          final milestones = [10, 30, 100, 365];
          final currentStreak = streak.currentStreak;

          for (final milestone in milestones) {
            if (currentStreak == milestone &&
                (streak.milestones[milestone] == null ||
                    streak.milestones[milestone]!
                            .difference(DateTime.now())
                            .inDays ==
                        0)) {
              if (kDebugMode) {
                print('✅ [BLOC] Streak milestone reached: $milestone days');
              }
              emit(StreakMilestoneReached(
                milestone: milestone,
                achievementUnlocked: '$milestone Day Streak',
                xpEarned: milestone * 10,
              ));
              return;
            }
          }

          // No milestone reached
          if (kDebugMode) {
            print('ℹ️ [BLOC] No streak milestone at $currentStreak days');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error checking streak milestone: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to check streak milestone',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadMasteryProgressEvent.
  ///
  /// Loads mastery progress for a specific verse.
  Future<void> _onLoadMasteryProgress(
    LoadMasteryProgressEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading mastery progress for verse: ${event.verseId}');
      }

      emit(const MemoryVerseLoading(message: 'Loading mastery progress...'));

      final result = await getMasteryProgress(verseId: event.verseId);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load mastery progress failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (mastery) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Mastery progress loaded: ${mastery.masteryLevel.name}');
          }
          emit(MasteryProgressLoaded(
            verseId: event.verseId,
            masteryLevel: mastery.masteryLevel.name,
            masteryPercentage: mastery.masteryPercentage,
            modesMastered: mastery.modesMastered,
            perfectRecalls: mastery.perfectRecalls,
            confidenceRating: mastery.confidenceRating,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading mastery progress: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load mastery progress',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles UpdateMasteryLevelEvent.
  ///
  /// Updates mastery level for a verse.
  Future<void> _onUpdateMasteryLevel(
    UpdateMasteryLevelEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Updating mastery level for verse: ${event.verseId} to ${event.newMasteryLevel}');
      }

      emit(const MemoryVerseLoading(message: 'Updating mastery level...'));

      final result = await updateMasteryLevel(
        verseId: event.verseId,
        newMasteryLevel: MasteryLevel.values.firstWhere(
          (e) => e.name == event.newMasteryLevel,
        ),
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Update mastery level failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (mastery) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Mastery level updated: ${mastery.masteryLevel.name}');
          }
          emit(MasteryLevelUpdated(
            verseId: event.verseId,
            newMasteryLevel: mastery.masteryLevel.name,
            message: 'Mastery level updated to ${mastery.masteryLevel.name}!',
            xpEarned: 100,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error updating mastery level: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to update mastery level',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadDailyGoalEvent.
  ///
  /// Loads today's daily goal and progress.
  Future<void> _onLoadDailyGoal(
    LoadDailyGoalEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading daily goal');
      }

      emit(const MemoryVerseLoading(message: 'Loading daily goal...'));

      final result = await getDailyGoal();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load daily goal failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (goal) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Daily goal loaded: ${goal.completedReviews}/${goal.targetReviews} reviews');
          }
          emit(DailyGoalLoaded(
            targetReviews: goal.targetReviews,
            completedReviews: goal.completedReviews,
            targetNewVerses: goal.targetNewVerses,
            addedNewVerses: goal.addedNewVerses,
            goalAchieved: goal.goalAchieved,
            bonusXpAwarded: goal.bonusXpAwarded,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading daily goal: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load daily goal',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles UpdateDailyGoalProgressEvent.
  ///
  /// Updates daily goal progress after practice.
  Future<void> _onUpdateDailyGoalProgress(
    UpdateDailyGoalProgressEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Updating daily goal progress (isNewVerse: ${event.isNewVerse})');
      }

      final result =
          await updateDailyGoalProgress(isNewVerse: event.isNewVerse);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [BLOC] Update daily goal progress failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (goal) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Daily goal progress updated: ${goal.completedReviews}/${goal.targetReviews}');
          }

          final goalJustCompleted =
              goal.goalAchieved && goal.bonusXpAwarded > 0;

          emit(DailyGoalProgressUpdated(
            message: goalJustCompleted
                ? 'Daily goal completed! +${goal.bonusXpAwarded} XP'
                : 'Progress updated',
            newProgress: {
              'target_reviews': goal.targetReviews,
              'completed_reviews': goal.completedReviews,
              'target_new_verses': goal.targetNewVerses,
              'added_new_verses': goal.addedNewVerses,
              'goal_achieved': goal.goalAchieved,
            },
            goalJustCompleted: goalJustCompleted,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error updating daily goal progress: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to update daily goal progress',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles SetDailyGoalTargetsEvent.
  ///
  /// Sets custom daily goal targets.
  Future<void> _onSetDailyGoalTargets(
    SetDailyGoalTargetsEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '📖 [BLOC] Setting daily goal targets: ${event.targetReviews} reviews, ${event.targetNewVerses} new verses');
      }

      emit(const MemoryVerseLoading(message: 'Setting goal targets...'));

      final result = await setDailyGoalTargets(
        targetReviews: event.targetReviews,
        targetNewVerses: event.targetNewVerses,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Set daily goal targets failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (goal) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Daily goal targets set: ${goal.targetReviews} reviews, ${goal.targetNewVerses} new verses');
          }
          emit(DailyGoalTargetsSet(
            message: 'Daily goals updated!',
            targetReviews: goal.targetReviews,
            targetNewVerses: goal.targetNewVerses,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error setting daily goal targets: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to set daily goal targets',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadActiveChallengesEvent.
  ///
  /// Loads active challenges for the user.
  Future<void> _onLoadActiveChallenges(
    LoadActiveChallengesEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Loading active challenges');
      }

      emit(const MemoryVerseLoading(message: 'Loading challenges...'));

      final result = await getActiveChallenges();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load active challenges failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (challenges) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Active challenges loaded: ${challenges.length} challenges');
          }

          final challengeData = challenges
              .map((challenge) => {
                    'id': challenge.id,
                    'type': challenge.challengeType.name,
                    'target_type': challenge.targetType.name,
                    'target_value': challenge.targetValue,
                    'current_progress': challenge.currentProgress,
                    'xp_reward': challenge.xpReward,
                    'start_date': challenge.startDate.toIso8601String(),
                    'end_date': challenge.endDate.toIso8601String(),
                    'is_completed': challenge.isCompleted,
                  })
              .toList();

          emit(ActiveChallengesLoaded(challenges: challengeData));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading active challenges: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to load active challenges',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles ClaimChallengeRewardEvent.
  ///
  /// Claims reward for a completed challenge.
  Future<void> _onClaimChallengeReward(
    ClaimChallengeRewardEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📖 [BLOC] Claiming challenge reward: ${event.challengeId}');
      }

      emit(const MemoryVerseLoading(message: 'Claiming reward...'));

      final result = await claimChallengeReward(challengeId: event.challengeId);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Claim challenge reward failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (data) {
          final (challenge, xpEarned) = data;
          if (kDebugMode) {
            print('✅ [BLOC] Challenge reward claimed: $xpEarned XP');
          }
          emit(ChallengeRewardClaimed(
            challengeId: challenge.id,
            message: 'Challenge completed! +$xpEarned XP',
            xpEarned: xpEarned,
            achievementUnlocked: challenge.badgeIcon,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error claiming challenge reward: $e');
      }
      emit(MemoryVerseError(
        message: 'Failed to claim challenge reward',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  // ==========================================================================
  // LEADERBOARD AND STATISTICS EVENT HANDLERS
  // ==========================================================================

  /// Handles LoadMemoryChampionsLeaderboardEvent.
  ///
  /// Fetches Memory Champions Leaderboard with user stats and rankings.
  Future<void> _onLoadMemoryChampionsLeaderboard(
    LoadMemoryChampionsLeaderboardEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '🏆 [BLOC] Loading Memory Champions leaderboard (period: ${event.period})');
      }

      emit(const MemoryVerseLoading(message: 'Loading leaderboard...'));

      final result = await getMemoryChampionsLeaderboard(
        LeaderboardParams(
          period: event.period,
          limit: event.limit,
        ),
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load leaderboard failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (data) {
          final (leaderboard, userStats) = data;
          if (kDebugMode) {
            print('✅ [BLOC] Leaderboard loaded: ${leaderboard.length} entries');
          }
          emit(MemoryChampionsLeaderboardLoaded(
            leaderboard: leaderboard,
            userStats: userStats,
            period: event.period,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading leaderboard: $e');
      }
      emit(const MemoryVerseError(
        message: 'Failed to load leaderboard',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles LoadMemoryStatisticsEvent.
  ///
  /// Fetches comprehensive memory verse statistics including heat map,
  /// mastery distribution, and practice mode stats.
  Future<void> _onLoadMemoryStatistics(
    LoadMemoryStatisticsEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('📊 [BLOC] Loading memory statistics');
      }

      emit(const MemoryVerseLoading(message: 'Loading statistics...'));

      final result = await getMemoryStatistics();

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load memory statistics failed: ${failure.message}');
          }
          emit(MemoryVerseError(
            message: failure.message,
            code: failure.code,
            isNetworkError: failure is NetworkFailure,
          ));
        },
        (statistics) {
          if (kDebugMode) {
            print('✅ [BLOC] Memory statistics loaded: $statistics');
          }
          // Get the statistics from the data envelope
          final statsData = statistics['statistics'] as Map<String, dynamic>;
          emit(MemoryStatisticsLoaded(statistics: statsData));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading memory statistics: $e');
      }
      emit(const MemoryVerseError(
        message: 'Failed to load statistics',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  // ==========================================================================
  // SUGGESTED VERSES EVENT HANDLERS
  // ==========================================================================

  /// Handles LoadSuggestedVersesEvent.
  ///
  /// Fetches curated suggested verses with optional category filter.
  Future<void> _onLoadSuggestedVerses(
    LoadSuggestedVersesEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '💡 [BLOC] Loading suggested verses (category: ${event.category}, language: ${event.language})');
      }

      emit(const SuggestedVersesLoading());

      // Parse category if provided
      SuggestedVerseCategory? categoryEnum;
      if (event.category != null && event.category!.isNotEmpty) {
        categoryEnum = SuggestedVerseCategory.fromString(event.category!);
      }

      final result = await getSuggestedVerses(
        params: GetSuggestedVersesParams(
          category: categoryEnum,
          language: event.language,
        ),
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ [BLOC] Load suggested verses failed: ${failure.message}');
          }
          emit(SuggestedVersesError(
            message: failure.message,
            code: failure.code,
          ));
        },
        (response) {
          if (kDebugMode) {
            print(
                '✅ [BLOC] Suggested verses loaded: ${response.verses.length} verses');
          }
          emit(SuggestedVersesLoaded(
            verses: response.verses,
            categories: response.categories,
            selectedCategory: categoryEnum,
            total: response.total,
          ));
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error loading suggested verses: $e');
      }
      emit(const SuggestedVersesError(
        message: 'Failed to load suggested verses',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Handles AddSuggestedVerseEvent.
  ///
  /// Adds a suggested verse to the user's memory deck using the manual verse flow.
  Future<void> _onAddSuggestedVerse(
    AddSuggestedVerseEvent event,
    Emitter<MemoryVerseState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('💡 [BLOC] Adding suggested verse: ${event.verseReference}');
      }

      emit(const MemoryVerseLoading(message: 'Adding verse to memory deck...'));

      // Use the existing addVerseManually use case
      final result = await addVerseManually(
        verseReference: event.verseReference,
        verseText: event.verseText,
        language: event.language,
      );

      await result.fold(
        (failure) async {
          if (kDebugMode) {
            print('❌ [BLOC] Add suggested verse failed: ${failure.message}');
          }

          // Check if operation was queued for offline sync
          if (failure is NetworkFailure && failure.code == 'OFFLINE_QUEUED') {
            emit(OperationQueued(
              message: 'Verse will be added when online',
              operationType: 'add_suggested',
            ));
          } else {
            emit(MemoryVerseError(
              message: failure.message,
              code: failure.code,
              isNetworkError: failure is NetworkFailure,
            ));
          }
        },
        (verse) async {
          if (kDebugMode) {
            print('✅ [BLOC] Suggested verse added: ${verse.verseReference}');
          }

          // Clear suggested verses cache to refresh "Already Added" status
          await suggestedVersesCacheService.clearCache();
          if (kDebugMode) {
            print('🗑️ [BLOC] Cleared suggested verses cache');
          }

          // Check if emit is still valid before emitting
          if (!emit.isDone) {
            emit(VerseAdded(
              verse: verse,
              message: '${verse.verseReference} added to memory deck!',
            ));
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BLOC] Unexpected error adding suggested verse: $e');
      }
      emit(const MemoryVerseError(
        message: 'Failed to add verse',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }
}
