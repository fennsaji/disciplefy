/// Result of a bulk Google Calendar attendee sync operation.
///
/// Returned by [CommunityRepository.syncFellowshipCalendar].
class SyncCalendarResult {
  final int syncedMeetings;
  final int skippedMeetings;
  final int syncedMembers;
  final List<String> oauthErrors;

  const SyncCalendarResult({
    required this.syncedMeetings,
    required this.skippedMeetings,
    required this.syncedMembers,
    required this.oauthErrors,
  });

  /// True when one or more meetings could not be synced due to expired OAuth.
  bool get requiresReconnect => oauthErrors.isNotEmpty;

  factory SyncCalendarResult.fromJson(Map<String, dynamic> json) {
    return SyncCalendarResult(
      syncedMeetings: (json['syncedMeetings'] as num?)?.toInt() ?? 0,
      skippedMeetings: (json['skippedMeetings'] as num?)?.toInt() ?? 0,
      syncedMembers: (json['syncedMembers'] as num?)?.toInt() ?? 0,
      oauthErrors: (json['oauthErrors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
