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
  final FellowshipMeetingsStatus status;
  final List<FellowshipMeetingEntity> meetings;
  final bool submitting;
  final String? errorMessage;
  final String? successMessage;

  /// True while a Google Calendar sync operation is in progress.
  final bool isSyncingCalendar;

  /// True when any upcoming meeting with a Google Calendar event has
  /// [FellowshipMeetingEntity.lastSyncedAt] == null (never synced).
  final bool showSyncBanner;

  /// True when one or more meetings could not be synced due to expired OAuth.
  final bool syncRequiresReconnect;

  const FellowshipMeetingsState({
    this.status = FellowshipMeetingsStatus.initial,
    this.meetings = const [],
    this.submitting = false,
    this.errorMessage,
    this.successMessage,
    this.isSyncingCalendar = false,
    this.showSyncBanner = false,
    this.syncRequiresReconnect = false,
  });

  FellowshipMeetingsState copyWith({
    FellowshipMeetingsStatus? status,
    List<FellowshipMeetingEntity>? meetings,
    bool? submitting,
    String? Function()? errorMessage,
    String? Function()? successMessage,
    bool? isSyncingCalendar,
    bool? showSyncBanner,
    bool? syncRequiresReconnect,
  }) {
    return FellowshipMeetingsState(
      status: status ?? this.status,
      meetings: meetings ?? this.meetings,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
      isSyncingCalendar: isSyncingCalendar ?? this.isSyncingCalendar,
      showSyncBanner: showSyncBanner ?? this.showSyncBanner,
      syncRequiresReconnect:
          syncRequiresReconnect ?? this.syncRequiresReconnect,
    );
  }

  @override
  List<Object?> get props => [
        status,
        meetings,
        submitting,
        errorMessage,
        successMessage,
        isSyncingCalendar,
        showSyncBanner,
        syncRequiresReconnect,
      ];
}
