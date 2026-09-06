import 'package:equatable/equatable.dart';

import 'current_study_entity.dart';

/// Domain entity representing a fellowship mentor (owner or promoted helper).
class FellowshipMentorEntity extends Equatable {
  /// The mentor's unique ID (Supabase Auth UID).
  final String userId;

  /// The mentor's display name shown in the fellowship.
  final String displayName;

  /// URL to the mentor's avatar image, or null if not set.
  final String? avatarUrl;

  const FellowshipMentorEntity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, displayName, avatarUrl];
}

/// Domain entity representing a fellowship group.
///
/// A fellowship is a small study group that a user belongs to, with a
/// designated mentor and members working through a shared learning path.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [FellowshipModel.toEntity] and consumed by the domain and presentation
/// layers.
class FellowshipEntity extends Equatable {
  /// Unique identifier for the fellowship.
  final String id;

  /// Display name of the fellowship.
  final String name;

  /// Optional description of the fellowship's focus or purpose.
  final String? description;

  /// Total number of members currently in the fellowship.
  final int memberCount;

  /// The current user's role within this fellowship: `'mentor'` or `'member'`.
  final String userRole;

  /// ISO-8601 timestamp when the current user joined the fellowship.
  final String joinedAt;

  /// ISO-8601 timestamp when the fellowship was created.
  final String createdAt;

  /// The learning path the fellowship is currently working through, if any.
  final CurrentStudyEntity? currentStudy;

  /// Display name of the fellowship's mentor, if available.
  final String? mentorName;

  /// Whether the fellowship is publicly discoverable.
  final bool isPublic;

  /// Who is allowed to post in the feed: `'all_members'` (mentor + members)
  /// or `'mentor_only'` (only the mentor).
  final String postingPermission;

  /// All mentors of this fellowship (owner plus any promoted members).
  final List<FellowshipMentorEntity> mentors;

  /// True when this is an official Disciplefy fellowship.
  final bool isOfficial;

  /// True when the Discipler AI helper is allowed to participate.
  final bool disciplerAllowed;

  /// True when the fellowship admin allows a daily study post.
  final bool dailyPostAllowed;

  /// Discipler reply mode: `'off'`, `'auto'`, or `'review'`.
  final String disciplerReplyMode;

  /// Which questions the Discipler answers: `'all'` or `'lessons_only'`.
  final String disciplerReplyScope;

  /// Minutes to wait for a mentor to answer before Discipler replies.
  final int disciplerReplyDelayMin;

  /// True when the Discipler AI helper may react to posts.
  final bool disciplerReactEnabled;

  /// True when the fellowship has daily study posts turned on.
  final bool dailyPostOn;

  /// True when the current user wants push notifications for Discipler
  /// activity in this fellowship.
  final bool myDisciplerActivityPush;

  const FellowshipEntity({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.userRole,
    required this.joinedAt,
    required this.createdAt,
    this.currentStudy,
    this.mentorName,
    this.isPublic = false,
    this.postingPermission = 'all_members',
    this.mentors = const [],
    this.isOfficial = false,
    this.disciplerAllowed = false,
    this.dailyPostAllowed = false,
    this.disciplerReplyMode = 'auto',
    this.disciplerReplyScope = 'all',
    this.disciplerReplyDelayMin = 0,
    this.disciplerReactEnabled = true,
    this.dailyPostOn = true,
    this.myDisciplerActivityPush = true,
  });

  /// True when the current user is allowed to create posts in this fellowship.
  bool get canCurrentUserPost =>
      postingPermission != 'mentor_only' || userRole == 'mentor';

  /// Returns a copy of this fellowship with select preference fields replaced.
  FellowshipEntity copyWith({
    String? name,
    String? description,
    String? postingPermission,
    List<FellowshipMentorEntity>? mentors,
    String? disciplerReplyMode,
    String? disciplerReplyScope,
    int? disciplerReplyDelayMin,
    bool? disciplerReactEnabled,
    bool? dailyPostOn,
    bool? myDisciplerActivityPush,
  }) {
    return FellowshipEntity(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      memberCount: memberCount,
      userRole: userRole,
      joinedAt: joinedAt,
      createdAt: createdAt,
      currentStudy: currentStudy,
      mentorName: mentorName,
      isPublic: isPublic,
      postingPermission: postingPermission ?? this.postingPermission,
      mentors: mentors ?? this.mentors,
      isOfficial: isOfficial,
      disciplerAllowed: disciplerAllowed,
      dailyPostAllowed: dailyPostAllowed,
      disciplerReplyMode: disciplerReplyMode ?? this.disciplerReplyMode,
      disciplerReplyScope: disciplerReplyScope ?? this.disciplerReplyScope,
      disciplerReplyDelayMin:
          disciplerReplyDelayMin ?? this.disciplerReplyDelayMin,
      disciplerReactEnabled:
          disciplerReactEnabled ?? this.disciplerReactEnabled,
      dailyPostOn: dailyPostOn ?? this.dailyPostOn,
      myDisciplerActivityPush:
          myDisciplerActivityPush ?? this.myDisciplerActivityPush,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        memberCount,
        userRole,
        joinedAt,
        createdAt,
        currentStudy,
        mentorName,
        isPublic,
        postingPermission,
        mentors,
        isOfficial,
        disciplerAllowed,
        dailyPostAllowed,
        disciplerReplyMode,
        disciplerReplyScope,
        disciplerReplyDelayMin,
        disciplerReactEnabled,
        dailyPostOn,
        myDisciplerActivityPush,
      ];
}
