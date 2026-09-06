import 'package:equatable/equatable.dart';

/// Domain entity representing a single Discipler activity feed item.
///
/// Surfaces what the Discipler AI helper has done in a fellowship — a
/// drafted or answered reply, a reaction, or a daily study post — so mentors
/// can review or audit it. Produced by [DisciplerActivityModel.toEntity].
class DisciplerActivityEntity extends Equatable {
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

  const DisciplerActivityEntity({
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

  @override
  List<Object?> get props => [
        id,
        kind,
        postId,
        commentId,
        reaction,
        language,
        summary,
        reviewedAt,
        createdAt,
        postContent,
        postType,
        topicTitle,
        commentContent,
        commentPending,
        commentDeleted,
      ];
}
