import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_reflection.dart';
import '../../domain/usecases/get_reflection.dart';
import '../../domain/usecases/get_reflection_for_guide.dart';
import '../../domain/usecases/get_reflection_stats.dart';
import '../../domain/usecases/list_reflections.dart';
import '../../domain/usecases/save_reflection.dart';
import 'reflections_event.dart';
import 'reflections_state.dart';

/// BLoC for managing reflection operations.
///
/// This BLoC handles all reflection-related business logic including
/// saving, retrieving, listing, and deleting reflections.
class ReflectionsBloc extends Bloc<ReflectionsEvent, ReflectionsState> {
  final SaveReflection _saveReflection;
  final GetReflection _getReflection;
  final GetReflectionForGuide _getReflectionForGuide;
  final ListReflections _listReflections;
  final DeleteReflection _deleteReflection;
  final GetReflectionStats _getReflectionStats;

  ReflectionsBloc({
    required SaveReflection saveReflection,
    required GetReflection getReflection,
    required GetReflectionForGuide getReflectionForGuide,
    required ListReflections listReflections,
    required DeleteReflection deleteReflection,
    required GetReflectionStats getReflectionStats,
  })  : _saveReflection = saveReflection,
        _getReflection = getReflection,
        _getReflectionForGuide = getReflectionForGuide,
        _listReflections = listReflections,
        _deleteReflection = deleteReflection,
        _getReflectionStats = getReflectionStats,
        super(const ReflectionsInitial()) {
    on<SaveReflectionRequested>(_onSaveReflection);
    on<GetReflectionRequested>(_onGetReflection);
    on<GetReflectionForGuideRequested>(_onGetReflectionForGuide);
    on<ListReflectionsRequested>(_onListReflections);
    on<DeleteReflectionRequested>(_onDeleteReflection);
    on<GetReflectionStatsRequested>(_onGetReflectionStats);
  }

  Future<void> _onSaveReflection(
    SaveReflectionRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _saveReflection(event.params);

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (session) => emit(ReflectionSaved(session)),
    );
  }

  Future<void> _onGetReflection(
    GetReflectionRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _getReflection(event.reflectionId);

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (session) => emit(ReflectionLoaded(session)),
    );
  }

  Future<void> _onGetReflectionForGuide(
    GetReflectionForGuideRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _getReflectionForGuide(event.studyGuideId);

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (session) => emit(ReflectionLoaded(session)),
    );
  }

  Future<void> _onListReflections(
    ListReflectionsRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _listReflections(event.params);

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (listResult) => emit(ReflectionsListLoaded(listResult)),
    );
  }

  Future<void> _onDeleteReflection(
    DeleteReflectionRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _deleteReflection(event.reflectionId);

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (_) => emit(const ReflectionDeleted()),
    );
  }

  Future<void> _onGetReflectionStats(
    GetReflectionStatsRequested event,
    Emitter<ReflectionsState> emit,
  ) async {
    emit(const ReflectionsLoading());

    final result = await _getReflectionStats();

    result.fold(
      (failure) => emit(ReflectionsError(failure)),
      (stats) => emit(ReflectionStatsLoaded(stats)),
    );
  }
}
