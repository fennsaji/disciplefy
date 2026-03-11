import '../../domain/entities/fellowship_comment_entity.dart';

/// Data model for a comment on a fellowship post returned by the API.
///
/// Comments are replies to fellowship posts. The backend enriches each comment
/// with author display info so the UI does not need a separate lookup.
class FellowshipCommentModel {
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

  const FellowshipCommentModel({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    required this.authorDisplayName,
    this.authorAvatarUrl,
  });

  /// Creates a [FellowshipCommentModel] from a JSON map (API response).
  factory FellowshipCommentModel.fromJson(Map<String, dynamic> json) {
    return FellowshipCommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorUserId: json['author_user_id'] as String,
      content: json['content'] as String,
      isDeleted: json['is_deleted'] as bool,
      createdAt: json['created_at'] as String,
      authorDisplayName: json['author_display_name'] as String,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  /// Converts this model to a [FellowshipCommentEntity] for use in the domain layer.
  FellowshipCommentEntity toEntity() => FellowshipCommentEntity(
        id: id,
        postId: postId,
        authorUserId: authorUserId,
        content: content,
        isDeleted: isDeleted,
        createdAt: createdAt,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
      );
}
