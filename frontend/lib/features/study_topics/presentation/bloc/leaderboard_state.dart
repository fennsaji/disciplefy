import 'package:equatable/equatable.dart';

import '../../domain/entities/leaderboard_entry.dart';

/// States for LeaderboardBloc
abstract class LeaderboardState extends Equatable {
  const LeaderboardState();

  @override
  List<Object?> get props => [];
}

/// Initial state before data is loaded
class LeaderboardInitial extends LeaderboardState {
  const LeaderboardInitial();
}

/// Loading state while fetching leaderboard data
class LeaderboardLoading extends LeaderboardState {
  const LeaderboardLoading();
}

/// Successfully loaded leaderboard data
class LeaderboardLoaded extends LeaderboardState {
  final List<LeaderboardEntry> entries;
  final UserXpRank userRank;

  const LeaderboardLoaded({
    required this.entries,
    required this.userRank,
  });

  @override
  List<Object?> get props => [entries, userRank];
}

/// Error state when loading fails
class LeaderboardError extends LeaderboardState {
  final String message;

  const LeaderboardError({required this.message});

  @override
  List<Object?> get props => [message];
}
