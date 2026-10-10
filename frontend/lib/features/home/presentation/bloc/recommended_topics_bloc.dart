import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/models/app_language.dart';
import '../../data/services/recommended_guides_service.dart';
import 'recommended_topics_event.dart';
import 'recommended_topics_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// BLoC for managing recommended topics on the Home screen.
///
/// This BLoC follows the Single Responsibility Principle by handling
/// only recommended topics loading and management.
///
/// Supports both generic "Explore Topics" for unauthenticated users and
/// personalized "For You" topics for authenticated users.
class RecommendedTopicsBloc
    extends Bloc<RecommendedTopicsEvent, RecommendedTopicsState> {
  final RecommendedGuidesService _topicsService;
  final LanguagePreferenceService _languagePreferenceService;

  RecommendedTopicsBloc({
    required RecommendedGuidesService topicsService,
    required LanguagePreferenceService languagePreferenceService,
  })  : _topicsService = topicsService,
        _languagePreferenceService = languagePreferenceService,
        super(const RecommendedTopicsInitial()) {
    on<LoadRecommendedTopics>(_onLoadRecommendedTopics);
    on<RefreshRecommendedTopics>(_onRefreshRecommendedTopics);
    on<ClearRecommendedTopicsError>(_onClearError);
    on<LanguagePreferenceChanged>(_onLanguagePreferenceChanged);
    // Language changes are not subscribed to here: HomeBloc, which owns this
    // bloc, reloads "For You" in the study content language on both the app
    // and content language streams. Subscribing here as well fetched the
    // topics a second time, in the app language, racing HomeBloc's request.
  }

  /// Handle loading recommended topics with intelligent caching
  Future<void> _onLoadRecommendedTopics(
    LoadRecommendedTopics event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Skip loading state if we might have cached data (better UX)
    // Only emit loading state for force refresh or initial load
    final shouldShowLoading =
        event.forceRefresh || state is RecommendedTopicsInitial;

    if (shouldShowLoading) {
      emit(const RecommendedTopicsLoading());
    }

    final result = await _topicsService.getFilteredTopics(
      limit: event.limit ?? 6,
      category: event.category,
      difficulty: event.difficulty,
      language: event.language,
      forceRefresh: event.forceRefresh,
    );

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => RecommendedTopicsError(
        message: message,
        errorCode: errorCode,
      ),
      onSuccess: (dynamic topics) {
        Logger.info(
          'Loaded ${topics.length} recommended topics',
          tag: 'RECOMMENDED_TOPICS',
          context: {'topic_count': topics.length},
        );
        emit(RecommendedTopicsLoaded(topics: topics));
      },
      operationName: 'load recommended topics',
    );
  }

  /// Handle refreshing recommended topics (always forces fresh data)
  /// Reloads the recommended topics, bypassing the cache.
  Future<void> _onRefreshRecommendedTopics(
    RefreshRecommendedTopics event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    add(const LoadRecommendedTopics(forceRefresh: true));
  }

  /// Handle clearing errors
  void _onClearError(
    ClearRecommendedTopicsError event,
    Emitter<RecommendedTopicsState> emit,
  ) {
    if (state is RecommendedTopicsError) {
      emit(const RecommendedTopicsInitial());
    }
  }

  /// Handle language preference change from settings
  Future<void> _onLanguagePreferenceChanged(
    LanguagePreferenceChanged event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Clear cache and reload topics in new language
    _topicsService.clearCache();

    // Only reload if we have loaded topics
    if (state is RecommendedTopicsLoaded) {
      add(LoadRecommendedTopics(
        limit: 6,
        language: event.languageCode,
        forceRefresh: true,
      ));
    }
  }

  @override
  Future<void> close() {
    // RecommendedGuidesService is a singleton managed by dependency injection
    // No need to dispose it here as it may be used by other parts of the app
    return super.close();
  }
}
