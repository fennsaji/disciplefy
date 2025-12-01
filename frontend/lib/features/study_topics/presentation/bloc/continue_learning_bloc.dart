import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/topic_progress_repository.dart';
import 'continue_learning_event.dart';
import 'continue_learning_state.dart';

/// BLoC for managing continue learning section.
///
/// Handles loading in-progress topics that the user has started
/// but not yet completed, enabling them to continue where they left off.
class ContinueLearningBloc
    extends Bloc<ContinueLearningEvent, ContinueLearningState> {
  final TopicProgressRepository _repository;

  ContinueLearningBloc({
    required TopicProgressRepository repository,
  })  : _repository = repository,
        super(const ContinueLearningInitial()) {
    on<LoadContinueLearning>(_onLoadContinueLearning);
    on<RefreshContinueLearning>(_onRefreshContinueLearning);
    on<ClearContinueLearningCache>(_onClearCache);
  }

  Future<void> _onLoadContinueLearning(
    LoadContinueLearning event,
    Emitter<ContinueLearningState> emit,
  ) async {
    // Don't reload if already loaded (unless force refresh)
    if (state is ContinueLearningLoaded && !event.forceRefresh) {
      return;
    }

    emit(const ContinueLearningLoading());

    final result = await _repository.getInProgressTopics(
      language: event.language,
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(ContinueLearningError(
        message: failure.message,
      )),
      (topics) {
        if (topics.isEmpty) {
          emit(const ContinueLearningEmpty());
        } else {
          emit(ContinueLearningLoaded(topics: topics));
        }
      },
    );
  }

  Future<void> _onRefreshContinueLearning(
    RefreshContinueLearning event,
    Emitter<ContinueLearningState> emit,
  ) async {
    // Keep current state while refreshing if we have data
    final previousState = state;
    final hadData = previousState is ContinueLearningLoaded;

    if (!hadData) {
      emit(const ContinueLearningLoading());
    }

    final result = await _repository.getInProgressTopics(
      language: event.language,
    );

    result.fold(
      (failure) => emit(ContinueLearningError(
        message: failure.message,
      )),
      (topics) {
        if (topics.isEmpty) {
          emit(const ContinueLearningEmpty());
        } else {
          emit(ContinueLearningLoaded(topics: topics));
        }
      },
    );
  }

  void _onClearCache(
    ClearContinueLearningCache event,
    Emitter<ContinueLearningState> emit,
  ) {
    emit(const ContinueLearningInitial());
  }
}
