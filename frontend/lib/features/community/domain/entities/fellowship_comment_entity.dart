import 'package:equatable/equatable.dart';

import '../../../../core/constants/discipler.dart';

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

  /// True when this is a Discipler-authored draft awaiting mentor review.
  final bool isPendingReview;

  /// True when the comment content mentions the Discipler AI helper.
  final bool mentionsDiscipler;

  /// For Discipler replies that reference a generated study guide: the
  /// foreign-key reference to `study_guides`.
  final String? studyGuideId;

  /// Title of the referenced study guide, if any.
  final String? guideTitle;

  /// Input type used to generate the referenced guide (`'scripture'` or
  /// `'topic'`).
  final String? guideInputType;

  /// Input value used to generate the referenced guide.
  final String? guideInputValue;

  /// Language of the referenced guide (`'en'`, `'hi'`, or `'ml'`).
  final String? guideLanguage;

  const FellowshipCommentEntity({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    this.isPendingReview = false,
    this.mentionsDiscipler = false,
    this.studyGuideId,
    this.guideTitle,
    this.guideInputType,
    this.guideInputValue,
    this.guideLanguage,
  });

  /// True when this comment's author is the Discipler AI helper.
  bool get authorIsSystem => authorUserId == kDisciplerUserId;

  /// True when this comment references a generated study guide.
  bool get hasGuide =>
      studyGuideId != null ||
      (guideInputValue != null && guideInputType != null);

  /// Returns a copy of this comment with select fields replaced.
  FellowshipCommentEntity copyWith({bool? isPendingReview}) {
    return FellowshipCommentEntity(
      id: id,
      postId: postId,
      authorUserId: authorUserId,
      content: content,
      isDeleted: isDeleted,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      isPendingReview: isPendingReview ?? this.isPendingReview,
      mentionsDiscipler: mentionsDiscipler,
      studyGuideId: studyGuideId,
      guideTitle: guideTitle,
      guideInputType: guideInputType,
      guideInputValue: guideInputValue,
      guideLanguage: guideLanguage,
    );
  }

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
        isPendingReview,
        mentionsDiscipler,
        studyGuideId,
        guideTitle,
        guideInputType,
        guideInputValue,
        guideLanguage,
      ];
}
