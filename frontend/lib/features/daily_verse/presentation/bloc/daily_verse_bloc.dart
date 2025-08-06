import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/usecases/get_daily_verse.dart';
import '../../domain/usecases/get_cached_verse.dart';
import '../../domain/usecases/manage_verse_preferences.dart';
import 'daily_verse_event.dart';
import 'daily_verse_state.dart';

/// BLoC for managing daily verse state and operations
class DailyVerseBloc extends Bloc<DailyVerseEvent, DailyVerseState> {
  final GetDailyVerse getDailyVerse;
  final GetCachedVerse getCachedVerse;
  final GetPreferredLanguage getPreferredLanguage;
  final SetPreferredLanguage setPreferredLanguage;
  final GetCacheStats getCacheStats;
  final ClearVerseCache clearVerseCache;

  DailyVerseBloc({
    required this.getDailyVerse,
    required this.getCachedVerse,
    required this.getPreferredLanguage,
    required this.setPreferredLanguage,
    required this.getCacheStats,
    required this.clearVerseCache,
  }) : super(const DailyVerseInitial()) {
    on<LoadTodaysVerse>(_onLoadTodaysVerse);
    on<LoadVerseForDate>(_onLoadVerseForDate);
    on<ChangeVerseLanguage>(_onChangeVerseLanguage);
    on<SetPreferredVerseLanguage>(_onSetPreferredVerseLanguage);
    on<RefreshVerse>(_onRefreshVerse);
    on<LoadCachedVerse>(_onLoadCachedVerse);
    on<GetCacheStatsEvent>(_onGetCacheStats);
    on<ClearVerseCacheEvent>(_onClearVerseCache);
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
        getDailyVerse(GetDailyVerseParams.today()),
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
        getDailyVerse(GetDailyVerseParams.forDate(event.date)),
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
  void _onChangeVerseLanguage(
    ChangeVerseLanguage event,
    Emitter<DailyVerseState> emit,
  ) {
    // NULL SAFETY FIX: Add proper null checks and type validation
    final currentState = state;

    if (currentState is DailyVerseLoaded) {
      // Safe cast - we already verified the type
      emit(currentState.copyWith(currentLanguage: event.language));
    } else if (currentState is DailyVerseOffline) {
      // Safe cast - we already verified the type
      emit(currentState.copyWith(currentLanguage: event.language));
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
      await setPreferredLanguage(SetPreferredLanguageParams(language: event.language));

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

  // ===== PRIVATE HELPER METHODS =====
  // Extracted to reduce method length and improve code organization

  /// Gets preferred language with English fallback
  Future<VerseLanguage> _getPreferredLanguageWithFallback() async {
    final preferredLanguageResult = await getPreferredLanguage(NoParams());
    return preferredLanguageResult.fold(
      (failure) => VerseLanguage.english,
      (language) => language,
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

    result.fold(
      (failure) => emit(DailyVerseError(
        message: failure.message,
      )),
      (verse) => emit(DailyVerseLoaded(
        verse: verse,
        currentLanguage: preferredLanguage,
        preferredLanguage: preferredLanguage,
      )),
    );
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
            message: 'No cached verse available. Please connect to internet and try again.',
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
