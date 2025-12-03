import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/leaderboard_repository.dart';
import 'leaderboard_event.dart';
import 'leaderboard_state.dart';

/// BLoC for managing leaderboard data.
///
/// Handles loading and refreshing of XP leaderboard entries
/// and current user's rank.
class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  final LeaderboardRepository _repository;

  LeaderboardBloc({
    required LeaderboardRepository repository,
  })  : _repository = repository,
        super(const LeaderboardInitial()) {
    on<LoadLeaderboard>(_onLoadLeaderboard);
    on<RefreshLeaderboard>(_onRefreshLeaderboard);
  }

  Future<void> _onLoadLeaderboard(
    LoadLeaderboard event,
    Emitter<LeaderboardState> emit,
  ) async {
    // Don't reload if already loaded
    if (state is LeaderboardLoaded) {
      return;
    }

    emit(const LeaderboardLoading());

    final result = await _repository.getLeaderboardWithUserRank();

    result.fold(
      (failure) => emit(LeaderboardError(message: failure.message)),
      (data) => emit(LeaderboardLoaded(
        entries: data.entries,
        userRank: data.userRank,
      )),
    );
  }

  Future<void> _onRefreshLeaderboard(
    RefreshLeaderboard event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(const LeaderboardLoading());

    final result = await _repository.getLeaderboardWithUserRank();

    result.fold(
      (failure) => emit(LeaderboardError(message: failure.message)),
      (data) => emit(LeaderboardLoaded(
        entries: data.entries,
        userRank: data.userRank,
      )),
    );
  }
}
