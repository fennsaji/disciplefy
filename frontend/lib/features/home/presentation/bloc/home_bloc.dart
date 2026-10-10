import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';

import 'home_event.dart';
import 'home_state.dart';
import 'recommended_topics_bloc.dart';
import 'recommended_topics_event.dart' as topics_events;
import 'recommended_topics_state.dart' as topics_states;
import 'home_study_generation_bloc.dart';
import 'home_study_generation_event.dart' as generation_events;
import 'home_study_generation_state.dart' as generation_states;
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/utils/logger.dart';
import '../../../study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_cache_scope.dart';
import '../../../study_topics/data/services/learning_path_download_service.dart';
import '../../../study_topics/domain/entities/learning_path.dart';
import '../../../study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// Refactored BLoC for coordinating Home screen concerns.
///
/// This BLoC now follows the Single Responsibility Principle by delegating
/// specific responsibilities to specialized BLoCs while coordinating their interactions.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final RecommendedTopicsBloc _topicsBloc;
  final HomeStudyGenerationBloc _studyGenerationBloc;
  final LanguagePreferenceService _languagePreferenceService;
  final LearningPathsRepository _learningPathsRepository;
  final LearningPathDownloadService _downloadService;

  late final StreamSubscription _topicsSubscription;
  late final StreamSubscription _studyGenerationSubscription;
  StreamSubscription<dynamic>? _languageChangeSubscription;
  StreamSubscription<dynamic>? _contentLanguageChangeSubscription;

  /// User + content language ([LearningCacheScope.scopeFor]) the active path
  /// in the state belongs to. A path from another scope — another account
  /// after a sign-in, or the old language after a switch — is never kept on
  /// screen while the right one loads.
  String? _activePathScope;

  /// Content language the last language-change reload was requested for.
  String? _languageReloadRequestedFor;

  HomeBloc({
    required RecommendedTopicsBloc topicsBloc,
    required HomeStudyGenerationBloc studyGenerationBloc,
    required LanguagePreferenceService languagePreferenceService,
    required LearningPathsRepository learningPathsRepository,
    required LearningPathDownloadService downloadService,
  })  : _topicsBloc = topicsBloc,
        _studyGenerationBloc = studyGenerationBloc,
        _languagePreferenceService = languagePreferenceService,
        _learningPathsRepository = learningPathsRepository,
        _downloadService = downloadService,
        super(const HomeCombinedState()) {
    // Subscribe to child BLoC states and trigger events instead of direct emit
    _topicsSubscription = _topicsBloc.stream.listen((state) {
      add(TopicsStateChangedEvent(state));
    });
    _studyGenerationSubscription = _studyGenerationBloc.stream.listen((state) {
      add(StudyGenerationStateChangedEvent(state));
    });

    // Register event handlers
    on<LoadRecommendedTopics>(_onLoadRecommendedTopics);
    on<RefreshRecommendedTopics>(_onRefreshRecommendedTopics);
    on<GenerateStudyGuideFromVerse>(_onGenerateStudyGuideFromVerse);
    on<GenerateStudyGuideFromTopic>(_onGenerateStudyGuideFromTopic);
    on<ClearHomeError>(_onClearHomeError);
    // One at a time: the app-language and content-language streams can both
    // fire for one change, and the second must see the first's request.
    on<LanguagePreferenceChanged>(
      _onLanguagePreferenceChanged,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<LoadActiveLearningPath>(_onLoadActiveLearningPath);

    // Register internal coordination events
    on<TopicsStateChangedEvent>(_onTopicsStateChanged);
    on<StudyGenerationStateChangedEvent>(_onStudyGenerationStateChanged);

    // Listen for language preference changes
    _setupLanguageChangeListener();
  }

  /// Handle topics state changes through proper event system
  void _onTopicsStateChanged(
    TopicsStateChangedEvent event,
    Emitter<HomeState> emit,
  ) {
    final topicsState = event.topicsState;
    final currentState = state;
    if (currentState is HomeCombinedState) {
      switch (topicsState) {
        case topics_states.RecommendedTopicsLoading _:
          emit(currentState.copyWith(
            isLoadingTopics: true,
            clearTopicsError: true,
          ));
          break;
        case final topics_states.RecommendedTopicsLoaded loaded:
          emit(currentState.copyWith(
            isLoadingTopics: false,
            topics: loaded.topics,
            clearTopicsError: true,
          ));
          break;
        case final topics_states.RecommendedTopicsError error:
          emit(currentState.copyWith(
            isLoadingTopics: false,
            topicsError: error.message,
          ));
          break;
        default:
          break;
      }
    }
  }

  /// Handle study generation state changes through proper event system
  void _onStudyGenerationStateChanged(
    StudyGenerationStateChangedEvent event,
    Emitter<HomeState> emit,
  ) {
    final generationState = event.generationState;
    final currentState = state;
    if (currentState is HomeCombinedState) {
      switch (generationState) {
        case final generation_states.HomeStudyGenerationInProgress progress:
          emit(currentState.copyWith(
            isGeneratingStudyGuide: true,
            generationInput: progress.input,
            generationInputType: progress.inputType,
            clearGenerationError: true,
          ));
          break;
        case final generation_states.HomeStudyGenerationSuccess success:
          // First, update combined state to stop generating
          emit(currentState.copyWith(
            isGeneratingStudyGuide: false,
            clearGenerationError: true,
          ));
          // Then emit navigation state, but preserve topics by extending HomeCombinedState
          emit(HomeStudyGuideGeneratedCombined(
            studyGuide: success.studyGuide,
            topics: currentState.topics,
            isLoadingTopics: currentState.isLoadingTopics,
            topicsError: currentState.topicsError,
            generationInput: currentState.generationInput,
            generationInputType: currentState.generationInputType,
            activeLearningPath: currentState.activeLearningPath,
            learningPathReason: currentState.learningPathReason,
            isLoadingActivePath: currentState.isLoadingActivePath,
            activePathSummary: currentState.activePathSummary,
          ));
          break;
        case final generation_states.HomeStudyGenerationError error:
          emit(currentState.copyWith(
            isGeneratingStudyGuide: false,
            generationError: error.message,
          ));
          break;
        default:
          break;
      }
    }
  }

  /// Handle loading recommended topics by delegating to topics BLoC
  Future<void> _onLoadRecommendedTopics(
    LoadRecommendedTopics event,
    Emitter<HomeState> emit,
  ) async {
    // Get study content language preference (not app UI language)
    String? languageCode;
    try {
      final appLanguage =
          await _languagePreferenceService.getStudyContentLanguage();
      languageCode = appLanguage.code;
    } catch (e) {
      // Fall back to default language if getting study content language fails
      languageCode = 'en';
    }

    _topicsBloc.add(topics_events.LoadRecommendedTopics(
      limit: event.limit,
      category: event.category,
      difficulty: event.difficulty,
      language: languageCode,
      forceRefresh: event.forceRefresh,
    ));
  }

  /// Handle refreshing recommended topics by delegating to topics BLoC
  void _onRefreshRecommendedTopics(
    RefreshRecommendedTopics event,
    Emitter<HomeState> emit,
  ) {
    _topicsBloc.add(const topics_events.RefreshRecommendedTopics());
  }

  /// Handle generating study guide from verse by delegating to generation BLoC
  void _onGenerateStudyGuideFromVerse(
    GenerateStudyGuideFromVerse event,
    Emitter<HomeState> emit,
  ) {
    _studyGenerationBloc.add(generation_events.GenerateStudyGuideFromVerse(
      verseReference: event.verseReference,
      language: event.language,
    ));
  }

  /// Handle generating study guide from topic by delegating to generation BLoC
  void _onGenerateStudyGuideFromTopic(
    GenerateStudyGuideFromTopic event,
    Emitter<HomeState> emit,
  ) {
    _studyGenerationBloc.add(generation_events.GenerateStudyGuideFromTopic(
      topicName: event.topicName,
      language: event.language,
    ));
  }

  /// Handle clearing errors by delegating to child BLoCs
  void _onClearHomeError(
    ClearHomeError event,
    Emitter<HomeState> emit,
  ) {
    _topicsBloc.add(const topics_events.ClearRecommendedTopicsError());
    _studyGenerationBloc
        .add(const generation_events.ClearHomeStudyGenerationError());
  }

  /// Handle a change of the app language or the study content language.
  ///
  /// Both streams can fire for one change (content on "Default" follows the
  /// app language), so content already in the resolved content language is
  /// not reloaded again.
  Future<void> _onLanguagePreferenceChanged(
    LanguagePreferenceChanged event,
    Emitter<HomeState> emit,
  ) async {
    String languageCode = 'en';
    try {
      languageCode =
          (await _languagePreferenceService.getStudyContentLanguage()).code;
    } catch (_) {}
    final alreadyInLanguage =
        _activePathScope == LearningCacheScope.scopeFor(languageCode);
    if (alreadyInLanguage || _languageReloadRequestedFor == languageCode) {
      return;
    }
    _languageReloadRequestedFor = languageCode;

    Logger.info(
      'Language preference changed, refreshing all home content',
      tag: 'HOME_BLOC',
    );

    // Reload the active learning path (translations are language-dependent)
    add(const LoadActiveLearningPath(
      forceRefresh: true,
    ));
  }

  /// Handle loading the recommended learning path for the For You section.
  ///
  /// The backend's next-path engine picks it: the active (in-progress) path,
  /// else the first path of the user's growth goal list, else a featured one.
  ///
  /// Stale-while-revalidate: the path already on screen (or, on a cold start,
  /// the copy persisted for this user and language) is shown at once, and a
  /// fresh one is always fetched — progress changes — and swapped in.
  Future<void> _onLoadActiveLearningPath(
    LoadActiveLearningPath event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is HomeCombinedState) {
      // Get study content language preference (not app UI language)
      String languageCode = 'en';
      try {
        final appLanguage =
            await _languagePreferenceService.getStudyContentLanguage();
        languageCode = appLanguage.code;
      } catch (e) {
        Logger.warning(
          'Failed to get study content language preference, using default',
          tag: 'HOME_BLOC',
        );
      }

      await _showCachedActivePath(languageCode, emit);

      // Fetch recommended learning path (works for all users). Always fresh:
      // whatever is on screen came from a cache.
      Logger.info(
        'Fetching recommended learning path (requested forceRefresh: ${event.forceRefresh})',
        tag: 'HOME_BLOC',
      );
      final result = await _learningPathsRepository.getRecommendedPath(
        language: languageCode,
        forceRefresh: true,
      );

      if (result.isLeft()) {
        final failure = result.fold((f) => f, (_) => null)!;
        Logger.error(
          'Failed to load recommended learning path: ${ErrorMessageSanitizer.sanitize(failure)}',
          tag: 'HOME_BLOC',
        );

        // A path already shown for this user and language (the one on
        // screen, or the persisted copy) stays: a failed refresh never
        // blanks the enrolled path. Only sign-out / a scope change clears it.
        final shown = state;
        if (shown is HomeCombinedState &&
            shown.activeLearningPath != null &&
            _activePathScope == LearningCacheScope.scopeFor(languageCode)) {
          emit(shown.copyWith(isLoadingActivePath: false));
          return;
        }

        // Offline fallback: try to find any learning path that has downloaded
        // content from the Hive-persisted categories cache.
        final offlinePath = await _findOfflineAvailablePath(languageCode);

        final updatedState = state;
        if (updatedState is HomeCombinedState) {
          if (offlinePath != null) {
            _activePathScope = LearningCacheScope.scopeFor(languageCode);
            emit(updatedState.copyWith(
              isLoadingActivePath: false,
              activeLearningPath: offlinePath,
              learningPathReason:
                  LearningPathRecommendationReason.offlineAvailable,
              clearActivePathSummary: true,
            ));
          } else {
            _activePathScope = null;
            emit(updatedState.copyWith(
              isLoadingActivePath: false,
              clearActiveLearningPath: true,
            ));
          }
        }
      } else {
        final recommended = result.fold((_) => null, (r) => r)!;
        var path = recommended.path;
        var reason = recommended.reason;

        // If the API returned a path with 0% progress (e.g. auth timing issue
        // caused the backend to treat the user as anonymous), cross-reference
        // with the enrolled paths cache which uses the correct SQL function.
        if (!path.isEnrolled || path.progressPercentage == 0) {
          final enrolledResult =
              await _learningPathsRepository.getEnrolledPaths(
            language: languageCode,
          );
          enrolledResult.fold((_) => null, (enrolled) {
            final match = enrolled
                .where((p) => p.id == path.id && p.isEnrolled)
                .firstOrNull;
            if (match != null && match.progressPercentage > 0) {
              Logger.info(
                'Enriching recommended path with enrolled data: ${match.progressPercentage}%',
                tag: 'HOME_BLOC',
              );
              path = path.copyWith(
                isEnrolled: true,
                progressPercentage: match.progressPercentage,
              );
              reason = LearningPathRecommendationReason.active;
            }
          });
        }

        // Home's active path is the user's enrolled path, if any: a guest
        // keeps that one and every other path locks. Never cleared here: a
        // guest cannot leave a path, and the record is per user.
        if (path.isEnrolled) GuestPathEnrollment.record(path.id);

        Logger.info(
          'Loaded recommended learning path: ${path.title} (reason: ${reason.name}, progress: ${path.progressPercentage}%)',
          tag: 'HOME_BLOC',
        );

        final updatedState = state;
        if (updatedState is HomeCombinedState) {
          _activePathScope = LearningCacheScope.scopeFor(languageCode);
          emit(updatedState.copyWith(
            isLoadingActivePath: false,
            activeLearningPath: path,
            learningPathReason: reason,
            activePathSummary: recommended.summary,
            clearActivePathSummary: recommended.summary == null,
          ));
        }
      }
    }
  }

  /// Puts the right path on screen before the network call: keeps the one
  /// shown when it belongs to this user and [languageCode], else shows the
  /// cached copy for them, else clears it (the loading indicator shows).
  Future<void> _showCachedActivePath(
    String languageCode,
    Emitter<HomeState> emit,
  ) async {
    final scope = LearningCacheScope.scopeFor(languageCode);
    final current = state;
    if (current is! HomeCombinedState) return;

    if (current.activeLearningPath != null && _activePathScope == scope) {
      emit(current.copyWith(isLoadingActivePath: true));
      return;
    }

    RecommendedPathResult? cached;
    try {
      cached = await _learningPathsRepository.getCachedRecommendedPath(
        language: languageCode,
      );
    } catch (e) {
      Logger.debug('Cached recommended path unavailable: $e');
    }

    final latest = state;
    if (latest is! HomeCombinedState) return;
    if (cached != null) {
      _activePathScope = scope;
      emit(latest.copyWith(
        isLoadingActivePath: true,
        activeLearningPath: cached.path,
        learningPathReason: cached.reason,
        activePathSummary: cached.summary,
        clearActivePathSummary: cached.summary == null,
      ));
    } else {
      _activePathScope = null;
      emit(latest.copyWith(
        isLoadingActivePath: true,
        clearActiveLearningPath: true,
      ));
    }
  }

  /// Tries to find a learning path that has at least one downloaded guide,
  /// using the Hive-persisted categories cache (survives app restarts).
  /// Returns null if no downloaded path is found or cache is empty.
  Future<LearningPath?> _findOfflineAvailablePath(String language) async {
    try {
      final downloads = _downloadService.cachedDownloads
          .where(
              (m) => m.topics.any((t) => t.status == TopicDownloadStatus.done))
          .toList();

      if (downloads.isEmpty) return null;

      final downloadedIds = downloads.map((m) => m.learningPathId).toSet();

      final result = await _learningPathsRepository.getLearningPathCategories(
        language: language,
      );

      return result.fold(
        (_) => null,
        (cats) {
          for (final cat in cats.categories) {
            for (final path in cat.paths) {
              if (downloadedIds.contains(path.id)) return path;
            }
          }
          return null;
        },
      );
    } catch (e) {
      Logger.warning('Offline path fallback failed: $e', tag: 'HOME_BLOC');
      return null;
    }
  }

  /// Setup listeners for app language and study content language changes.
  /// Content on "Default" follows the app language, so either can change it.
  void _setupLanguageChangeListener() {
    _languageChangeSubscription =
        _languagePreferenceService.languageChanges.listen(
      (AppLanguage newLanguage) {
        // Trigger refresh when language changes
        add(const LanguagePreferenceChanged());
      },
    );
    _contentLanguageChangeSubscription =
        _languagePreferenceService.studyContentLanguageChanges.listen(
      (AppLanguage newLanguage) => add(const LanguagePreferenceChanged()),
    );
  }

  @override
  Future<void> close() async {
    // Cancel stream subscriptions first
    await _topicsSubscription.cancel();
    await _studyGenerationSubscription.cancel();
    await _languageChangeSubscription?.cancel();
    await _contentLanguageChangeSubscription?.cancel();

    // Close child BLoCs
    await _topicsBloc.close();
    await _studyGenerationBloc.close();

    // Close parent BLoC
    return super.close();
  }
}
