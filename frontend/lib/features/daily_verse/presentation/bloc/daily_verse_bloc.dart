import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/entities/daily_verse_streak.dart';
import '../../domain/usecases/get_daily_verse.dart';
import '../../domain/usecases/get_cached_verse.dart';
import '../../domain/usecases/manage_verse_preferences.dart';
import '../../domain/usecases/get_default_language.dart';
import '../../domain/repositories/streak_repository.dart';
import 'daily_verse_event.dart';
import 'daily_verse_state.dart';
import '../../../../core/utils/logger.dart';

/// BLoC for managing daily verse state and operations
class DailyVerseBloc extends Bloc<DailyVerseEvent, DailyVerseState> {
  final GetDailyVerse getDailyVerse;
  final GetCachedVerse getCachedVerse;
  final GetPreferredLanguage getPreferredLanguage;
  final SetPreferredLanguage setPreferredLanguage;
  final GetCacheStats getCacheStats;
  final ClearVerseCache clearVerseCache;
  final GetDefaultLanguage getDefaultLanguage;
  final LanguagePreferenceService languagePreferenceService;
  final StreakRepository streakRepository;

  // Language change subscription
  StreamSubscription<dynamic>? _languageChangeSubscription;

  DailyVerseBloc({
    required this.getDailyVerse,
    required this.getCachedVerse,
    required this.getPreferredLanguage,
    required this.setPreferredLanguage,
    required this.getCacheStats,
    required this.clearVerseCache,
    required this.getDefaultLanguage,
    required this.languagePreferenceService,
    required this.streakRepository,
  }) : super(const DailyVerseInitial()) {
    on<LoadTodaysVerse>(_onLoadTodaysVerse);
    on<LoadVerseForDate>(_onLoadVerseForDate);
    on<ChangeVerseLanguage>(_onChangeVerseLanguage);
    on<SetPreferredVerseLanguage>(_onSetPreferredVerseLanguage);
    on<RefreshVerse>(_onRefreshVerse);
    on<LoadCachedVerse>(_onLoadCachedVerse);
    on<GetCacheStatsEvent>(_onGetCacheStats);
    on<ClearVerseCacheEvent>(_onClearVerseCache);
    on<LanguagePreferenceChanged>(_onLanguagePreferenceChanged);
    on<MarkVerseAsViewed>(_onMarkVerseAsViewed);

    // Listen for language preference changes
    _setupLanguageChangeListener();
  }

  /// Setup listener for language preference changes from settings
  void _setupLanguageChangeListener() {
    _languageChangeSubscription =
        languagePreferenceService.languageChanges.listen(
      (appLanguage) {
        // Convert AppLanguage to VerseLanguage and trigger reload
        add(const LanguagePreferenceChanged());
      },
    );
  }

  @override
  Future<void> close() {
    _languageChangeSubscription?.cancel();
    return super.close();
  }

