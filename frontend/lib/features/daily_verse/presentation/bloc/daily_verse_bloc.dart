import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/usecases/get_daily_verse.dart';
import '../../domain/usecases/manage_verse_preferences.dart';
import 'daily_verse_event.dart';
import 'daily_verse_state.dart';

/// BLoC for managing daily verse state and operations
class DailyVerseBloc extends Bloc<DailyVerseEvent, DailyVerseState> {
  final GetDailyVerse getDailyVerse;
  final GetPreferredLanguage getPreferredLanguage;
  final SetPreferredLanguage setPreferredLanguage;
  final GetCacheStats getCacheStats;
  final ClearVerseCache clearVerseCache;

  DailyVerseBloc({
    required this.getDailyVerse,
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
      // Get preferred language first
      final preferredLanguageResult = await getPreferredLanguage(NoParams());
      final preferredLanguage = preferredLanguageResult.fold(
        (failure) => VerseLanguage.english,
        (language) => language,
      );

      // Get today's verse
      final result = await getDailyVerse(GetDailyVerseParams.today());

      result.fold(
        (failure) => emit(DailyVerseError(
          message: failure.message,
          hasCachedFallback: false,
        )),
        (verse) => emit(DailyVerseLoaded(
          verse: verse,
          currentLanguage: preferredLanguage,
          preferredLanguage: preferredLanguage,
          isFromCache: false,
          isServiceAvailable: true,
        )),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to load today\'s verse: $e',
        hasCachedFallback: false,
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
      // Get preferred language first
      final preferredLanguageResult = await getPreferredLanguage(NoParams());
      final preferredLanguage = preferredLanguageResult.fold(
        (failure) => VerseLanguage.english,
        (language) => language,
      );

      // Get verse for specific date
      final result = await getDailyVerse(GetDailyVerseParams.forDate(event.date));

      result.fold(
        (failure) => emit(DailyVerseError(
          message: failure.message,
          hasCachedFallback: false,
        )),
        (verse) => emit(DailyVerseLoaded(
          verse: verse,
          currentLanguage: preferredLanguage,
          preferredLanguage: preferredLanguage,
          isFromCache: false,
          isServiceAvailable: true,
        )),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to load verse for ${event.date}: $e',
        hasCachedFallback: false,
      ));
    }
  }

  /// Change displayed language (temporary, not persisted)
  void _onChangeVerseLanguage(
    ChangeVerseLanguage event,
    Emitter<DailyVerseState> emit,
  ) {
    if (state is DailyVerseLoaded) {
      final currentState = state as DailyVerseLoaded;
      emit(currentState.copyWith(currentLanguage: event.language));
    } else if (state is DailyVerseOffline) {
      final currentState = state as DailyVerseOffline;
      emit(currentState.copyWith(currentLanguage: event.language));
    }
  }

  /// Set preferred language (persisted)
  Future<void> _onSetPreferredVerseLanguage(
    SetPreferredVerseLanguage event,
    Emitter<DailyVerseState> emit,
  ) async {
    try {
      await setPreferredLanguage(SetPreferredLanguageParams(language: event.language));
      
      // Update current state with new preferred language
      if (state is DailyVerseLoaded) {
        final currentState = state as DailyVerseLoaded;
        emit(currentState.copyWith(
          currentLanguage: event.language,
          preferredLanguage: event.language,
        ));
      } else if (state is DailyVerseOffline) {
        final currentState = state as DailyVerseOffline;
        emit(currentState.copyWith(
          currentLanguage: event.language,
          preferredLanguage: event.language,
        ));
      }

      emit(DailyVerseLanguageUpdated(newLanguage: event.language));
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to save language preference: $e',
        hasCachedFallback: false,
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
    // This would require additional repository method for cache-only access
    // For now, emit offline state with fallback message
    emit(const DailyVerseError(
      message: 'No cached verse available. Please check your internet connection.',
      hasCachedFallback: false,
    ));
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
          hasCachedFallback: false,
        )),
        (stats) => emit(DailyVerseCacheStats(stats: stats)),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to get cache stats: $e',
        hasCachedFallback: false,
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
          hasCachedFallback: false,
        )),
        (_) => emit(const DailyVerseCacheCleared()),
      );
    } catch (e) {
      emit(DailyVerseError(
        message: 'Failed to clear cache: $e',
        hasCachedFallback: false,
      ));
    }
  }
}