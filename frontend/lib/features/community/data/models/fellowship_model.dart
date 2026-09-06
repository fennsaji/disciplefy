import 'current_study_model.dart';
import '../../domain/entities/fellowship_entity.dart';

/// Data model for a fellowship group returned by the API.
///
/// A fellowship is a small study group that a user belongs to, with a
/// designated mentor and members working through a shared learning path.
class FellowshipModel {
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
  final CurrentStudyModel? currentStudy;

  /// Display name of the fellowship's mentor, if available.
  final String? mentorName;

  /// Whether the fellowship is publicly discoverable.
  final bool isPublic;

  /// Who is allowed to post: `'all_members'` or `'mentor_only'`.
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

  const FellowshipModel({
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

  /// Creates a [FellowshipModel] from a JSON map (API response).
  factory FellowshipModel.fromJson(Map<String, dynamic> json) {
    final currentStudyJson = json['current_study'] as Map<String, dynamic>?;
    final mentorsJson = (json['mentors'] as List<dynamic>?) ?? [];

    return FellowshipModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      memberCount: (json['member_count'] as num).toInt(),
      userRole: json['user_role'] as String,
      joinedAt: json['joined_at'] as String,
      createdAt: json['created_at'] as String,
      currentStudy: currentStudyJson != null
          ? CurrentStudyModel.fromJson(currentStudyJson)
          : null,
      mentorName: json['mentor_name'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      postingPermission: json['posting_permission'] as String? ?? 'all_members',
      mentors: mentorsJson
          .map((m) => FellowshipMentorEntity(
                userId: m['user_id'] as String,
                displayName: m['display_name'] as String? ?? 'Mentor',
                avatarUrl: m['avatar_url'] as String?,
              ))
          .toList(),
      isOfficial: json['is_official'] as bool? ?? false,
      disciplerAllowed: json['discipler_allowed'] as bool? ?? false,
      dailyPostAllowed: json['daily_post_allowed'] as bool? ?? false,
      disciplerReplyMode: json['discipler_reply_mode'] as String? ?? 'auto',
      disciplerReplyScope: json['discipler_reply_scope'] as String? ?? 'all',
      disciplerReplyDelayMin:
          (json['discipler_reply_delay_min'] as num?)?.toInt() ?? 0,
      disciplerReactEnabled: json['discipler_react_enabled'] as bool? ?? true,
      dailyPostOn: json['daily_post_on'] as bool? ?? true,
      myDisciplerActivityPush:
          json['my_discipler_activity_push'] as bool? ?? true,
    );
  }

  /// Converts this model to a [FellowshipEntity] for use in the domain layer.
  FellowshipEntity toEntity() => FellowshipEntity(
        id: id,
        name: name,
        description: description,
        memberCount: memberCount,
        userRole: userRole,
        joinedAt: joinedAt,
        createdAt: createdAt,
        currentStudy: currentStudy?.toEntity(),
        mentorName: mentorName,
        isPublic: isPublic,
        postingPermission: postingPermission,
        mentors: mentors,
        isOfficial: isOfficial,
        disciplerAllowed: disciplerAllowed,
        dailyPostAllowed: dailyPostAllowed,
        disciplerReplyMode: disciplerReplyMode,
        disciplerReplyScope: disciplerReplyScope,
        disciplerReplyDelayMin: disciplerReplyDelayMin,
        disciplerReactEnabled: disciplerReactEnabled,
        dailyPostOn: dailyPostOn,
        myDisciplerActivityPush: myDisciplerActivityPush,
      );
}
