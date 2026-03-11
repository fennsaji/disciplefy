import 'package:equatable/equatable.dart';

/// Domain entity representing a member of a fellowship.
///
/// Encapsulates a single user's membership details within a fellowship,
/// including their role, join date, and mute status.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [FellowshipMemberModel.toEntity] and consumed by the domain and
/// presentation layers.
class FellowshipMemberEntity extends Equatable {
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

  /// Number of topics this member has completed on the fellowship's active
  /// learning path. Null when the fellowship has no active study.
  final int? topicsCompleted;

  const FellowshipMemberEntity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    required this.isMuted,
    this.topicsCompleted,
  });

  FellowshipMemberEntity copyWith({bool? isMuted, int? topicsCompleted}) {
    return FellowshipMemberEntity(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      role: role,
      joinedAt: joinedAt,
      isMuted: isMuted ?? this.isMuted,
      topicsCompleted: topicsCompleted ?? this.topicsCompleted,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        displayName,
        avatarUrl,
        role,
        joinedAt,
        isMuted,
        topicsCompleted,
      ];
}
