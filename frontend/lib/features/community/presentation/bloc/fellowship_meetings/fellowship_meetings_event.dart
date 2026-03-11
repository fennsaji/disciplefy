import 'package:equatable/equatable.dart';

/// Base class for all [FellowshipMeetingsBloc] events.
abstract class FellowshipMeetingsEvent extends Equatable {
  const FellowshipMeetingsEvent();

  @override
  List<Object?> get props => [];
}

/// Requests the upcoming meeting list for [fellowshipId].
class FellowshipMeetingsLoadRequested extends FellowshipMeetingsEvent {
  /// The fellowship whose meetings should be loaded.
  final String fellowshipId;

  const FellowshipMeetingsLoadRequested(this.fellowshipId);

  @override
  List<Object?> get props => [fellowshipId];
}

/// Requests creation of a new scheduled meeting.
class FellowshipMeetingCreateRequested extends FellowshipMeetingsEvent {
  final String fellowshipId;
  final String title;
  final String? description;

  /// ISO-8601 start timestamp.
  final String startsAt;

  /// Meeting length in minutes.
  final int durationMinutes;

  /// IANA timezone string, e.g. `'America/New_York'`.
  final String timeZone;

  /// Recurrence pattern: `'daily'`, `'weekly'`, `'monthly'`, or null.
  final String? recurrence;

  /// Physical gathering location. When set the meeting is in-person and
  /// no Google Calendar / Meet link is generated.
  final String? location;

  /// Google OAuth access token with Calendar scope (optional).
  /// When provided, the backend uses the mentor's own Google token to create
  /// the Calendar event — enabling real Meet links and proper invite emails.
  /// Expires in ~1 hour; the backend will auto-refresh it using [googleRefreshToken].
  final String? googleAccessToken;

  /// Google OAuth refresh token (optional, requires offline access consent).
  /// The backend exchanges this for a fresh [googleAccessToken] when the
  /// original has expired, ensuring Meet links are always created.
  final String? googleRefreshToken;

  const FellowshipMeetingCreateRequested({
    required this.fellowshipId,
    required this.title,
    this.description,
    required this.startsAt,
    required this.durationMinutes,
    required this.timeZone,
    this.recurrence,
    this.location,
    this.googleAccessToken,
    this.googleRefreshToken,
  });

  @override
  List<Object?> get props => [
        fellowshipId,
        title,
        description,
        startsAt,
        durationMinutes,
        timeZone,
        recurrence,
        location,
        googleAccessToken,
        googleRefreshToken,
      ];
}

/// Requests cancellation of the meeting identified by [meetingId].
class FellowshipMeetingCancelRequested extends FellowshipMeetingsEvent {
  /// The ID of the meeting to cancel.
  final String meetingId;

  /// Google OAuth access token (calendar.events scope). Required to delete
  /// events on the mentor's personal Google Calendar (calendar_type =
  /// 'user_primary'). Obtained via a silent GoogleSignIn scope check —
  /// the same flow used when scheduling the meeting.
  final String? googleAccessToken;

  const FellowshipMeetingCancelRequested(
    this.meetingId, {
    this.googleAccessToken,
  });

  @override
  List<Object?> get props => [meetingId, googleAccessToken];
}
