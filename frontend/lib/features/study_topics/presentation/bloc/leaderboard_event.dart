import 'package:equatable/equatable.dart';

/// Events for LeaderboardBloc
abstract class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();

  @override
  List<Object?> get props => [];
}

/// Load leaderboard data (entries and user rank)
class LoadLeaderboard extends LeaderboardEvent {
  const LoadLeaderboard();
}

/// Refresh leaderboard data (force reload)
class RefreshLeaderboard extends LeaderboardEvent {
  const RefreshLeaderboard();
}
