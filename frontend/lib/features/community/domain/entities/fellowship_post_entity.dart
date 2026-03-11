import 'package:equatable/equatable.dart';

/// Domain entity representing a post within a fellowship feed.
///
/// A post is a piece of content shared by a fellowship member. It may be a
/// general message, a prayer request, a praise report, or a question. The
/// entity carries enriched author display info and the current user's reaction
/// so the UI does not need a separate lookup.
///
/// This is a pure business-logic object with no JSON parsing. It is produced
/// by [FellowshipPostModel.toEntity] and consumed by the domain and
/// presentation layers.
class FellowshipPostEntity extends Equatable {
  /// Unique identifier for the post.
  final String id;

  /// The ID of the fellowship this post belongs to.
  final String fellowshipId;

  /// The Supabase Auth UID of the user who created this post.
  final String authorUserId;

  /// The text body of the post.
  final String content;

  /// Post category: `'general'`, `'prayer'`, `'praise'`, or `'question'`.
  final String postType;

  /// Reaction emoji counts keyed by emoji string, e.g. `{'🙏': 3, '❤️': 1}`.
  final Map<String, int> reactionCounts;

  /// Whether this post has been soft-deleted.
  final bool isDeleted;

  /// ISO-8601 timestamp when the post was created.
  final String createdAt;

  /// Display name of the post author (enriched by the backend).
  final String authorDisplayName;

  /// Avatar URL of the post author, or null if not set.
  final String? authorAvatarUrl;

  /// The emoji reaction the current user has applied to this post, or null.
  final String? userReaction;

  /// Total number of comments on this post.
  final int commentCount;

  /// ID of the learning-path topic this post belongs to, or null for the
  /// main fellowship feed.
  final String? topicId;

  /// For `study_note` posts: the title of the lesson within the topic.
  final String? topicTitle;

  /// For `study_note` and `shared_guide` posts: the learning-path or guide
  /// name.
  final String? guideTitle;

  /// For `study_note` posts: the 1-based lesson number within the topic.
  final int? lessonIndex;

  /// For `shared_guide` posts: the foreign-key reference to `study_guides`.
  final String? studyGuideId;

  /// For `shared_guide` posts: the input type used to generate the guide
  /// (`'scripture'` or `'topic'`).
  final String? guideInputType;

  /// For `shared_guide` posts: the language of the guide
  /// (`'en'`, `'hi'`, or `'ml'`).
  final String? guideLanguage;

  const FellowshipPostEntity({
    required this.id,
    required this.fellowshipId,
    required this.authorUserId,
    required this.content,
    required this.postType,
    required this.reactionCounts,
    required this.isDeleted,
    required this.createdAt,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    this.userReaction,
    required this.commentCount,
    this.topicId,
    this.topicTitle,
    this.guideTitle,
    this.lessonIndex,
    this.studyGuideId,
    this.guideInputType,
    this.guideLanguage,
  });

  @override
  List<Object?> get props => [
        id,
        fellowshipId,
        authorUserId,
        content,
        postType,
        reactionCounts,
        isDeleted,
        createdAt,
        authorDisplayName,
        authorAvatarUrl,
        userReaction,
        commentCount,
        topicId,
        topicTitle,
        guideTitle,
        lessonIndex,
        studyGuideId,
        guideInputType,
        guideLanguage,
      ];
}
