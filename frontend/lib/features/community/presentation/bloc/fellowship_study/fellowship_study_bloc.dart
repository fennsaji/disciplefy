import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../community/domain/repositories/community_repository.dart';
import 'fellowship_study_event.dart';
import 'fellowship_study_state.dart';

/// BLoC that manages the active learning-path study for a single fellowship.
///
/// Created and provided by [FellowshipHomeScreen] so its lifetime matches the
/// fellowship home screen.  Initialized via [FellowshipStudyInitialized] with
/// the fellowship data already known from the fellowship list.
class FellowshipStudyBloc
    extends Bloc<FellowshipStudyEvent, FellowshipStudyState> {
  final CommunityRepository _repository;

  FellowshipStudyBloc({required CommunityRepository repository})
      : _repository = repository,
        super(FellowshipStudyState.initial()) {
    on<FellowshipStudyInitialized>(_onInitialized);
    on<FellowshipStudyRefreshRequested>(_onRefreshRequested);
    on<FellowshipStudySetRequested>(_onSetRequested);
    on<FellowshipStudyAdvanceRequested>(_onAdvanceRequested);
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  void _onInitialized(
    FellowshipStudyInitialized event,
    Emitter<FellowshipStudyState> emit,
  ) {
    emit(state.copyWith(
      fellowshipId: event.fellowshipId,
      isMentor: event.isMentor,
      currentLearningPathId: event.currentLearningPathId,
      clearCurrentPathTitle: event.currentLearningPathId == null,
      currentPathTitle: event.currentPathTitle,
      currentGuideIndex: event.currentGuideIndex,
    ));
  }

  Future<void> _onRefreshRequested(
    FellowshipStudyRefreshRequested event,
    Emitter<FellowshipStudyState> emit,
  ) async {
    final fellowshipId = state.fellowshipId;
    if (fellowshipId.isEmpty) return;

    final result = await _repository.getFellowship(fellowshipId);
    result.fold(
      (_) {
        // Silently keep existing state on failure — screen already shows data.
      },
      (data) {
        final activeStudy = data['active_study'] as Map<String, dynamic>?;
        if (activeStudy != null) {
          emit(state.copyWith(
            currentLearningPathId: activeStudy['learning_path_id'] as String?,
            currentPathTitle: activeStudy['learning_path_title'] as String?,
            currentGuideIndex: activeStudy['current_guide_index'] as int?,
          ));
        } else {
          emit(state.copyWith(
            clearCurrentLearningPathId: true,
            clearCurrentPathTitle: true,
          ));
        }
      },
    );
  }

  Future<void> _onSetRequested(
    FellowshipStudySetRequested event,
    Emitter<FellowshipStudyState> emit,
  ) async {
    emit(state.copyWith(
      setStatus: FellowshipStudySetStatus.loading,
      clearSetError: true,
    ));

    final result = await _repository.setFellowshipStudy(
      fellowshipId: event.fellowshipId,
      learningPathId: event.learningPathId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        setStatus: FellowshipStudySetStatus.failure,
        setError: failure.message,
      )),
      (title) => emit(state.copyWith(
        setStatus: FellowshipStudySetStatus.success,
        currentLearningPathId: event.learningPathId,
        currentPathTitle: title.isNotEmpty ? title : event.learningPathTitle,
      )),
    );
  }

  Future<void> _onAdvanceRequested(
    FellowshipStudyAdvanceRequested event,
    Emitter<FellowshipStudyState> emit,
  ) async {
    emit(state.copyWith(
      advanceStatus: FellowshipStudyAdvanceStatus.loading,
      clearAdvanceError: true,
    ));

    final result = await _repository.advanceStudy(state.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        advanceStatus: FellowshipStudyAdvanceStatus.failure,
        advanceError: failure.message,
      )),
      (data) => emit(state.copyWith(
        advanceStatus: FellowshipStudyAdvanceStatus.success,
        studyCompleted: data['is_complete'] as bool? ?? false,
        currentGuideIndex: data['current_guide_index'] as int?,
        totalGuides: data['total_guides'] as int?,
        clearAdvanceError: true,
      )),
    );
  }
}
