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
        ));
      },
    );
  }
}
