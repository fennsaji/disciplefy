import 'package:equatable/equatable.dart';

import 'current_study_entity.dart';

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
  });

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
      ];
}
