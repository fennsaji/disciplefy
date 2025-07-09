import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_saved_guides.dart';
import '../../domain/usecases/get_recent_guides.dart';
import '../../domain/usecases/save_guide.dart';
import '../../domain/usecases/remove_guide.dart';
import '../../domain/usecases/add_to_recent.dart';
import '../../domain/repositories/saved_guides_repository.dart';
import 'saved_guides_event.dart';
import 'saved_guides_state.dart';

class SavedGuidesBloc extends Bloc<SavedGuidesEvent, SavedGuidesState> {
  final GetSavedGuides getSavedGuides;
  final GetRecentGuides getRecentGuides;
  final SaveGuide saveGuide;
  final RemoveGuide removeGuide;
  final AddToRecent addToRecent;
  final SavedGuidesRepository repository;

  StreamSubscription? _savedGuidesSubscription;
  StreamSubscription? _recentGuidesSubscription;

  SavedGuidesBloc({
    required this.getSavedGuides,
    required this.getRecentGuides,
    required this.saveGuide,
    required this.removeGuide,
    required this.addToRecent,
    required this.repository,
  }) : super(SavedGuidesInitial()) {
    on<LoadSavedGuides>(_onLoadSavedGuides);
    on<LoadRecentGuides>(_onLoadRecentGuides);
    on<SaveGuideEvent>(_onSaveGuide);
    on<RemoveGuideEvent>(_onRemoveGuide);
    on<AddToRecentEvent>(_onAddToRecent);
    on<ClearAllSavedEvent>(_onClearAllSaved);
    on<ClearAllRecentEvent>(_onClearAllRecent);
    on<WatchSavedGuidesEvent>(_onWatchSavedGuides);
    on<WatchRecentGuidesEvent>(_onWatchRecentGuides);
  }

  Future<void> _onLoadSavedGuides(
    LoadSavedGuides event,
    Emitter<SavedGuidesState> emit,
  ) async {
    emit(SavedGuidesLoading());

    final savedResult = await getSavedGuides(NoParams());
    final recentResult = await getRecentGuides(NoParams());

    savedResult.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (savedGuides) {
        recentResult.fold(
          (failure) => emit(SavedGuidesError(message: failure.message)),
          (recentGuides) => emit(SavedGuidesLoaded(
            savedGuides: savedGuides,
            recentGuides: recentGuides,
          )),
        );
      },
    );
  }

  Future<void> _onLoadRecentGuides(
    LoadRecentGuides event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await getRecentGuides(NoParams());
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (guides) {
        if (state is SavedGuidesLoaded) {
          final currentState = state as SavedGuidesLoaded;
          emit(currentState.copyWith(recentGuides: guides));
        } else {
          emit(SavedGuidesLoaded(savedGuides: const [], recentGuides: guides));
        }
      },
    );
  }

  Future<void> _onSaveGuide(
    SaveGuideEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await saveGuide(SaveGuideParams(guide: event.guide));
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (_) => emit(const SavedGuidesActionSuccess(message: 'Guide saved successfully')),
    );
  }

  Future<void> _onRemoveGuide(
    RemoveGuideEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await removeGuide(RemoveGuideParams(guideId: event.guideId));
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (_) => emit(const SavedGuidesActionSuccess(message: 'Guide removed successfully')),
    );
  }

  Future<void> _onAddToRecent(
    AddToRecentEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await addToRecent(AddToRecentParams(guide: event.guide));
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (_) {}, // Silent success for recent additions
    );
  }

  Future<void> _onClearAllSaved(
    ClearAllSavedEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await repository.clearAllSaved();
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (_) => emit(const SavedGuidesActionSuccess(message: 'All saved guides cleared')),
    );
  }

  Future<void> _onClearAllRecent(
    ClearAllRecentEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await repository.clearAllRecent();
    result.fold(
      (failure) => emit(SavedGuidesError(message: failure.message)),
      (_) => emit(const SavedGuidesActionSuccess(message: 'Recent guides cleared')),
    );
  }

  Future<void> _onWatchSavedGuides(
    WatchSavedGuidesEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    await _savedGuidesSubscription?.cancel();
    _savedGuidesSubscription = repository.watchSavedGuides().listen(
      (savedGuides) {
        // Check if the emitter is still valid before emitting
        if (!emit.isDone) {
          if (state is SavedGuidesLoaded) {
            final currentState = state as SavedGuidesLoaded;
            emit(currentState.copyWith(savedGuides: savedGuides));
          } else {
            emit(SavedGuidesLoaded(savedGuides: savedGuides, recentGuides: const []));
          }
        }
      },
      onError: (error) {
        // Check if the emitter is still valid before emitting
        if (!emit.isDone) {
          emit(SavedGuidesError(message: error.toString()));
        }
      },
    );
  }

  Future<void> _onWatchRecentGuides(
    WatchRecentGuidesEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    await _recentGuidesSubscription?.cancel();
    _recentGuidesSubscription = repository.watchRecentGuides().listen(
      (recentGuides) {
        // Check if the emitter is still valid before emitting
        if (!emit.isDone) {
          if (state is SavedGuidesLoaded) {
            final currentState = state as SavedGuidesLoaded;
            emit(currentState.copyWith(recentGuides: recentGuides));
          } else {
            emit(SavedGuidesLoaded(savedGuides: const [], recentGuides: recentGuides));
          }
        }
      },
      onError: (error) {
        // Check if the emitter is still valid before emitting
        if (!emit.isDone) {
          emit(SavedGuidesError(message: error.toString()));
        }
      },
    );
  }

  @override
  Future<void> close() {
    _savedGuidesSubscription?.cancel();
    _recentGuidesSubscription?.cancel();
    return super.close();
  }
}