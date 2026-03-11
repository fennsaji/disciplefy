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
  });

  /// Creates a [FellowshipModel] from a JSON map (API response).
  factory FellowshipModel.fromJson(Map<String, dynamic> json) {
    final currentStudyJson = json['current_study'] as Map<String, dynamic>?;

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
      );
}
