import 'package:equatable/equatable.dart';

/// Domain entity representing a publicly discoverable fellowship group.
///
/// A public fellowship is a small study group visible to all users for the
/// purpose of discovery and joining. It carries only the metadata needed to
/// display a browse/search result card and does not include per-user context
/// such as roles or join timestamps.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [PublicFellowshipModel.toEntity] and consumed by the domain and
/// presentation layers.
class PublicFellowshipEntity extends Equatable {
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

  const PublicFellowshipEntity({
    required this.id,
    required this.name,
    this.description,
    required this.language,
    required this.memberCount,
    required this.maxMembers,
    this.currentStudyTitle,
    this.mentorName,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        language,
        memberCount,
        maxMembers,
        currentStudyTitle,
        mentorName,
      ];
}
