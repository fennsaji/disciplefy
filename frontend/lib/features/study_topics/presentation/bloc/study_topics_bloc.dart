import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';
import '../../domain/repositories/study_topics_repository.dart';
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
      final categoriesResult = await _repository.getCategories(
        forceRefresh: event.forceRefresh,
      );

      if (categoriesResult.isLeft()) {
        final failure = categoriesResult.fold((l) => l, (r) => null)!;
        emit(StudyTopicsError(
          message: failure.message,
          errorCode: failure.code,
        ));
        return;
      }

      _categories = categoriesResult.fold((l) => [], (r) => r);

      // Set initial filter
      _currentFilter = event.initialFilter ?? const StudyTopicsFilter();

      // Load topics
      final topicsResult = await _repository.getAllTopics(
        filter: _currentFilter,
        forceRefresh: event.forceRefresh,
      );

      ErrorHandler.handleEitherResult(
        result: topicsResult,
        emit: emit,
        createErrorState: (message, errorCode) => StudyTopicsError(
          message: message,
          errorCode: errorCode,
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

          if (topics.isEmpty) {
            emit(StudyTopicsEmpty(
              categories: _categories,
              currentFilter: _currentFilter,
            ));
          } else {
            emit(StudyTopicsLoaded(
              topics: topics,
              categories: _categories,
              currentFilter: _currentFilter,
              hasMore: topics.length >= _currentFilter.limit,
            ));
          }
        },
        operationName: 'load study topics',
      );
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

  /// Handle search query with debouncing
  Future<void> _onSearchTopics(
    SearchTopics event,
    Emitter<StudyTopicsState> emit,
  ) async {
    // Cancel previous search timer
    _searchDebounceTimer?.cancel();

    // Update filter immediately for UI responsiveness
    _currentFilter = _currentFilter.copyWith(searchQuery: event.query);

    // Debounce search to avoid excessive filtering
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!emit.isDone) {
        _performSearch(emit);
      }
    });
  }

  /// Perform the actual search operation
  void _performSearch(Emitter<StudyTopicsState> emit) {
    if (state is StudyTopicsLoaded) {
      final currentState = state as StudyTopicsLoaded;

      // Apply client-side search filtering to loaded topics
      final filteredTopics = _applySearchFilter(
        _allLoadedTopics,
        _currentFilter.searchQuery,
      );

      if (filteredTopics.isEmpty && _currentFilter.hasFilters) {
        emit(StudyTopicsEmpty(
          categories: currentState.categories,
          currentFilter: _currentFilter,
        ));
      } else {
        emit(currentState.copyWith(
          topics: filteredTopics,
          currentFilter: _currentFilter,
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

  /// Load topics with current filter settings
  Future<void> _loadTopicsWithCurrentFilter(
    Emitter<StudyTopicsState> emit,
  ) async {
    final result = await _repository.getAllTopics(filter: _currentFilter);

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => StudyTopicsError(
        message: message,
        errorCode: errorCode,
        isInitialLoadError: false,
      ),
      onSuccess: (List<RecommendedGuideTopic> topics) {
        _allLoadedTopics = topics;

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
      operationName: 'filter study topics',
    );
  }

  /// Apply current search filter to topics list
  List<RecommendedGuideTopic> _applyCurrentFilters(
    List<RecommendedGuideTopic> topics,
  ) {
    return _applySearchFilter(topics, _currentFilter.searchQuery);
  }

  /// Apply search filter to topics list
  List<RecommendedGuideTopic> _applySearchFilter(
    List<RecommendedGuideTopic> topics,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return topics;
    }

    final query = searchQuery.toLowerCase();
    return topics.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.category.toLowerCase().contains(query) ||
          topic.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}
