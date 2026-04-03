import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import 'learning_paths_event.dart';
import 'learning_paths_state.dart';

/// BLoC for managing learning paths.
///
/// Handles loading, enrolling, and viewing learning paths
/// which are curated collections of topics for structured learning.
class LearningPathsBloc extends Bloc<LearningPathsEvent, LearningPathsState> {
  final LearningPathsRepository _repository;

  static const _categoryPageSize = 4;
  static const _pathsPerCategory = 3;

  LearningPathsBloc({
    required LearningPathsRepository repository,
  })  : _repository = repository,
        super(const LearningPathsInitial()) {
    on<LoadLearningPaths>(_onLoadLearningPaths);
    on<LoadLearningPathDetails>(_onLoadLearningPathDetails);
    on<EnrollInLearningPath>(_onEnrollInLearningPath);
    on<RefreshLearningPaths>(_onRefreshLearningPaths);
    on<ClearLearningPathsCache>(_onClearCache);
    on<LoadMoreCategories>(_onLoadMoreCategories);
    on<LoadMorePathsForCategory>(_onLoadMorePathsForCategory);
    on<SearchLearningPaths>(_onSearchLearningPaths);
    on<LoadFlatLearningPaths>(_onLoadFlatLearningPaths);
    on<LoadPersonalizedPaths>(_onLoadPersonalizedPaths);
  }

  Future<void> _onLoadLearningPaths(
    LoadLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    if (state is LearningPathsLoaded && !event.forceRefresh) {
      return;
    }

    emit(const LearningPathsLoading());

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      includeEnrolled: event.includeEnrolled,
      forceRefresh: event.forceRefresh,
    );

    // Preserve personalizedPaths from prior state (if any) so they survive
    // the LoadLearningPaths re-emission.
    final priorPersonalizedPaths = state is LearningPathsLoaded
        ? (state as LearningPathsLoaded).personalizedPaths
        : <LearningPath>[];