  /// Load today's verse
  Future<void> _onLoadTodaysVerse(
    LoadTodaysVerse event,
    Emitter<DailyVerseState> emit,
  ) async {
    emit(DailyVerseLoading(isRefreshing: event.forceRefresh));

    try {
      final preferredLanguage = await _getPreferredLanguageWithFallback();
      await _loadAndEmitVerse(
        getDailyVerse(GetDailyVerseParams.today(preferredLanguage)),
        preferredLanguage,
        emit,
        errorMessage: 'Failed to load today\'s verse',
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to load today\'s verse: $e',
      ));
    }
  }

  /// Load verse for specific date
  Future<void> _onLoadVerseForDate(
    LoadVerseForDate event,
    Emitter<DailyVerseState> emit,
  ) async {
    emit(DailyVerseLoading(isRefreshing: event.forceRefresh));

    try {
      final preferredLanguage = await _getPreferredLanguageWithFallback();
      await _loadAndEmitVerse(
        getDailyVerse(
            GetDailyVerseParams.forDate(event.date, preferredLanguage)),
        preferredLanguage,
        emit,
        errorMessage: 'Failed to load verse for ${event.date}',
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to load verse for ${event.date}: $e',
      ));
    }
  }

  /// Change displayed language (temporary, not persisted)
  /// This now fetches a new verse with the selected language
  Future<void> _onChangeVerseLanguage(
    ChangeVerseLanguage event,
    Emitter<DailyVerseState> emit,
  ) async {
    // Get the current state to preserve the date
    final currentState = state;
    DateTime? currentDate;

    if (currentState is DailyVerseLoaded) {
      currentDate = currentState.verse.date;
    } else if (currentState is DailyVerseOffline) {
      currentDate = currentState.verse.date;
    }

    if (currentDate != null) {
      // Fetch verse with new language
      emit(DailyVerseLoading(isRefreshing: true));

      try {
        await _loadAndEmitVerse(
          getDailyVerse(
              GetDailyVerseParams.forDate(currentDate, event.language)),
          event.language,
          emit,
          errorMessage: 'Failed to load verse in ${event.language.displayName}',
        );
      } catch (e) {
        emit(DailyVerseError(
          message: 'Failed to load verse in ${event.language.displayName}: $e',
        ));
      }
    } else {
      // Invalid state for language change - emit error
      emit(const DailyVerseError(
        message: 'Cannot change language: No verse is currently loaded',
      ));
    }
  }

  /// Set preferred language (persisted)
  Future<void> _onSetPreferredVerseLanguage(
    SetPreferredVerseLanguage event,
    Emitter<DailyVerseState> emit,
  ) async {
    try {
      // Save the preference first
      await setPreferredLanguage(
          SetPreferredLanguageParams(language: event.language));

      // Update current state with new preferred language
      _updateStateWithNewLanguage(event.language, emit);

      emit(DailyVerseLanguageUpdated(newLanguage: event.language));
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to save language preference: $e',
      ));
    }
  }

  /// Refresh current verse
  Future<void> _onRefreshVerse(
    RefreshVerse event,
    Emitter<DailyVerseState> emit,
  ) async {
    add(const LoadTodaysVerse(forceRefresh: true));
  }

  /// Load cached verse only (offline mode)
  Future<void> _onLoadCachedVerse(
    LoadCachedVerse event,
    Emitter<DailyVerseState> emit,
  ) async {
    emit(const DailyVerseLoading());

    try {
      final preferredLanguage = await _getPreferredLanguageWithFallback();
      final date = event.date ?? DateTime.now();

      await _loadAndEmitCachedVerse(date, preferredLanguage, emit);
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to load cached verse: $e',
      ));
    }
  }

  /// Get cache statistics
  Future<void> _onGetCacheStats(
    GetCacheStatsEvent event,
    Emitter<DailyVerseState> emit,
  ) async {
    try {
      final result = await getCacheStats(NoParams());

      result.fold(
        (failure) => emit(DailyVerseError(
          message: 'Failed to get cache stats: ${failure.message}',
        )),
        (stats) => emit(DailyVerseCacheStats(stats: stats)),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to get cache stats: $e',
      ));
    }
  }

  /// Clear verse cache
  Future<void> _onClearVerseCache(
    ClearVerseCacheEvent event,
    Emitter<DailyVerseState> emit,
  ) async {
    try {
      final result = await clearVerseCache(NoParams());

      result.fold(
        (failure) => emit(DailyVerseError(
          message: 'Failed to clear cache: ${failure.message}',
        )),
        (_) => emit(const DailyVerseCacheCleared()),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to clear cache: $e',
      ));
    }
  }

  /// Handle language preference change from settings
  Future<void> _onLanguagePreferenceChanged(
    LanguagePreferenceChanged event,
    Emitter<DailyVerseState> emit,
  ) async {
    // Only reload if we have a loaded or offline verse
    final currentState = state;
    if (currentState is DailyVerseLoaded || currentState is DailyVerseOffline) {
      // Reload today's verse with new language preference
      add(const LoadTodaysVerse());
    }
  }

  // ===== PRIVATE HELPER METHODS =====
  // Extracted to reduce method length and improve code organization

  /// Gets preferred language with English fallback
  /// Uses unified language preference service first, then falls back to local preferences
  Future<VerseLanguage> _getPreferredLanguageWithFallback() async {
    // Try to get default language from unified service first
    final defaultLanguageResult = await getDefaultLanguage(NoParams());

    return await defaultLanguageResult.fold(
      (failure) async {
        // If default language fails, try local preferences
        final preferredLanguageResult = await getPreferredLanguage(NoParams());
        return preferredLanguageResult.fold(
          (failure) => VerseLanguage.english,
          (language) => language,
        );
      },
      (language) async => language,
    );
  }

  /// Loads verse and emits appropriate state based on result
  Future<void> _loadAndEmitVerse(
    Future<dynamic> verseOperation,
    VerseLanguage preferredLanguage,
    Emitter<DailyVerseState> emit, {
    required String errorMessage,
  }) async {
    final result = await verseOperation;

    await result.fold(
      (failure) async => emit(DailyVerseError(
        message: failure.message,
      )),
      (verse) async {
        // Load current streak for authenticated users
        final streak = await _loadStreak();

        emit(DailyVerseLoaded(
          verse: verse,
          currentLanguage: preferredLanguage,
          preferredLanguage: preferredLanguage,
          streak: streak,
        ));

        // Automatically mark verse as viewed for today (update streak)
        if (verse.isToday) {
          add(const MarkVerseAsViewed());
        }
      },
    );
  }

  /// Load current user's streak (returns null if not authenticated)
  Future<dynamic> _loadStreak() async {
    try {
      return await streakRepository.getStreak();
    } catch (e) {
      // Silently fail - streak is optional feature
      return null;
    }
  }

  /// Mark verse as viewed and update streak
  Future<void> _onMarkVerseAsViewed(
    MarkVerseAsViewed event,
    Emitter<DailyVerseState> emit,
  ) async {
    // Only update streak if we have a loaded verse
    final currentState = state;
    if (currentState is! DailyVerseLoaded) return;

    try {
      final previousStreak = currentState.streak;
      final updatedStreak = await streakRepository.markVerseAsViewed();

      // Emit updated state with new streak
      emit(currentState.copyWith(streak: updatedStreak));

      // Check for milestone achievement or streak lost
      await _checkAndSendStreakNotifications(previousStreak, updatedStreak);
    } catch (e) {
      // Silently fail - streak is optional feature
      // Don't emit error state as verse is still valid
    }
  }

  /// Check if milestone reached or streak lost, and send notification
  Future<void> _checkAndSendStreakNotifications(
    DailyVerseStreak? previousStreak,
    DailyVerseStreak updatedStreak,
  ) async {
    try {
      final previousCount = previousStreak?.currentStreak ?? 0;
      final newCount = updatedStreak.currentStreak;

      // Check for milestone achievement (7, 30, 100, 365 days)
      const milestones = [7, 30, 100, 365];
      for (final milestone in milestones) {
        if (newCount == milestone && previousCount < milestone) {
          // Milestone reached! Send notification
          await _sendStreakNotification(
            notificationType: 'milestone',
            streakCount: milestone,
          );
          break; // Only send one milestone notification per update
        }
      }

      // Check for streak lost (streak reset from > 0 to 1)
      if (previousCount > 1 && newCount == 1) {
        // Streak was lost! Send notification
        await _sendStreakNotification(
          notificationType: 'streak_lost',
          streakCount: previousCount,
        );
      }
    } catch (e) {
      // Silently fail - notifications are optional
    }
  }

  /// Send streak notification via backend Edge Function
  Future<void> _sendStreakNotification({
    required String notificationType,
    required int streakCount,
  }) async {
    try {
      // Get current language from state
      String languageCode = 'en'; // Default to English
      final currentState = state;

      if (currentState is DailyVerseLoaded) {
        languageCode = currentState.currentLanguage.code;
      } else if (currentState is DailyVerseOffline) {
        languageCode = currentState.currentLanguage.code;
      }

      // Call repository to send notification via Edge Function
      final success = await streakRepository.sendStreakNotification(
        notificationType: notificationType,
        streakCount: streakCount,
        language: languageCode,
      );

      if (success) {
        Logger.debug(
            'Streak notification sent: $notificationType for $streakCount days');
      }
    } catch (e) {
      // Silently fail - notifications are optional
      Logger.debug('Failed to send streak notification: $e');
    }
  }

  /// Loads cached verse and emits offline state
  Future<void> _loadAndEmitCachedVerse(
    DateTime date,
    VerseLanguage preferredLanguage,
    Emitter<DailyVerseState> emit,
  ) async {
    final result = await getCachedVerse(GetCachedVerseParams.forDate(date));

    result.fold(
      (failure) => emit(DailyVerseError(
        message: failure.message,
      )),
      (cachedVerse) {
        // NULL SAFETY FIX: Explicit null check with proper error handling
        if (cachedVerse != null) {
          emit(DailyVerseOffline(
            verse: cachedVerse,
            currentLanguage: preferredLanguage,
            preferredLanguage: preferredLanguage,
          ));
        } else {
          emit(const DailyVerseError(
            message:
                'No cached verse available. Please connect to internet and try again.',
          ));
        }
      },
    );
  }

  /// Updates current state with new language preference
  void _updateStateWithNewLanguage(
    VerseLanguage language,
    Emitter<DailyVerseState> emit,
  ) {
    // NULL SAFETY FIX: Safe state access with proper type checking
    final currentState = state;

    // Update current state with new preferred language
    if (currentState is DailyVerseLoaded) {
      // Safe cast - we already verified the type
      emit(currentState.copyWith(
        currentLanguage: language,
        preferredLanguage: language,
      ));
    } else if (currentState is DailyVerseOffline) {
      // Safe cast - we already verified the type
      emit(currentState.copyWith(
        currentLanguage: language,
        preferredLanguage: language,
      ));
    }
    // Note: If no verse is loaded, we just save the preference without state update
  }
}
