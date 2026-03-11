import 'package:equatable/equatable.dart';

import '../../../../../features/community/domain/entities/fellowship_meeting_entity.dart';

/// Status of the [FellowshipMeetingsBloc] load operation.
enum FellowshipMeetingsStatus {
  /// No load has been triggered yet.
  initial,

  /// Meetings are currently being fetched from the network.
  loading,

  /// Meetings were successfully fetched.
  success,

  /// A network or server error occurred during the last fetch.
  failure,
}

/// Immutable state managed by [FellowshipMeetingsBloc].
///
/// Use [copyWith] to derive a new instance with selective field overrides.
/// Nullable message fields use the closure-based `copyWith` pattern so that
/// callers can explicitly clear them by passing `() => null`.
class FellowshipMeetingsState extends Equatable {
  /// Current status of the meetings list load.
  final FellowshipMeetingsStatus status;

  /// The list of meetings currently held in state.
  final List<FellowshipMeetingEntity> meetings;

  /// True while a create or cancel operation is in progress.
  final bool submitting;

  /// Non-null when the last operation produced an error.
  final String? errorMessage;

  /// Non-null after a successful create or cancel operation.
  final String? successMessage;

  const FellowshipMeetingsState({
    this.status = FellowshipMeetingsStatus.initial,
    this.meetings = const [],
    this.submitting = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Returns a copy of this state with the supplied fields replaced.
  ///
  /// Pass `errorMessage: () => null` or `successMessage: () => null` to
  /// explicitly clear those fields.
  FellowshipMeetingsState copyWith({
    FellowshipMeetingsStatus? status,
    List<FellowshipMeetingEntity>? meetings,
    bool? submitting,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return FellowshipMeetingsState(
      status: status ?? this.status,
      meetings: meetings ?? this.meetings,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, meetings, submitting, errorMessage, successMessage];
}
