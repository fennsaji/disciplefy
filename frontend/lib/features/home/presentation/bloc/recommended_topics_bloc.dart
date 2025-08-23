import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/models/app_language.dart';
import '../../data/services/recommended_guides_service.dart';
import 'recommended_topics_event.dart';
import 'recommended_topics_state.dart';

/// BLoC for managing recommended topics on the Home screen.
///
/// This BLoC follows the Single Responsibility Principle by handling
/// only recommended topics loading and management.
class RecommendedTopicsBloc
    extends Bloc<RecommendedTopicsEvent, RecommendedTopicsState> {
  final RecommendedGuidesService _topicsService;
  final LanguagePreferenceService _languagePreferenceService;

  // Language change subscription
  StreamSubscription<dynamic>? _languageChangeSubscription;

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

    // Listen for language preference changes
    _setupLanguageChangeListener();
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
  Future<void> _onRefreshRecommendedTopics(
    RefreshRecommendedTopics event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Force refresh with default parameters
    add(const LoadRecommendedTopics(
      limit: 6,
      forceRefresh: true,
    ));
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

  /// Setup listener for language preference changes from settings
  void _setupLanguageChangeListener() {
    _languageChangeSubscription =
        _languagePreferenceService.languageChanges.listen(
      (AppLanguage newLanguage) {
        // Trigger refresh when language changes with new language code
        add(LanguagePreferenceChanged(languageCode: newLanguage.code));
      },
    );
  }

  /// Handle language preference change from settings
  Future<void> _onLanguagePreferenceChanged(
    LanguagePreferenceChanged event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Clear cache and reload topics in new language
    _topicsService.clearCache();

    // Only reload if we have loaded topics
    final currentState = state;
    if (currentState is RecommendedTopicsLoaded) {
      // Reload topics with the new language preference
      add(LoadRecommendedTopics(
        limit: 6,
        language: event.languageCode,
        forceRefresh: true,
      ));
    }
  }

  @override
  Future<void> close() {
    // Cancel language change subscription
    _languageChangeSubscription?.cancel();

    // RecommendedGuidesService is a singleton managed by dependency injection
    // No need to dispose it here as it may be used by other parts of the app
    return super.close();
  }
}
