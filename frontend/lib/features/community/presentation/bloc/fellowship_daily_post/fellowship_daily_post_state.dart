import 'package:equatable/equatable.dart';

import '../../../domain/entities/daily_post_status_entity.dart';

enum FellowshipDailyPostStatus { initial, loading, loaded, failure }

/// A one-off message for the screen to show (usually a snackbar). [id]
/// changes every time so the same message can be shown twice.
class FellowshipDailyPostNotice extends Equatable {
  final int id;

  /// The action this notice is about (`preview`, `regenerate`, `post_now`),
  /// or `schedule` for a schedule change.
  final String kind;
  final bool success;

  /// Server message to show on failure; `null` uses the screen's own wording.
  final String? error;

  const FellowshipDailyPostNotice({
    required this.id,
    required this.kind,
    required this.success,
    this.error,
  });

  @override
  List<Object?> get props => [id, kind, success, error];
}

class FellowshipDailyPostState extends Equatable {
  final FellowshipDailyPostStatus status;
  final String fellowshipId;
  final DailyPostStatusEntity? data;

  /// True while a schedule change or action request is being sent.
  final bool saving;
  final String? errorMessage;
  final FellowshipDailyPostNotice? notice;

  const FellowshipDailyPostState({
    this.status = FellowshipDailyPostStatus.initial,
    this.fellowshipId = '',
    this.data,
    this.saving = false,
    this.errorMessage,
    this.notice,
  });

  FellowshipDailyPostState copyWith({
    FellowshipDailyPostStatus? status,
    String? fellowshipId,
    DailyPostStatusEntity? data,
    bool? saving,
    String? errorMessage,
    FellowshipDailyPostNotice? notice,
  }) {
    return FellowshipDailyPostState(
      status: status ?? this.status,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      data: data ?? this.data,
      saving: saving ?? this.saving,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props =>
      [status, fellowshipId, data, saving, errorMessage, notice];
}