    result.fold(
      (failure) => emit(LearningPathsError(message: failure.message)),
      (categoriesResult) {
        if (!categoriesResult.categories.any((c) => c.paths.isNotEmpty)) {
          emit(const LearningPathsEmpty());
        } else {
          final enrolledPaths = categoriesResult.categories
              .expand((c) => c.paths)
              .where((p) => p.isEnrolled)
              .toList();
          emit(LearningPathsLoaded(
            categories: categoriesResult.categories,
            enrolledPaths: enrolledPaths,
            hasMoreCategories: categoriesResult.hasMoreCategories,
            nextCategoryOffset: categoriesResult.nextCategoryOffset,
            personalizedPaths: priorPersonalizedPaths,
          ));
        }
      },
    );
  }

  Future<void> _onLoadLearningPathDetails(
    LoadLearningPathDetails event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(LearningPathDetailLoading(pathId: event.pathId));

    final result = await _repository.getLearningPathDetails(
      pathId: event.pathId,
      language: event.language,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (failure) => emit(LearningPathsError(message: failure.message)),
      (pathDetail) => emit(LearningPathDetailLoaded(pathDetail: pathDetail)),
    );
  }

  Future<void> _onEnrollInLearningPath(
    EnrollInLearningPath event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(LearningPathEnrolling(pathId: event.pathId));

    final result = await _repository.enrollInPath(pathId: event.pathId);

    result.fold(
      (failure) => emit(LearningPathsError(
        message: failure.message,
        isInitialLoadError: false,
      )),
      (enrollment) => emit(LearningPathEnrolled(enrollment: enrollment)),
    );
  }

  Future<void> _onRefreshLearningPaths(
    RefreshLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final hadData = state is LearningPathsLoaded;
    if (!hadData) {
      emit(const LearningPathsLoading());
    }

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      forceRefresh: true,
    );

    result.fold(
      (failure) {
        emit(LearningPathsError(
          message: failure.message,
          isInitialLoadError: !hadData,
        ));
      },
      (categoriesResult) {
        if (!categoriesResult.categories.any((c) => c.paths.isNotEmpty)) {
          emit(const LearningPathsEmpty());
        } else {
          final enrolledPaths = categoriesResult.categories
              .expand((c) => c.paths)
              .where((p) => p.isEnrolled)
              .toList();
          // Intentionally omit personalizedPaths (defaults to []) so the
          // For You section uses fresh language-correct paths immediately.
          // LoadPersonalizedPaths (dispatched alongside RefreshLearningPaths)
          // will repopulate it once the language-aware fetch completes.
          emit(LearningPathsLoaded(
            categories: categoriesResult.categories,
            enrolledPaths: enrolledPaths,
            hasMoreCategories: categoriesResult.hasMoreCategories,
            nextCategoryOffset: categoriesResult.nextCategoryOffset,
          ));
        }
      },
    );
  }

  void _onClearCache(
    ClearLearningPathsCache event,
    Emitter<LearningPathsState> emit,
  ) {
    _repository.clearCache();
    emit(const LearningPathsInitial());
  }

  Future<void> _onLoadMoreCategories(
    LoadMoreCategories event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is! LearningPathsLoaded ||
        !current.hasMoreCategories ||
        current.isFetchingMoreCategories) {
      return;
    }

    emit(current.copyWith(isFetchingMoreCategories: true));

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      categoryOffset: current.nextCategoryOffset,
      forceRefresh: true,
    );

    result.fold(
      (failure) => emit(current.copyWith(isFetchingMoreCategories: false)),
      (categoriesResult) {
        final combined = [
          ...current.categories,
          ...categoriesResult.categories,
        ];
        final enrolledPaths =
            combined.expand((c) => c.paths).where((p) => p.isEnrolled).toList();
        emit(LearningPathsLoaded(
          categories: combined,
          enrolledPaths: enrolledPaths,
          hasMoreCategories: categoriesResult.hasMoreCategories,
          nextCategoryOffset: categoriesResult.nextCategoryOffset,
          personalizedPaths: current.personalizedPaths,
        ));
      },
    );
  }

  Future<void> _onLoadMorePathsForCategory(
    LoadMorePathsForCategory event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is! LearningPathsLoaded) return;

    final catIndex =
        current.categories.indexWhere((c) => c.name == event.category);
    if (catIndex == -1) return;

    final cat = current.categories[catIndex];
    if (!cat.hasMoreInCategory ||
        current.loadingCategories.contains(event.category)) {
      return;
    }

    // Mark category as loading
    emit(current.copyWith(
      loadingCategories: [...current.loadingCategories, event.category],
    ));

    final result = await _repository.getLearningPathsForCategory(
      category: event.category,
      language: event.language,
      offset: cat.nextPathOffset,
    );

    final updated = state;
    if (updated is! LearningPathsLoaded) return;

    result.fold(
      (failure) {
        // Remove loading indicator on failure
        emit(updated.copyWith(
          loadingCategories: updated.loadingCategories
              .where((c) => c != event.category)
              .toList(),
        ));
      },
      (newCatData) {
        final updatedCategories =
            List<LearningPathCategory>.from(updated.categories);
        final idx =
            updatedCategories.indexWhere((c) => c.name == event.category);
        if (idx != -1) {
          final existing = updatedCategories[idx];
          updatedCategories[idx] = existing.copyWith(
            paths: [...existing.paths, ...newCatData.paths],
            hasMoreInCategory: newCatData.hasMoreInCategory,
            nextPathOffset: newCatData.nextPathOffset,
          );
        }
        final enrolledPaths = updatedCategories
            .expand((c) => c.paths)
            .where((p) => p.isEnrolled)
            .toList();
        emit(LearningPathsLoaded(
          categories: updatedCategories,
          enrolledPaths: enrolledPaths,
          hasMoreCategories: updated.hasMoreCategories,
          nextCategoryOffset: updated.nextCategoryOffset,
          loadingCategories: updated.loadingCategories
              .where((c) => c != event.category)
              .toList(),
          personalizedPaths: updated.personalizedPaths,
        ));
      },
    );
  }

  /// Loads all paths as a flat list (no category grouping, no per-category limit).
  ///
  /// Used by the fellowship picker so that completed paths (sorted last in the
  /// category API) are never cut off by the 3-paths-per-category limit.
  Future<void> _onLoadFlatLearningPaths(
    LoadFlatLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is LearningPathsLoaded) {
      emit(current.copyWith(isSearching: true, searchQuery: ''));
    } else {
      emit(const LearningPathsLoading());
    }

    final result = await _repository.getLearningPaths(
      language: event.language,
      limit: 100,
      forceRefresh: true,
      fellowshipId: event.fellowshipId,
    );

    result.fold(
      (failure) => emit(LearningPathsError(message: failure.message)),
      (data) => emit(LearningPathsLoaded(
        categories: const [],
        searchResults: data.paths,
        searchQuery: '',
      )),
    );
  }

  /// Fetches personalized paths and stores them in the current loaded state.
  ///
  /// Fires-and-forgets if the BLoC is not yet in [LearningPathsLoaded].
  /// The For You section will pick up the update on the next rebuild.
  Future<void> _onLoadPersonalizedPaths(
    LoadPersonalizedPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final result = await _repository.getPersonalizedPaths(
      language: event.language,
      limit: event.limit,
    );

    result.fold(
      (_) => null, // Personalization is supplementary — never block the UI
      (paths) {
        final current = state;
        if (current is LearningPathsLoaded) {
          emit(current.copyWith(personalizedPaths: paths));
        }
      },
    );
  }

  /// Handles search queries.
  ///
  /// When [event.query] is empty, clears search state and returns to the
  /// normal category listing. Otherwise, fetches matching paths from the
  /// server (bypassing cache) using the user's content language and emits
  /// results into [LearningPathsLoaded.searchResults].
  Future<void> _onSearchLearningPaths(
    SearchLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;

    // Empty query → restore normal listing
    if (event.query.isEmpty) {
      if (current is LearningPathsLoaded) {
        emit(current.copyWith(clearSearch: true));
      }
      return;
    }

    // Keep the existing categories visible while search loads
    if (current is LearningPathsLoaded) {
      emit(current.copyWith(
        searchQuery: event.query,
        isSearching: true,
      ));
    }

    // Search using the user's content language
    final result = await _repository.getLearningPaths(
      language: event.language,
      forceRefresh: true,
      limit: 50,
      search: event.query,
    );

    final paths = result.fold((_) => <LearningPath>[], (data) => data.paths);

    final afterSearch = state;
    if (afterSearch is LearningPathsLoaded) {
      emit(afterSearch.copyWith(
        searchQuery: event.query,
        searchResults: paths,
        isSearching: false,
      ));
    } else {
      // Bloc was reset while we were searching — emit a fresh loaded state
      emit(LearningPathsLoaded(
        categories: const [],
        searchQuery: event.query,
        searchResults: paths,
      ));
    }
  }
}
