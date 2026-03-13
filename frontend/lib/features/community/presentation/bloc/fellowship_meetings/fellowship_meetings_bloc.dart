import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../features/community/domain/entities/sync_calendar_result.dart';
import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'fellowship_meetings_event.dart';
import 'fellowship_meetings_state.dart';

/// BLoC that manages the scheduled meetings list for a single fellowship,
/// along with create, cancel, and calendar-sync operations.
///
/// Inject [CommunityRepository] via the constructor. Dispatch:
/// - [FellowshipMeetingsLoadRequested] to fetch/refresh the list.
/// - [FellowshipMeetingCreateRequested] to schedule a new meeting.
/// - [FellowshipMeetingCancelRequested] to cancel an existing meeting.
/// - [FellowshipMeetingsSyncCalendarRequested] to bulk-sync Google Calendar.
class FellowshipMeetingsBloc
    extends Bloc<FellowshipMeetingsEvent, FellowshipMeetingsState> {
  final CommunityRepository _repository;

  FellowshipMeetingsBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipMeetingsState()) {
    on<FellowshipMeetingsLoadRequested>(_onLoadRequested);
    on<FellowshipMeetingCreateRequested>(_onCreateRequested);
    on<FellowshipMeetingCancelRequested>(_onCancelRequested);
    on<FellowshipMeetingsSyncCalendarRequested>(_onSyncCalendarRequested);
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Fetches (or refreshes) the upcoming meetings list for the fellowship.
  Future<void> _onLoadRequested(
    FellowshipMeetingsLoadRequested event,
    Emitter<FellowshipMeetingsState> emit,
  ) async {
    emit(state.copyWith(status: FellowshipMeetingsStatus.loading));

    final result = await _repository.getMeetings(event.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipMeetingsStatus.failure,
        errorMessage: () => failure.message,
      )),
      (meetings) {
        // Use meetLink as proxy for "has Google Calendar event" because the API
        // does not return google_calendar_event_id to the client. Only meetings
        // with a Google Meet link can be synced (service_account meetings also
        // have a meet link, but filtering by calendar_type is backend-only).
        // This is an intentional approximation: the worst-case is showing the
        // banner for service_account meetings, where /sync-calendar will simply
        // return syncedMeetings: 0 and the banner will remain visible.
        final hasMeetingNeedingSync = meetings.any(
          (m) => m.meetLink.isNotEmpty && m.lastSyncedAt == null,
        );
        emit(state.copyWith(
          status: FellowshipMeetingsStatus.success,
          meetings: meetings,
          showSyncBanner: hasMeetingNeedingSync,
          errorMessage: () => null,
        ));
      },
    );
  }

  /// Schedules a new meeting and prepends it to the sorted meeting list on
  /// success.
  Future<void> _onCreateRequested(
    FellowshipMeetingCreateRequested event,
    Emitter<FellowshipMeetingsState> emit,
  ) async {
    emit(state.copyWith(
      submitting: true,
      errorMessage: () => null,
      successMessage: () => null,
    ));

    final result = await _repository.createMeeting(
      fellowshipId: event.fellowshipId,
      title: event.title,
      description: event.description,
      startsAt: event.startsAt,
      durationMinutes: event.durationMinutes,
      timeZone: event.timeZone,
      recurrence: event.recurrence,
      location: event.location,
      googleAccessToken: event.googleAccessToken,
      googleRefreshToken: event.googleRefreshToken,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        submitting: false,
        errorMessage: () => failure.message,
      )),
      (newMeeting) {
        final updated = [newMeeting, ...state.meetings]
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        emit(state.copyWith(
          submitting: false,
          meetings: updated,
          successMessage: () => 'Meeting scheduled! Invites sent.',
        ));
      },
    );
  }

  /// Cancels a meeting and removes it from the local list on success.
  Future<void> _onCancelRequested(
    FellowshipMeetingCancelRequested event,
    Emitter<FellowshipMeetingsState> emit,
  ) async {
    emit(state.copyWith(
      submitting: true,
      errorMessage: () => null,
      successMessage: () => null,
    ));

    final result = await _repository.cancelMeeting(
      event.meetingId,
      googleAccessToken: event.googleAccessToken,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        submitting: false,
        errorMessage: () => failure.message,
      )),
      (_) {
        final updated =
            state.meetings.where((m) => m.id != event.meetingId).toList();
        emit(state.copyWith(
          submitting: false,
          meetings: updated,
          successMessage: () => 'Meeting cancelled.',
        ));
      },
    );
  }

  /// Bulk-syncs Google Calendar attendees for all upcoming meetings.
  Future<void> _onSyncCalendarRequested(
    FellowshipMeetingsSyncCalendarRequested event,
    Emitter<FellowshipMeetingsState> emit,
  ) async {
    emit(state.copyWith(
      isSyncingCalendar: true,
      syncRequiresReconnect: false,
      errorMessage: () => null,
      successMessage: () => null,
    ));

    final result = await _repository.syncFellowshipCalendar(event.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        isSyncingCalendar: false,
        errorMessage: () => failure.message,
      )),
      (syncResult) {
        if (syncResult.requiresReconnect) {
          emit(state.copyWith(
            isSyncingCalendar: false,
            syncRequiresReconnect: true,
          ));
        } else {
          emit(state.copyWith(
            isSyncingCalendar: false,
            showSyncBanner: false,
            successMessage: () =>
                'Calendar synced for ${syncResult.syncedMembers} members.',
          ));
        }
      },
    );
  }
}
