import '../../domain/entities/public_fellowship_entity.dart';

/// Data model for a publicly discoverable fellowship group returned by the API.
///
/// A public fellowship is a small study group visible to all users for the
/// purpose of discovery and joining. It carries only the metadata needed to
/// display a browse/search result card and does not include per-user context
/// such as roles or join timestamps.
class PublicFellowshipModel {
  /// Unique identifier for the fellowship.
  final String id;

  /// Display name of the fellowship.
  final String name;

  /// Optional description of the fellowship's focus or purpose.
  final String? description;

  /// Language code for the fellowship: `'en'`, `'hi'`, or `'ml'`.
  final String language;

  /// Total number of members currently in the fellowship.
  final int memberCount;

  /// Maximum number of members the fellowship can accommodate.
  final int maxMembers;

  /// Title of the study the fellowship is currently working through, if any.
  final String? currentStudyTitle;

  /// Display name of the fellowship's mentor.
  final String? mentorName;

  const PublicFellowshipModel({
    required this.id,
    required this.name,
    this.description,
    required this.language,
    required this.memberCount,
    required this.maxMembers,
    this.currentStudyTitle,
    this.mentorName,
  });

  /// Creates a [PublicFellowshipModel] from a JSON map (API response).
  factory PublicFellowshipModel.fromJson(Map<String, dynamic> json) {
    return PublicFellowshipModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      language: json['language'] as String? ?? 'en',
      memberCount: json['member_count'] as int? ?? 0,
      maxMembers: json['max_members'] as int? ?? 12,
      currentStudyTitle: json['current_study_title'] as String?,
      mentorName: json['mentor_name'] as String?,
    );
  }

  /// Converts this model to a [PublicFellowshipEntity] for use in the domain layer.
  PublicFellowshipEntity toEntity() => PublicFellowshipEntity(
        id: id,
        name: name,
        description: description,
        language: language,
        memberCount: memberCount,
        maxMembers: maxMembers,
        currentStudyTitle: currentStudyTitle,
        mentorName: mentorName,
      );
}
