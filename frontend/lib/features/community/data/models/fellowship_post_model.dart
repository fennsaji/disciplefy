import '../../domain/entities/fellowship_post_entity.dart';

/// Data model for a post within a fellowship feed returned by the API.
///
/// A post is a piece of content shared by a fellowship member. It may be a
/// general message, a prayer request, a praise report, or a question. The
/// backend enriches each post with author display info and the current user's
/// reaction so the UI does not need a separate lookup.
class FellowshipPostModel {
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

  /// ID of the learning-path topic this post belongs to, or null.
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

  const FellowshipPostModel({
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

  /// Creates a [FellowshipPostModel] from a JSON map (API response).
  ///
  /// The `reaction_counts` field is stored as JSONB in the database and arrives
  /// as a `Map<String, dynamic>` over the wire; each value is cast to [int].
  factory FellowshipPostModel.fromJson(Map<String, dynamic> json) {
    final rawReactions =
        (json['reaction_counts'] as Map<String, dynamic>?) ?? {};
    final reactionCounts = rawReactions.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    return FellowshipPostModel(
      id: json['id'] as String,
      fellowshipId: json['fellowship_id'] as String,
      authorUserId: json['author_user_id'] as String,
      content: json['content'] as String,
      postType: json['post_type'] as String,
      reactionCounts: reactionCounts,
      isDeleted: json['is_deleted'] as bool,
      createdAt: json['created_at'] as String,
      authorDisplayName: json['author_display_name'] as String,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      userReaction: json['user_reaction'] as String?,
      commentCount: (json['comment_count'] as num).toInt(),
      topicId: json['topic_id'] as String?,
      topicTitle: json['topic_title'] as String?,
      guideTitle: json['guide_title'] as String?,
      lessonIndex: json['lesson_index'] as int?,
      studyGuideId: json['study_guide_id'] as String?,
      guideInputType: json['guide_input_type'] as String?,
      guideLanguage: json['guide_language'] as String?,
    );
  }

  /// Converts this model to a [FellowshipPostEntity] for use in the domain layer.
  FellowshipPostEntity toEntity() => FellowshipPostEntity(
        id: id,
        fellowshipId: fellowshipId,
        authorUserId: authorUserId,
        content: content,
        postType: postType,
        reactionCounts: reactionCounts,
        isDeleted: isDeleted,
        createdAt: createdAt,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        userReaction: userReaction,
        commentCount: commentCount,
        topicId: topicId,
        topicTitle: topicTitle,
        guideTitle: guideTitle,
        lessonIndex: lessonIndex,
        studyGuideId: studyGuideId,
        guideInputType: guideInputType,
        guideLanguage: guideLanguage,
      );
}
