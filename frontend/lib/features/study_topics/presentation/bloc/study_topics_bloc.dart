import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';
import '../../domain/repositories/study_topics_repository.dart';
import '../../domain/utils/topic_search_utils.dart';
import 'study_topics_event.dart';
import 'study_topics_state.dart';

/// BLoC for managing study topics screen state and operations.
class StudyTopicsBloc extends Bloc<StudyTopicsEvent, StudyTopicsState> {
  final StudyTopicsRepository _repository;
  final LanguagePreferenceService _languagePreferenceService;

  // Internal state tracking
  List<RecommendedGuideTopic> _allLoadedTopics = [];
  List<String> _categories = [];
  StudyTopicsFilter _currentFilter = const StudyTopicsFilter();
  Timer? _searchDebounceTimer;

  StudyTopicsBloc({
    required StudyTopicsRepository repository,
    required LanguagePreferenceService languagePreferenceService,
  })  : _repository = repository,
        _languagePreferenceService = languagePreferenceService,
        super(const StudyTopicsInitial()) {
    on<LoadStudyTopics>(_onLoadStudyTopics);
    on<FilterByCategories>(_onFilterByCategories);
    on<SearchTopics>(_onSearchTopics);
    on<LoadMoreTopics>(_onLoadMoreTopics);
    on<RefreshStudyTopics>(_onRefreshStudyTopics);
    on<ClearFilters>(_onClearFilters);
    on<ClearError>(_onClearError);
    on<ChangeLanguage>(_onChangeLanguage);
  }

