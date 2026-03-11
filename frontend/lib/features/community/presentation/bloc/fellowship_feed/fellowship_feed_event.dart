import 'package:equatable/equatable.dart';

/// Base class for all [FellowshipFeedBloc] events.
abstract class FellowshipFeedEvent extends Equatable {
  const FellowshipFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes the feed BLoC with the current user's context.
/// Called once when [FellowshipHomeScreen] is first built.
class FellowshipFeedInitialized extends FellowshipFeedEvent {
  final bool isMentor;
  final String? currentUserId;

  const FellowshipFeedInitialized({
    required this.isMentor,
    this.currentUserId,
  });

  @override
  List<Object?> get props => [isMentor, currentUserId];
}

/// Loads the first page of posts for the given fellowship, discarding any
/// previously held posts and resetting the pagination cursor.
class FellowshipFeedLoadRequested extends FellowshipFeedEvent {
  /// The ID of the fellowship whose feed should be loaded.
  final String fellowshipId;

  /// When non-null, only posts attached to this topic (guide discussion) are
  /// loaded. When null, only posts with no topic (main feed) are loaded.
  final String? topicId;

  const FellowshipFeedLoadRequested({
    required this.fellowshipId,
    this.topicId,
  });

  @override
  List<Object?> get props => [fellowshipId, topicId];
}

/// Appends the next page of posts to the existing list using the current
/// cursor held in state.
class FellowshipFeedLoadMoreRequested extends FellowshipFeedEvent {
  /// The ID of the fellowship whose feed is being paginated.
  final String fellowshipId;

  const FellowshipFeedLoadMoreRequested({required this.fellowshipId});

  @override
  List<Object?> get props => [fellowshipId];
}

/// Creates a new post in the fellowship feed.
class FellowshipPostCreateRequested extends FellowshipFeedEvent {
  /// The ID of the fellowship to post into.
  final String fellowshipId;

  /// The text body of the new post.
  final String content;

  /// One of: `'general'`, `'prayer'`, `'praise'`, `'question'`.
  final String postType;

  /// When non-null, attaches the post to a specific guide discussion.
  final String? topicId;

  /// Human-readable title of the topic/guide discussion thread.
  final String? topicTitle;

  /// Human-readable title of the study guide being referenced.
  final String? guideTitle;

  /// Zero-based index of the lesson within the guide.
  final int? lessonIndex;

  /// The ID of the study guide being referenced.
  final String? studyGuideId;

  /// Input type used to generate the guide (e.g. `'book'`, `'topic'`).
  final String? guideInputType;

  /// Language code of the guide (e.g. `'en'`, `'hi'`, `'ml'`).
  final String? guideLanguage;

  const FellowshipPostCreateRequested({
    required this.fellowshipId,
    required this.content,
    required this.postType,
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
        fellowshipId,
        content,
        postType,
        topicId,
        topicTitle,
        guideTitle,
        lessonIndex,
        studyGuideId,
        guideInputType,
        guideLanguage,
      ];
}

/// Deletes the post identified by [postId] from the feed.
class FellowshipPostDeleteRequested extends FellowshipFeedEvent {
  /// The ID of the post to delete.
  final String postId;

  const FellowshipPostDeleteRequested({required this.postId});

  @override
  List<Object?> get props => [postId];
}

/// Toggles the current user's reaction on a post.
class FellowshipReactionToggleRequested extends FellowshipFeedEvent {
  /// The ID of the post to react to.
  final String postId;

  /// The reaction type string, e.g. `'amen'`, `'heart'`.
  final String reactionType;

  const FellowshipReactionToggleRequested({
    required this.postId,
    required this.reactionType,
  });

  @override
  List<Object?> get props => [postId, reactionType];
}

/// Opens the comments sheet for a post, loading its comments.
class FellowshipCommentsOpenRequested extends FellowshipFeedEvent {
  final String postId;

  const FellowshipCommentsOpenRequested({required this.postId});

  @override
  List<Object?> get props => [postId];
}

/// Submits a new comment on the active post (set by [FellowshipCommentsOpenRequested]).
class FellowshipCommentCreateRequested extends FellowshipFeedEvent {
  final String content;

  const FellowshipCommentCreateRequested({required this.content});

  @override
  List<Object?> get props => [content];
}

/// Deletes the comment identified by [commentId] from [postId].
class FellowshipCommentDeleteRequested extends FellowshipFeedEvent {
  final String commentId;
  final String postId;

  const FellowshipCommentDeleteRequested({
    required this.commentId,
    required this.postId,
  });

  @override
  List<Object?> get props => [commentId, postId];
}

/// Reports a post or comment to fellowship admins.
///
/// [contentType] must be `'post'` or `'comment'`.
class FellowshipReportRequested extends FellowshipFeedEvent {
  final String fellowshipId;
  final String contentType;
  final String contentId;
  final String reason;

  const FellowshipReportRequested({
    required this.fellowshipId,
    required this.contentType,
    required this.contentId,
    required this.reason,
  });

  @override
  List<Object?> get props => [fellowshipId, contentType, contentId, reason];
}

class FellowshipTopicCountsRequested extends FellowshipFeedEvent {
  final String fellowshipId;
  const FellowshipTopicCountsRequested({required this.fellowshipId});
  @override
  List<Object?> get props => [fellowshipId];
}
