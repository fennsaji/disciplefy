import '../../domain/entities/discipler_activity_entity.dart';

/// Data model for a single Discipler activity feed item returned by the API.
///
/// The backend joins the related `post` and `comment` rows inline so the UI
/// does not need a separate lookup.
class DisciplerActivityModel {
  /// Unique identifier for the activity record.
  final String id;

  /// Kind of activity: e.g. `'draft'`, `'reply'`, `'react'`, `'daily_post'`.
  final String kind;

  /// The ID of the post this activity relates to, if any.
  final String? postId;

  /// The ID of the comment this activity relates to, if any.
  final String? commentId;

  /// The reaction emoji applied, if [kind] is a reaction.
  final String? reaction;

  /// Language code the activity was generated in.
  final String? language;

  /// Human-readable summary of the activity.
  final String summary;

  /// ISO-8601 timestamp when a mentor reviewed this activity, or null.
  final String? reviewedAt;

  /// ISO-8601 timestamp when the activity was created.
  final String createdAt;

  /// Content of the related post, if any.
  final String? postContent;

  /// Post type of the related post, if any.
  final String? postType;

  /// Title of the related topic, if any.
  final String? topicTitle;

  /// Content of the related comment, if any.
  final String? commentContent;

  /// True when the related comment is still pending mentor review.
  final bool commentPending;

  /// True when the related comment was deleted (e.g. discarded by a mentor).
  final bool commentDeleted;

  const DisciplerActivityModel({
    required this.id,
    required this.kind,
    this.postId,
    this.commentId,
    this.reaction,
    this.language,
    required this.summary,
    this.reviewedAt,
    required this.createdAt,
    this.postContent,
    this.postType,
    this.topicTitle,
    this.commentContent,
    this.commentPending = false,
    this.commentDeleted = false,
  });

  /// Creates a [DisciplerActivityModel] from a JSON map (API response).
  factory DisciplerActivityModel.fromJson(Map<String, dynamic> json) {
    final post = json['post'] as Map<String, dynamic>?;
    final comment = json['comment'] as Map<String, dynamic>?;

    return DisciplerActivityModel(
      id: json['id'] as String,
      kind: json['kind'] as String,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      reaction: json['reaction'] as String?,
      language: json['language'] as String?,
      summary: json['summary'] as String,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String,
      postContent: post?['content'] as String?,
      postType: post?['post_type'] as String?,
      topicTitle: post?['topic_title'] as String?,
      commentContent: comment?['content'] as String?,
      commentPending: (comment?['is_pending_review'] as bool?) ?? false,
      commentDeleted: (comment?['is_deleted'] as bool?) ?? false,
    );
  }

  /// Converts this model to a [DisciplerActivityEntity] for use in the domain layer.
  DisciplerActivityEntity toEntity() => DisciplerActivityEntity(
        id: id,
        kind: kind,
        postId: postId,
        commentId: commentId,
        reaction: reaction,
        language: language,
        summary: summary,
        reviewedAt: reviewedAt,
        createdAt: createdAt,
        postContent: postContent,
        postType: postType,
        topicTitle: topicTitle,
        commentContent: commentContent,
        commentPending: commentPending,
        commentDeleted: commentDeleted,
      );
}
