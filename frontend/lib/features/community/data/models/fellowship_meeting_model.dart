import '../../domain/entities/fellowship_meeting_entity.dart';

/// Data model for a fellowship meeting returned by the API.
///
/// Maps directly from the JSON envelope returned by the
/// `fellowship-meetings-list` and `fellowship-meetings-create` Edge Functions.
/// Call [toEntity] to obtain the domain [FellowshipMeetingEntity].
class FellowshipMeetingModel {
  final String id;
  final String fellowshipId;
  final String createdBy;
  final String title;
  final String? description;
  final String startsAt;
  final String endsAt;
  final String? recurrence;

  /// Physical gathering location. Null for online meetings.
  final String? location;

  /// Google Meet join URL. Empty string for in-person meetings.
  final String meetLink;

  final String createdAt;

  final String? lastSyncedAt;

  const FellowshipMeetingModel({
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
    this.lastSyncedAt,
  });

  factory FellowshipMeetingModel.fromJson(Map<String, dynamic> json) {
    return FellowshipMeetingModel(
      id: json['id'] as String,
      fellowshipId: json['fellowship_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: json['starts_at'] as String,
      endsAt: json['ends_at'] as String,
      recurrence: json['recurrence'] as String?,
      location: json['location'] as String?,
      meetLink: (json['meet_link'] as String?) ?? '',
      createdAt: json['created_at'] as String,
      lastSyncedAt: json['last_synced_at'] as String?,
    );
  }

  FellowshipMeetingEntity toEntity() => FellowshipMeetingEntity(
        id: id,
        fellowshipId: fellowshipId,
        createdBy: createdBy,
        title: title,
        description: description,
        startsAt: startsAt,
        endsAt: endsAt,
        recurrence: recurrence,
        location: location,
        meetLink: meetLink,
        createdAt: createdAt,
        lastSyncedAt: lastSyncedAt,
      );
}
