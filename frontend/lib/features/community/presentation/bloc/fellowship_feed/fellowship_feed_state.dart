import 'package:equatable/equatable.dart';

import '../../../../../features/community/domain/entities/fellowship_comment_entity.dart';
import '../../../../../features/community/domain/entities/fellowship_post_entity.dart';

/// Describes the primary load / pagination lifecycle for the fellowship feed.
enum FellowshipFeedStatus { initial, loading, success, failure }

/// Status of the comments for the currently active post.
enum FellowshipCommentsStatus { initial, loading, success, failure }

/// Status of a report-content operation.
enum FellowshipReportStatus { idle, loading, success, failure }

/// Single immutable state for [FellowshipFeedBloc].
///
/// Use [copyWith] to produce updated snapshots; never mutate fields directly.
class FellowshipFeedState extends Equatable {
  /// Primary load status (initial fetch or a hard refresh).
  final FellowshipFeedStatus status;

  /// The posts currently held in the feed, in reverse-chronological order.
  final List<FellowshipPostEntity> posts;

  /// Opaque pagination cursor (ISO-8601 timestamp or server-supplied string).
  ///
  /// Null when no page has been fetched yet or when [hasMore] is false.
  final String? cursor;

  /// Whether the server indicated there are more pages to fetch.
  final bool hasMore;

  /// Non-null when [status] is [FellowshipFeedStatus.failure].
  final String? errorMessage;

  /// True while a post create or delete operation is in flight.
  final bool submitting;

  /// True when the current user is a mentor of this fellowship.
  final bool isMentor;

  /// The current user's Supabase auth UID. Used to gate the delete button.
  final String? currentUserId;

  // ── Comments state ─────────────────────────────────────────────────────────

  /// The post whose comments are currently loaded (set when sheet opens).
  final String? activePostId;

  /// Comments for the currently active post.
  final List<FellowshipCommentEntity> comments;

  /// Load status for the comments sheet.
  final FellowshipCommentsStatus commentsStatus;

  /// True while a comment is being submitted.
  final bool commentSubmitting;

  /// Status of the most recent report-content operation.
  final FellowshipReportStatus reportStatus;

  /// Per-topic post counts (`topicId → count`). Populated lazily when the
  /// Lessons tab requests topic counts.
  final Map<String, int> topicPostCounts;

  const FellowshipFeedState({
    this.status = FellowshipFeedStatus.initial,
    this.posts = const [],
    this.cursor,
    this.hasMore = true,
    this.errorMessage,
    this.submitting = false,
    this.isMentor = false,
    this.currentUserId,
    this.activePostId,
    this.comments = const [],
    this.commentsStatus = FellowshipCommentsStatus.initial,
    this.commentSubmitting = false,
    this.reportStatus = FellowshipReportStatus.idle,
    this.topicPostCounts = const {},
  });

  /// Returns the initial state (used as the BLoC seed value).
  const FellowshipFeedState.initial() : this();

  @override
  List<Object?> get props => [
        status,
        posts,
        cursor,
        hasMore,
        errorMessage,
        submitting,
        isMentor,
        currentUserId,
        activePostId,
        comments,
        commentsStatus,
        commentSubmitting,
        reportStatus,
        topicPostCounts,
      ];

  /// Creates a copy of this state with the provided fields replaced.
  FellowshipFeedState copyWith({
    FellowshipFeedStatus? status,
    List<FellowshipPostEntity>? posts,
    String? cursor,
    bool clearCursor = false,
    bool? hasMore,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? submitting,
    bool? isMentor,
    String? currentUserId,
    String? activePostId,
    List<FellowshipCommentEntity>? comments,
    FellowshipCommentsStatus? commentsStatus,
    bool? commentSubmitting,
    FellowshipReportStatus? reportStatus,
    Map<String, int>? topicPostCounts,
  }) {
    return FellowshipFeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      hasMore: hasMore ?? this.hasMore,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      submitting: submitting ?? this.submitting,
      isMentor: isMentor ?? this.isMentor,
      currentUserId: currentUserId ?? this.currentUserId,
      activePostId: activePostId ?? this.activePostId,
      comments: comments ?? this.comments,
      commentsStatus: commentsStatus ?? this.commentsStatus,
      commentSubmitting: commentSubmitting ?? this.commentSubmitting,
      reportStatus: reportStatus ?? this.reportStatus,
      topicPostCounts: topicPostCounts ?? this.topicPostCounts,
    );
  }
}
