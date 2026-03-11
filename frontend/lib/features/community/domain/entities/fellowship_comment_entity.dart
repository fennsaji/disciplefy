import 'package:equatable/equatable.dart';

/// Domain entity representing a comment on a fellowship post.
///
/// Comments are replies to fellowship posts. The entity carries enriched
/// author display info so the UI does not need a separate lookup.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [FellowshipCommentModel.toEntity] and consumed by the domain and
/// presentation layers.
class FellowshipCommentEntity extends Equatable {
  /// Unique identifier for the comment.
  final String id;

  /// The ID of the post this comment belongs to.
  final String postId;

  /// The Supabase Auth UID of the user who created this comment.
  final String authorUserId;

  /// The text body of the comment.
  final String content;

  /// Whether this comment has been soft-deleted.
  final bool isDeleted;

  /// ISO-8601 timestamp when the comment was created.
  final String createdAt;

  /// Display name of the comment author (enriched by the backend).
  final String authorDisplayName;

  /// Avatar URL of the comment author, or null if not set.
  final String? authorAvatarUrl;

  const FellowshipCommentEntity({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    required this.authorDisplayName,
    this.authorAvatarUrl,
  });

  @override
  List<Object?> get props => [
        id,
        postId,
        authorUserId,
        content,
        isDeleted,
        createdAt,
        authorDisplayName,
        authorAvatarUrl,
      ];
}
