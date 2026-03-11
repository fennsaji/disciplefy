import '../../domain/entities/fellowship_member_entity.dart';

/// Data model for a member of a fellowship returned by the API.
///
/// Represents a single user's membership details within a fellowship,
/// including their role, join date, and whether they have been muted.
class FellowshipMemberModel {
  /// The user's unique ID (Supabase Auth UID).
  final String userId;

  /// The member's display name shown in the fellowship.
  final String displayName;

  /// URL to the member's avatar image, or null if not set.
  final String? avatarUrl;

  /// The member's role in this fellowship: `'mentor'` or `'member'`.
  final String role;

  /// ISO-8601 timestamp when this user joined the fellowship.
  final String joinedAt;

  /// Whether this member has been muted by the mentor.
  final bool isMuted;

  /// Number of topics completed on the fellowship's active learning path.
  /// Null when the fellowship has no active study.
  final int? topicsCompleted;

  const FellowshipMemberModel({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    required this.isMuted,
    this.topicsCompleted,
  });

  /// Creates a [FellowshipMemberModel] from a JSON map (API response).
  factory FellowshipMemberModel.fromJson(Map<String, dynamic> json) {
    return FellowshipMemberModel(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String,
      joinedAt: json['joined_at'] as String,
      isMuted: json['is_muted'] as bool,
      topicsCompleted: json['topics_completed'] as int?,
    );
  }

  /// Converts this model to a [FellowshipMemberEntity] for use in the domain layer.
  FellowshipMemberEntity toEntity() => FellowshipMemberEntity(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
        joinedAt: joinedAt,
        isMuted: isMuted,
        topicsCompleted: topicsCompleted,
      );
}
