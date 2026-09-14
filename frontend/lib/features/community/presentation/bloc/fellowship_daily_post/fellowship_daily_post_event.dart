import 'package:equatable/equatable.dart';

sealed class FellowshipDailyPostEvent extends Equatable {
  const FellowshipDailyPostEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the daily post status for [fellowshipId], showing a spinner.
class FellowshipDailyPostLoadRequested extends FellowshipDailyPostEvent {
  final String fellowshipId;

  const FellowshipDailyPostLoadRequested(this.fellowshipId);

  @override
  List<Object?> get props => [fellowshipId];
}

/// Reloads the status in place (pull to refresh, polling, after a change).
class FellowshipDailyPostRefreshRequested extends FellowshipDailyPostEvent {
  const FellowshipDailyPostRefreshRequested();
}

/// Changes the schedule. Only non-null fields are sent.
class FellowshipDailyPostScheduleChanged extends FellowshipDailyPostEvent {
  final bool? skipNext;
  final String? pausedUntil;
  final bool clearPause;
  final String? time;
  final String? nextLearningPathTopicId;

  const FellowshipDailyPostScheduleChanged({
    this.skipNext,
    this.pausedUntil,
    this.clearPause = false,
    this.time,
    this.nextLearningPathTopicId,
  });

  @override
  List<Object?> get props =>
      [skipNext, pausedUntil, clearPause, time, nextLearningPathTopicId];
}

/// Starts a gated action: `preview`, `regenerate` or `post_now`.
class FellowshipDailyPostActionRequested extends FellowshipDailyPostEvent {
  final String kind;

  /// For `repost`: the daily post to replace with a new version.
  final String? dailyPostId;

  const FellowshipDailyPostActionRequested(this.kind, {this.dailyPostId});

  @override
  List<Object?> get props => [kind, dailyPostId];
}
