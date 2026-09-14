import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/error_message_sanitizer.dart';
import '../../../domain/entities/daily_post_status_entity.dart';
import '../../../domain/repositories/community_repository.dart';
import 'fellowship_daily_post_event.dart';
import 'fellowship_daily_post_state.dart';

/// Mentor daily post screen: loads the status, changes the schedule, and
/// starts gated actions. Actions run on the server within about a minute, so
/// while any is open the status is polled and a notice is raised when it
/// finishes.
class FellowshipDailyPostBloc
    extends Bloc<FellowshipDailyPostEvent, FellowshipDailyPostState> {
  static const _pollInterval = Duration(seconds: 5);

  final CommunityRepository _repository;
  Timer? _pollTimer;
  int _noticeCounter = 0;

  FellowshipDailyPostBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipDailyPostState()) {
    on<FellowshipDailyPostLoadRequested>(_onLoad);
    on<FellowshipDailyPostRefreshRequested>(_onRefresh);
    on<FellowshipDailyPostScheduleChanged>(_onScheduleChanged);
    on<FellowshipDailyPostSettingsChanged>(_onSettingsChanged);
    on<FellowshipDailyPostActionRequested>(_onActionRequested);
  }

  Future<void> _onLoad(
    FellowshipDailyPostLoadRequested event,
    Emitter<FellowshipDailyPostState> emit,
  ) async {
    emit(state.copyWith(
      status: FellowshipDailyPostStatus.loading,
      fellowshipId: event.fellowshipId,
    ));
    final result = await _repository.getDailyPostStatus(event.fellowshipId);
    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipDailyPostStatus.failure,
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (data) {
        emit(state.copyWith(
            status: FellowshipDailyPostStatus.loaded, data: data));
        _updatePolling(data);
      },
    );
  }

  Future<void> _onRefresh(
    FellowshipDailyPostRefreshRequested event,
    Emitter<FellowshipDailyPostState> emit,
  ) async {
    if (state.fellowshipId.isEmpty) return;
    final previous = state.data;
    final result = await _repository.getDailyPostStatus(state.fellowshipId);
    result.fold(
      // A failed background refresh keeps what is on screen.
      (_) {},
      (data) {
        emit(state.copyWith(
          status: FellowshipDailyPostStatus.loaded,
          data: data,
          notice: _finishedRequestNotice(previous, data),
        ));
        _updatePolling(data);
      },
    );
  }

  Future<void> _onScheduleChanged(
    FellowshipDailyPostScheduleChanged event,
    Emitter<FellowshipDailyPostState> emit,
  ) async {
    emit(state.copyWith(saving: true));
    final result = await _repository.updateDailyPost(
      state.fellowshipId,
      skipNext: event.skipNext,
      pausedUntil: event.pausedUntil,
      clearPause: event.clearPause,
      time: event.time,
      nextLearningPathTopicId: event.nextLearningPathTopicId,
    );
    emit(state.copyWith(
      saving: false,
      notice: result.fold(
        (failure) =>
            _notice('schedule', false, ErrorMessageSanitizer.sanitize(failure)),
        (_) => _notice('schedule', true),
      ),
    ));
    if (result.isRight()) add(const FellowshipDailyPostRefreshRequested());
  }

  Future<void> _onSettingsChanged(
    FellowshipDailyPostSettingsChanged event,
    Emitter<FellowshipDailyPostState> emit,
  ) async {
    emit(state.copyWith(saving: true));
    final result = await _repository.updateFellowship(
      fellowshipId: state.fellowshipId,
      dailyPostOn: event.dailyPostOn,
      dailyPostFrequencyDays: event.frequencyDays,
      dailyPostAutoAdvance: event.autoAdvance,
    );
    emit(state.copyWith(
      saving: false,
      notice: result.fold(
        (failure) =>
            _notice('schedule', false, ErrorMessageSanitizer.sanitize(failure)),
        (_) => _notice('schedule', true),
      ),
    ));
    if (result.isRight()) add(const FellowshipDailyPostRefreshRequested());
  }

  Future<void> _onActionRequested(
    FellowshipDailyPostActionRequested event,
    Emitter<FellowshipDailyPostState> emit,
  ) async {
    emit(state.copyWith(saving: true));
    final result = await _repository.requestDailyPostAction(
        state.fellowshipId, event.kind,
        dailyPostId: event.dailyPostId);
    emit(state.copyWith(saving: false));
    result.fold(
      (failure) => emit(state.copyWith(
          notice: _notice(
              event.kind, false, ErrorMessageSanitizer.sanitize(failure)))),
      // Refresh so the action shows as in progress; polling takes it from there.
      (_) => add(const FellowshipDailyPostRefreshRequested()),
    );
  }

  /// A notice for the first request that was open before this refresh and has
  /// now finished.
  FellowshipDailyPostNotice? _finishedRequestNotice(
    DailyPostStatusEntity? previous,
    DailyPostStatusEntity current,
  ) {
    if (previous == null) return null;
    for (final entry in current.requests.entries) {
      final before = previous.requests[entry.key];
      if (before != null && before.isOpen && !entry.value.isOpen) {
        return _notice(entry.key, !entry.value.isFailed, entry.value.error);
      }
    }
    return null;
  }

  FellowshipDailyPostNotice _notice(String kind, bool success,
          [String? error]) =>
      FellowshipDailyPostNotice(
        id: ++_noticeCounter,
        kind: kind,
        success: success,
        error: error,
      );

  void _updatePolling(DailyPostStatusEntity data) {
    if (data.hasOpenRequest) {
      _pollTimer ??= Timer.periodic(_pollInterval, (_) {
        if (!isClosed) add(const FellowshipDailyPostRefreshRequested());
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
