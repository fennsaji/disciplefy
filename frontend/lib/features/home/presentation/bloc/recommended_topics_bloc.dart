import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/models/app_language.dart';
import '../../data/services/recommended_guides_service.dart';
import 'recommended_topics_event.dart';
import 'recommended_topics_state.dart';

/// BLoC for managing recommended topics on the Home screen.
///
/// This BLoC follows the Single Responsibility Principle by handling
/// only recommended topics loading and management.
///
/// Supports both generic "Explore Topics" for anonymous users and
/// personalized "For You" topics for authenticated users.
class RecommendedTopicsBloc
    extends Bloc<RecommendedTopicsEvent, RecommendedTopicsState> {
  final RecommendedGuidesService _topicsService;
  final LanguagePreferenceService _languagePreferenceService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  // Key for storing prompt dismissal in local storage
  static const String _promptDismissedKey = 'personalization_prompt_dismissed';

  // Language change subscription
  StreamSubscription<dynamic>? _languageChangeSubscription;

  // Track if personalization prompt was dismissed (loaded from storage)
  bool _promptDismissed = false;

  RecommendedTopicsBloc({
    required RecommendedGuidesService topicsService,
    required LanguagePreferenceService languagePreferenceService,
    required SharedPreferences prefs,
    AuthService? authService,
  })  : _topicsService = topicsService,
        _languagePreferenceService = languagePreferenceService,
        _prefs = prefs,
        _authService = authService ?? AuthService(),
        super(const RecommendedTopicsInitial()) {
    // Load persisted dismissal state
    _promptDismissed = _prefs.getBool(_promptDismissedKey) ?? false;
    on<LoadRecommendedTopics>(_onLoadRecommendedTopics);
    on<RefreshRecommendedTopics>(_onRefreshRecommendedTopics);
    on<ClearRecommendedTopicsError>(_onClearError);
    on<LanguagePreferenceChanged>(_onLanguagePreferenceChanged);
    on<LoadForYouTopics>(_onLoadForYouTopics);
    on<DismissPersonalizationPrompt>(_onDismissPersonalizationPrompt);
    on<InvalidateForYouCache>(_onInvalidateForYouCache);

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
  /// Uses LoadForYouTopics to get personalized topics for authenticated users
  Future<void> _onRefreshRecommendedTopics(
    RefreshRecommendedTopics event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Force refresh with personalized "For You" topics
    add(const LoadForYouTopics(
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
      // Check if user is authenticated to decide which endpoint to use
      final isAuthenticatedUser = _authService.isAuthenticated &&
          _authService.currentUser != null &&
          !_authService.currentUser!.isAnonymous;
      if (isAuthenticatedUser) {
        add(LoadForYouTopics(
          language: event.languageCode,
          forceRefresh: true,
        ));
      } else {
        add(LoadRecommendedTopics(
          limit: 6,
          language: event.languageCode,
          forceRefresh: true,
        ));
      }
    }
  }

  /// Handle loading personalized "For You" topics for authenticated users.
  ///
  /// This uses the personalized topics endpoint that considers the user's
  /// questionnaire responses and study history for recommendations.
  Future<void> _onLoadForYouTopics(
    LoadForYouTopics event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    // Check if user is authenticated (non-anonymous)
    final isAnonymousUser = !_authService.isAuthenticated ||
        _authService.currentUser == null ||
        _authService.currentUser!.isAnonymous;
    if (isAnonymousUser) {
      // Fall back to regular topics for anonymous users
      Logger.info(
        'User is anonymous, falling back to generic topics',
        tag: 'RECOMMENDED_TOPICS',
      );
      add(LoadRecommendedTopics(
        limit: event.limit,
        language: event.language,
        forceRefresh: event.forceRefresh,
      ));
      return;
    }

    // Skip loading state if we might have cached data (better UX)
    final shouldShowLoading =
        event.forceRefresh || state is RecommendedTopicsInitial;

    if (shouldShowLoading) {
      emit(const RecommendedTopicsLoading());
    }

    final result = await _topicsService.getForYouTopics(
      limit: event.limit,
      language: event.language,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (failure) {
        Logger.error(
          'Failed to load personalized topics: ${failure.message}',
          tag: 'RECOMMENDED_TOPICS',
        );
        emit(RecommendedTopicsError(
          message: failure.message,
          errorCode: failure.code,
        ));
      },
      (forYouResult) {
        Logger.info(
          'Loaded ${forYouResult.topics.length} personalized topics',
          tag: 'RECOMMENDED_TOPICS',
          context: {
            'topic_count': forYouResult.topics.length,
            'questionnaire_completed': forYouResult.hasCompletedQuestionnaire,
          },
        );

        // Determine if we should show the personalization prompt
        // Show prompt if:
        // 1. User hasn't completed questionnaire
        // 2. Prompt wasn't dismissed (persisted in local storage)
        final showPrompt =
            !forYouResult.hasCompletedQuestionnaire && !_promptDismissed;

        emit(RecommendedTopicsLoaded(
          topics: forYouResult.topics,
          showPersonalizationPrompt: showPrompt,
          isPersonalized: forYouResult.hasCompletedQuestionnaire,
        ));
      },
    );
  }

  /// Handle dismissing the personalization prompt card.
  ///
  /// This persists the dismissal to local storage so the prompt
  /// won't reappear on page reload for the same device/browser.
  Future<void> _onDismissPersonalizationPrompt(
    DismissPersonalizationPrompt event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    _promptDismissed = true;

    // Persist dismissal to local storage
    await _prefs.setBool(_promptDismissedKey, true);
    Logger.info(
      'Personalization prompt dismissed and persisted to local storage',
      tag: 'RECOMMENDED_TOPICS',
    );

    final currentState = state;
    if (currentState is RecommendedTopicsLoaded) {
      emit(currentState.copyWith(showPersonalizationPrompt: false));
    }
  }

  /// Handle invalidating the "For You" cache after study guide completion.
  ///
  /// This clears only the "For You" cache entries, ensuring that completed
  /// topics are refreshed on next load without affecting other cached data.
  Future<void> _onInvalidateForYouCache(
    InvalidateForYouCache event,
    Emitter<RecommendedTopicsState> emit,
  ) async {
    Logger.info(
      'Invalidating For You cache after study guide completion',
      tag: 'RECOMMENDED_TOPICS',
    );

    await _topicsService.clearForYouCache();

    // Note: We don't reload topics here to avoid unnecessary API calls
    // The cache will be refreshed on next LoadForYouTopics event
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