  /// Reusable async guard wrapper for unified try/catch/emit-error behavior
  Future<void> _withAsyncGuard(
    Emitter<StudyTopicsState> emit,
    Future<void> Function() operation,
    String operationName,
  ) async {
    try {
      await operation();
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS_BLOC] Error in $operationName: $e');
      }
      emit(StudyTopicsError(
        message: 'An unexpected error occurred: $e',
      ));
    }
  }

  /// Handle initial loading of topics and categories
  Future<void> _onLoadStudyTopics(
    LoadStudyTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    emit(const StudyTopicsLoading());

    await _withAsyncGuard(emit, () async {
      await _loadCategoriesInternal(forceRefresh: event.forceRefresh);

      // Get user's preferred language
      String languageCode = 'en'; // Default fallback
      try {
        final appLanguage =
            await _languagePreferenceService.getSelectedLanguage();
        languageCode = appLanguage.code;
      } catch (e) {
        if (kDebugMode) {
          print(
              '⚠️ [STUDY_TOPICS_BLOC] Failed to get language preference, using default: $e');
        }
      }

      // Initialize or update filter with user's language preference
      _currentFilter =
          (event.initialFilter ?? const StudyTopicsFilter()).copyWith(
        language: languageCode,
      );

      await _loadTopicsWithCurrentFilterInternal(
        emit,
        forceRefresh: event.forceRefresh,
      );
    }, 'load study topics');
  }

  /// Handle category filtering
  Future<void> _onFilterByCategories(
    FilterByCategories event,
    Emitter<StudyTopicsState> emit,
  ) async {
    if (state is StudyTopicsLoaded) {
      final currentState = state as StudyTopicsLoaded;

      emit(StudyTopicsFiltering(
        currentTopics: currentState.topics,
        categories: currentState.categories,
        currentFilter: currentState.currentFilter,
      ));

      _currentFilter = _currentFilter.copyWith(
        selectedCategories: event.selectedCategories,
        offset: 0,
      );

      await _loadTopicsWithCurrentFilterInternal(emit);
    }
  }

  /// Handle search query
  Future<void> _onSearchTopics(
    SearchTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    // Cancel any pending search timer
    _searchDebounceTimer?.cancel();

    // Update filter with new search query
    _currentFilter = _currentFilter.copyWith(searchQuery: event.query);

    // Perform search immediately since UI already handles debouncing
    _performSearch(emit);
  }

  /// Extract categories from current state
  List<String> _categoriesFromState() {
    if (state is StudyTopicsLoaded) {
      return (state as StudyTopicsLoaded).categories;
    } else if (state is StudyTopicsFiltering) {
      return (state as StudyTopicsFiltering).categories;
    } else if (state is StudyTopicsLoadingMore) {
      return (state as StudyTopicsLoadingMore).categories;
    } else if (state is StudyTopicsEmpty) {
      return (state as StudyTopicsEmpty).categories;
    }
    return [];
  }

  /// Extract hasMore flag from current state
  bool _hasMoreFromState() {
    if (state is StudyTopicsLoaded) {
      return (state as StudyTopicsLoaded).hasMore;
    } else if (state is StudyTopicsLoadingMore) {
      return (state as StudyTopicsLoadingMore).hasMore;
    }
    return false;
  }

  /// Perform the actual search operation
  void _performSearch(Emitter<StudyTopicsState> emit) {
    if (state is StudyTopicsLoaded ||
        state is StudyTopicsFiltering ||
        state is StudyTopicsLoadingMore ||
        state is StudyTopicsEmpty) {
      final categories = _categoriesFromState();
      final hasMore = _hasMoreFromState();

      final filteredTopics = TopicSearchUtils.applySearchFilter(
        _allLoadedTopics,
        _currentFilter.searchQuery,
      );

      if (filteredTopics.isEmpty && _currentFilter.hasFilters) {
        emit(StudyTopicsEmpty(
          categories: categories,
          currentFilter: _currentFilter,
        ));
      } else {
        emit(StudyTopicsLoaded(
          topics: filteredTopics,
          categories: categories,
          currentFilter: _currentFilter,
          hasMore: hasMore,
        ));
      }
    }
  }

  /// Handle loading more topics for pagination
  Future<void> _onLoadMoreTopics(
    LoadMoreTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    if (state is StudyTopicsLoaded) {
      final currentState = state as StudyTopicsLoaded;

      if (!currentState.hasMore) return;

      emit(StudyTopicsLoadingMore(
        currentTopics: currentState.topics,
        categories: currentState.categories,
        currentFilter: currentState.currentFilter,
        hasMore: currentState.hasMore,
      ));

      await _withAsyncGuard(emit, () async {
        final nextPageFilter = _currentFilter.copyWith(
          offset: _allLoadedTopics.length,
        );

        final result = await _repository.getAllTopics(filter: nextPageFilter);

        result.fold(
          (failure) {
            throw Exception('Failed to load more topics: ${failure.message}');
          },
          (newTopics) {
            _allLoadedTopics.addAll(newTopics);
            final filteredTopics = _applyCurrentFilters(_allLoadedTopics);

            emit(StudyTopicsLoaded(
              topics: filteredTopics,
              categories: currentState.categories,
              currentFilter: _currentFilter,
              hasMore: newTopics.length >= _currentFilter.limit,
            ));
          },
        );
      }, 'load more topics');
    }
  }

  /// Handle refresh operation
  Future<void> _onRefreshStudyTopics(
    RefreshStudyTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    _repository.clearCache();
    add(LoadStudyTopics(
      initialFilter: _currentFilter,
      forceRefresh: true,
    ));
  }

  /// Handle clearing all filters
  Future<void> _onClearFilters(
    ClearFilters event,
    Emitter<StudyTopicsState> emit,
  ) async {
    // Reset filter to default state
    _currentFilter = const StudyTopicsFilter();

    // Re-apply filters to existing cached topics instead of clearing cache
    if (_allLoadedTopics.isNotEmpty) {
      final filteredTopics = _applyCurrentFilters(_allLoadedTopics);

      emit(StudyTopicsLoaded(
        topics: filteredTopics,
        categories: _categories,
        currentFilter: _currentFilter,
        hasMore: _allLoadedTopics.length >= _currentFilter.limit,
      ));
    } else {
      // Only reload if no cached topics exist
      add(const LoadStudyTopics());
    }
  }

  /// Handle clearing error state
  void _onClearError(
    ClearError event,
    Emitter<StudyTopicsState> emit,
  ) {
    if (state is StudyTopicsError) {
      add(const LoadStudyTopics());
    }
  }

  /// Handle language change
  Future<void> _onChangeLanguage(
    ChangeLanguage event,
    Emitter<StudyTopicsState> emit,
  ) async {
    _currentFilter = _currentFilter.copyWith(language: event.language);
    _allLoadedTopics.clear();
    add(LoadStudyTopics(initialFilter: _currentFilter));
  }

  /// Load categories from repository (internal implementation)
  Future<void> _loadCategoriesInternal({required bool forceRefresh}) async {
    // Get the user's preferred language
    String languageCode = 'en'; // Default fallback
    try {
      final appLanguage =
          await _languagePreferenceService.getSelectedLanguage();
      languageCode = appLanguage.code;
    } catch (e) {
      if (kDebugMode) {
        print(
            '⚠️ [STUDY_TOPICS_BLOC] Failed to get language preference for categories, using default: $e');
      }
    }

    // Always fetch English categories for consistent filter chip styling
    final categoriesResult = await _repository.getCategories(
      forceRefresh: forceRefresh,
    );

    if (categoriesResult.isLeft()) {
      final failure = categoriesResult.fold((l) => l, (r) => null)!;
      throw Exception('Failed to load categories: ${failure.message}');
    }

    _categories = categoriesResult.fold((l) => [], (r) => r);
  }

  /// Load topics with current filter settings (internal implementation)
  Future<void> _loadTopicsWithCurrentFilterInternal(
    Emitter<StudyTopicsState> emit, {
    bool forceRefresh = false,
  }) async {
    final result = await _repository.getAllTopics(
      filter: _currentFilter,
      forceRefresh: forceRefresh,
    );

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => StudyTopicsError(
        message: message,
        errorCode: errorCode,
        isInitialLoadError: forceRefresh,
      ),
      onSuccess: (List<RecommendedGuideTopic> topics) {
        _allLoadedTopics = topics;

        Logger.info(
          'Loaded ${topics.length} study topics and ${_categories.length} categories',
          tag: 'STUDY_TOPICS',
          context: {
            'topic_count': topics.length,
            'category_count': _categories.length,
            'filter': _currentFilter.toString(),
          },
        );

        final filteredTopics = _applyCurrentFilters(topics);

        if (filteredTopics.isEmpty && _currentFilter.hasFilters) {
          emit(StudyTopicsEmpty(
            categories: _categories,
            currentFilter: _currentFilter,
          ));
        } else {
          emit(StudyTopicsLoaded(
            topics: filteredTopics,
            categories: _categories,
            currentFilter: _currentFilter,
            hasMore: topics.length >= _currentFilter.limit,
          ));
        }
      },
      operationName: 'load study topics',
    );
  }

  /// Apply current search filter to topics list
  List<RecommendedGuideTopic> _applyCurrentFilters(
    List<RecommendedGuideTopic> topics,
  ) {
    return TopicSearchUtils.applySearchFilter(
        topics, _currentFilter.searchQuery);
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}
