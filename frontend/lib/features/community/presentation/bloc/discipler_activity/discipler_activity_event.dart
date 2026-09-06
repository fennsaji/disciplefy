import 'package:equatable/equatable.dart';

/// Base class for all [DisciplerActivityBloc] events.
abstract class DisciplerActivityEvent extends Equatable {
  const DisciplerActivityEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the first page of Discipler activity for [fellowshipId], discarding
/// any previously held items and resetting the pagination cursor.
///
/// Pass [kind] to filter: `null` (all), `'draft'`, `'reply'`, `'react'`, or
/// `'daily_post'`.
class DisciplerActivityLoadRequested extends DisciplerActivityEvent {
  final String fellowshipId;
  final String? kind;

  const DisciplerActivityLoadRequested({
    required this.fellowshipId,
    this.kind,
  });

  @override
  List<Object?> get props => [fellowshipId, kind];
}

/// Appends the next page of activity items using the current cursor held in
/// state.
class DisciplerActivityLoadMoreRequested extends DisciplerActivityEvent {
  const DisciplerActivityLoadMoreRequested();
}

/// Approves or discards a Discipler-authored draft comment.
class DisciplerActivityReviewed extends DisciplerActivityEvent {
  final String commentId;
  final bool approve;

  const DisciplerActivityReviewed({
    required this.commentId,
    required this.approve,
  });

  @override
  List<Object?> get props => [commentId, approve];
}

/// Deletes the underlying post or comment behind an activity row.
class DisciplerActivityDeleteRequested extends DisciplerActivityEvent {
  final String activityId;
  final String? postId;
  final String? commentId;

  const DisciplerActivityDeleteRequested({
    required this.activityId,
    this.postId,
    this.commentId,
  });

  @override
  List<Object?> get props => [activityId, postId, commentId];
}
