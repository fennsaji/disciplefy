import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/learning_paths_repository.dart';
import 'learning_paths_event.dart';
import 'learning_paths_state.dart';

/// BLoC for managing learning paths.
///
/// Handles loading, enrolling, and viewing learning paths
/// which are curated collections of topics for structured learning.
class LearningPathsBloc extends Bloc<LearningPathsEvent, LearningPathsState> {
  final LearningPathsRepository _repository;

  LearningPathsBloc({
    required LearningPathsRepository repository,
  })  : _repository = repository,
        super(const LearningPathsInitial()) {
    on<LoadLearningPaths>(_onLoadLearningPaths);
    on<LoadLearningPathDetails>(_onLoadLearningPathDetails);
    on<EnrollInLearningPath>(_onEnrollInLearningPath);
    on<RefreshLearningPaths>(_onRefreshLearningPaths);
    on<ClearLearningPathsCache>(_onClearCache);
  }

  Future<void> _onLoadLearningPaths(
    LoadLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    // Don't reload if already loaded (unless force refresh)
    if (state is LearningPathsLoaded && !event.forceRefresh) {
      return;
    }

    emit(const LearningPathsLoading());

    final result = await _repository.getLearningPaths(
      language: event.language,
      includeEnrolled: event.includeEnrolled,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (failure) => emit(LearningPathsError(
        message: failure.message,
      )),
      (pathsResult) {
        if (pathsResult.paths.isEmpty) {
          emit(const LearningPathsEmpty());
        } else {
          final enrolledPaths =
              pathsResult.paths.where((p) => p.isEnrolled).toList();
          emit(LearningPathsLoaded(
            paths: pathsResult.paths,
            enrolledPaths: enrolledPaths,
            total: pathsResult.total,
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
      (failure) => emit(LearningPathsError(
        message: failure.message,
      )),
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
    // Keep current state while refreshing if we have data
    final previousState = state;
    final hadData = previousState is LearningPathsLoaded;

    if (!hadData) {
      emit(const LearningPathsLoading());
    }

    final result = await _repository.getLearningPaths(
      language: event.language,
      forceRefresh: true,
    );

    result.fold(
      (failure) {
        if (hadData) {
          emit(LearningPathsError(
            message: failure.message,
            isInitialLoadError: false,
          ));
        } else {
          emit(LearningPathsError(
            message: failure.message,
          ));
        }
      },
      (pathsResult) {
        if (pathsResult.paths.isEmpty) {
          emit(const LearningPathsEmpty());
        } else {
          final enrolledPaths =
              pathsResult.paths.where((p) => p.isEnrolled).toList();
          emit(LearningPathsLoaded(
            paths: pathsResult.paths,
            enrolledPaths: enrolledPaths,
            total: pathsResult.total,
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
}
