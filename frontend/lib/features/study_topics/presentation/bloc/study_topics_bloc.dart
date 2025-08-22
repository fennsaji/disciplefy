import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';
import '../../domain/repositories/study_topics_repository.dart';
import '../../domain/utils/topic_search_utils.dart';
import 'study_topics_event.dart';
import 'study_topics_state.dart';

/// BLoC for managing study topics screen state and operations.
class StudyTopicsBloc extends Bloc<StudyTopicsEvent, StudyTopicsState> {
  final StudyTopicsRepository _repository;

  // Internal state tracking
  List<RecommendedGuideTopic> _allLoadedTopics = [];
  List<String> _categories = [];
  StudyTopicsFilter _currentFilter = const StudyTopicsFilter();
  Timer? _searchDebounceTimer;

  StudyTopicsBloc({
    required StudyTopicsRepository repository,
  })  : _repository = repository,
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

  /// Handle initial loading of topics and categories
  Future<void> _onLoadStudyTopics(
    LoadStudyTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    emit(const StudyTopicsLoading());

    try {
      // Load categories first
      final categoriesLoaded = await _loadCategories(
        forceRefresh: event.forceRefresh,
        emit: emit,
      );
      if (!categoriesLoaded) return; // Error was emitted, return early

      // Set initial filter
      _currentFilter = event.initialFilter ?? const StudyTopicsFilter();

      // Load topics
      await _loadTopicsWithCurrentFilter(emit,
          forceRefresh: event.forceRefresh);
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS_BLOC] Unexpected error in load: $e');
      }
      emit(StudyTopicsError(
        message: 'An unexpected error occurred: $e',
      ));
    }
  }

  /// Handle category filtering
  Future<void> _onFilterByCategories(
    FilterByCategories event,
    Emitter<StudyTopicsState> emit,
  ) async {
    if (state is StudyTopicsLoaded) {
      final currentState = state as StudyTopicsLoaded;

      // Show filtering state
      emit(StudyTopicsFiltering(
        currentTopics: currentState.topics,
        categories: currentState.categories,
        currentFilter: currentState.currentFilter,
      ));

      // Update filter with new categories, reset offset for new search
      _currentFilter = _currentFilter.copyWith(
        selectedCategories: event.selectedCategories,
        offset: 0,
      );

      await _loadTopicsWithCurrentFilter(emit);
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

  /// Perform the actual search operation
  void _performSearch(Emitter<StudyTopicsState> emit) {
    // Handle search for different states that have topics loaded
    if (state is StudyTopicsLoaded ||
        state is StudyTopicsFiltering ||
        state is StudyTopicsLoadingMore ||
        state is StudyTopicsEmpty) {
      List<String> categories = [];
      bool hasMore = false;

      if (state is StudyTopicsLoaded) {
        final currentState = state as StudyTopicsLoaded;
        categories = currentState.categories;
        hasMore = currentState.hasMore;
      } else if (state is StudyTopicsFiltering) {
        final currentState = state as StudyTopicsFiltering;
        categories = currentState.categories;
        hasMore = false; // Filtering doesn't have hasMore
      } else if (state is StudyTopicsLoadingMore) {
        final currentState = state as StudyTopicsLoadingMore;
        categories = currentState.categories;
        hasMore = currentState.hasMore;
      } else if (state is StudyTopicsEmpty) {
        final currentState = state as StudyTopicsEmpty;
        categories = currentState.categories;
        hasMore = false; // Empty state doesn't have hasMore
      }

      // Apply client-side search filtering to loaded topics
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

      // Load next page
      final nextPageFilter = _currentFilter.copyWith(
        offset: _allLoadedTopics.length,
      );

      final result = await _repository.getAllTopics(filter: nextPageFilter);

      result.fold(
        (failure) {
          emit(StudyTopicsError(
            message: failure.message,
            errorCode: failure.code,
            isInitialLoadError: false,
          ));
        },
        (newTopics) {
          _allLoadedTopics.addAll(newTopics);

          // Apply current filters to all loaded topics
          final filteredTopics = _applyCurrentFilters(_allLoadedTopics);

          emit(StudyTopicsLoaded(
            topics: filteredTopics,
            categories: currentState.categories,
            currentFilter: _currentFilter,
            hasMore: newTopics.length >= _currentFilter.limit,
          ));
        },
      );
    }
  }

  /// Handle refresh operation
  Future<void> _onRefreshStudyTopics(
    RefreshStudyTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    // Clear repository cache and reload
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
    _currentFilter = const StudyTopicsFilter();
    _allLoadedTopics.clear();

    add(const LoadStudyTopics());
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

  /// Load categories from repository and handle failures
  Future<bool> _loadCategories({
    required bool forceRefresh,
    required Emitter<StudyTopicsState> emit,
  }) async {
    final categoriesResult = await _repository.getCategories(
      forceRefresh: forceRefresh,
    );

    if (categoriesResult.isLeft()) {
      final failure = categoriesResult.fold((l) => l, (r) => null)!;
      emit(StudyTopicsError(
        message: failure.message,
        errorCode: failure.code,
      ));
      return false;
    }

    _categories = categoriesResult.fold((l) => [], (r) => r);
    return true;
  }

  /// Load topics with current filter settings
  Future<void> _loadTopicsWithCurrentFilter(
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
