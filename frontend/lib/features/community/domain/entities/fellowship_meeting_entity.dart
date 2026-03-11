import 'package:equatable/equatable.dart';

/// Domain entity for a scheduled fellowship meeting.
///
/// Produced by [FellowshipMeetingModel.toEntity] and consumed by the domain
/// and presentation layers. This is a pure business-logic object with no JSON
/// parsing logic.
class FellowshipMeetingEntity extends Equatable {
  /// Unique identifier for the meeting.
  final String id;

  /// The ID of the fellowship this meeting belongs to.
  final String fellowshipId;

  /// The Supabase Auth UID of the user who created the meeting.
  final String createdBy;

  /// Human-readable title for the meeting.
  final String title;

  /// Optional longer description or agenda for the meeting.
  final String? description;

  /// ISO-8601 timestamp when the meeting starts.
  final String startsAt;

  /// ISO-8601 timestamp when the meeting ends.
  final String endsAt;

  /// Recurrence pattern: `'daily'`, `'weekly'`, `'monthly'`, or null for
  /// a one-off meeting.
  final String? recurrence;

  /// Physical gathering location. When non-null the meeting is in-person
  /// and [meetLink] will be empty.
  final String? location;

  /// Google Meet (or equivalent) URL for the meeting. Empty for in-person.
  final String meetLink;

  /// ISO-8601 timestamp when this record was created.
  final String createdAt;

  /// Whether this is an in-person gathering (as opposed to an online meeting).
  bool get isInPerson => location != null && location!.isNotEmpty;

  const FellowshipMeetingEntity({
    required this.id,
    required this.fellowshipId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    this.recurrence,
    this.location,
    required this.meetLink,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        fellowshipId,
        createdBy,
        title,
        description,
        startsAt,
        endsAt,
        recurrence,
        location,
        meetLink,
        createdAt,
      ];
}
