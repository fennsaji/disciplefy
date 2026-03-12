import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../features/community/domain/entities/fellowship_comment_entity.dart';
import '../../../../../features/community/domain/entities/fellowship_post_entity.dart';
import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'fellowship_feed_event.dart';
import 'fellowship_feed_state.dart';

/// Page size used for all paginated feed requests.
const int _kPageLimit = 20;

/// BLoC that manages the paginated post feed for a single fellowship, plus
/// post creation, deletion, and reaction-toggle operations.
///
/// Inject [CommunityRepository] via the constructor.
class FellowshipFeedBloc
    extends Bloc<FellowshipFeedEvent, FellowshipFeedState> {
  final CommunityRepository _repository;

  FellowshipFeedBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipFeedState.initial()) {
    on<FellowshipFeedInitialized>(_onInitialized);
    on<FellowshipFeedLoadRequested>(_onLoadRequested);
    on<FellowshipFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<FellowshipPostCreateRequested>(_onPostCreateRequested);
    on<FellowshipPostDeleteRequested>(_onPostDeleteRequested);
    on<FellowshipReactionToggleRequested>(_onReactionToggleRequested);
    on<FellowshipCommentsOpenRequested>(_onCommentsOpenRequested);
    on<FellowshipCommentCreateRequested>(_onCommentCreateRequested);
    on<FellowshipCommentDeleteRequested>(_onCommentDeleteRequested);
    on<FellowshipReportRequested>(_onReportRequested);
    on<FellowshipTopicCountsRequested>(_onTopicCountsRequested);
  }

  Future<void> _onInitialized(
    FellowshipFeedInitialized event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(
      isMentor: event.isMentor,
      currentUserId: event.currentUserId,
    ));
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Loads the first page, resetting all pagination state.
  Future<void> _onLoadRequested(
    FellowshipFeedLoadRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(
      status: FellowshipFeedStatus.loading,
      posts: [],
      clearCursor: true,
      hasMore: true,
      clearErrorMessage: true,
    ));

    final result = await _repository.getFellowshipPosts(
      fellowshipId: event.fellowshipId,
      topicId: event.topicId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipFeedStatus.failure,
        errorMessage: failure.message,
      )),
      (posts) => emit(state.copyWith(
        status: FellowshipFeedStatus.success,
        posts: posts,
        cursor: _extractCursor(posts),
        hasMore: posts.length >= _kPageLimit,
        clearErrorMessage: true,
      )),
    );
  }

  /// Fetches the next page using the cursor in state and appends results.
  Future<void> _onLoadMoreRequested(
    FellowshipFeedLoadMoreRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    // Guard: no-op if there are no more pages or a load is already running.
    if (!state.hasMore || state.status == FellowshipFeedStatus.loading) return;

    final result = await _repository.getFellowshipPosts(
      fellowshipId: event.fellowshipId,
      cursor: state.cursor,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipFeedStatus.failure,
        errorMessage: failure.message,
      )),
      (newPosts) {
        final appended = [...state.posts, ...newPosts];
        emit(state.copyWith(
          status: FellowshipFeedStatus.success,
          posts: appended,
          cursor: _extractCursor(newPosts),
          hasMore: newPosts.length >= _kPageLimit,
          clearErrorMessage: true,
        ));
      },
    );
  }

  /// Creates a post and prepends it to the existing list on success.
  Future<void> _onPostCreateRequested(
    FellowshipPostCreateRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(submitting: true));

    final result = await _repository.createPost(
      fellowshipId: event.fellowshipId,
      content: event.content,
      postType: event.postType,
      topicId: event.topicId,
      topicTitle: event.topicTitle,
      guideTitle: event.guideTitle,
      lessonIndex: event.lessonIndex,
      studyGuideId: event.studyGuideId,
      guideInputType: event.guideInputType,
      guideLanguage: event.guideLanguage,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        submitting: false,
        errorMessage: failure.message,
      )),
      (newPost) => emit(state.copyWith(
        submitting: false,
        posts: [newPost, ...state.posts],
        clearErrorMessage: true,
      )),
    );
  }

  /// Removes the post optimistically from the local list, then calls the
  /// repository. If the delete fails the post is not re-inserted (the user
  /// can pull-to-refresh); the error is surfaced via [errorMessage].
  Future<void> _onPostDeleteRequested(
    FellowshipPostDeleteRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    // Optimistic removal.
    final updatedPosts =
        state.posts.where((p) => p.id != event.postId).toList();
    emit(state.copyWith(
      submitting: true,
      posts: updatedPosts,
    ));

    final result = await _repository.deletePost(event.postId);

    result.fold(
      (failure) => emit(state.copyWith(
        submitting: false,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        submitting: false,
        clearErrorMessage: true,
      )),
    );
  }

  /// Calls [CommunityRepository.toggleReaction] and patches only the
  /// [reactionCounts] field of the matching post in the list.
  Future<void> _onReactionToggleRequested(
    FellowshipReactionToggleRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final result = await _repository.toggleReaction(
      postId: event.postId,
      reactionType: event.reactionType,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (updatedCounts) {
        final updatedPosts = state.posts.map((post) {
          if (post.id != event.postId) return post;
          return FellowshipPostEntity(
            id: post.id,
            fellowshipId: post.fellowshipId,
            authorUserId: post.authorUserId,
            content: post.content,
            postType: post.postType,
            reactionCounts: updatedCounts,
            isDeleted: post.isDeleted,
            createdAt: post.createdAt,
            authorDisplayName: post.authorDisplayName,
            authorAvatarUrl: post.authorAvatarUrl,
            userReaction: _resolveUserReaction(
              previous: post.userReaction,
              toggled: event.reactionType,
              updatedCounts: updatedCounts,
            ),
            commentCount: post.commentCount,
            topicId: post.topicId,
            topicTitle: post.topicTitle,
            guideTitle: post.guideTitle,
            lessonIndex: post.lessonIndex,
            studyGuideId: post.studyGuideId,
            guideInputType: post.guideInputType,
            guideLanguage: post.guideLanguage,
          );
        }).toList();

        emit(state.copyWith(
          posts: updatedPosts,
          clearErrorMessage: true,
        ));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Comment handlers
  // ---------------------------------------------------------------------------

  Future<void> _onCommentsOpenRequested(
    FellowshipCommentsOpenRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(
      activePostId: event.postId,
      comments: const [],
      commentsStatus: FellowshipCommentsStatus.loading,
    ));

    final result = await _repository.getComments(event.postId);

    result.fold(
      (failure) => emit(state.copyWith(
        commentsStatus: FellowshipCommentsStatus.failure,
        errorMessage: failure.message,
      )),
      (comments) => emit(state.copyWith(
        commentsStatus: FellowshipCommentsStatus.success,
        comments: comments,
      )),
    );
  }

  Future<void> _onCommentCreateRequested(
    FellowshipCommentCreateRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final postId = state.activePostId;
    if (postId == null) return;
    emit(state.copyWith(commentSubmitting: true));

    final result = await _repository.createComment(
      postId: postId,
      content: event.content,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        commentSubmitting: false,
        errorMessage: failure.message,
      )),
      (newComment) {
        // Increment commentCount on the matching post.
        final updatedPosts = state.posts.map((p) {
          if (p.id != postId) return p;
          return FellowshipPostEntity(
            id: p.id,
            fellowshipId: p.fellowshipId,
            authorUserId: p.authorUserId,
            content: p.content,
            postType: p.postType,
            reactionCounts: p.reactionCounts,
            isDeleted: p.isDeleted,
            createdAt: p.createdAt,
            authorDisplayName: p.authorDisplayName,
            authorAvatarUrl: p.authorAvatarUrl,
            userReaction: p.userReaction,
            commentCount: p.commentCount + 1,
          );
        }).toList();
        emit(state.copyWith(
          commentSubmitting: false,
          comments: [...state.comments, newComment],
          posts: updatedPosts,
        ));
      },
    );
  }

  Future<void> _onCommentDeleteRequested(
    FellowshipCommentDeleteRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final result = await _repository.deleteComment(event.commentId);

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        // Remove comment from local list and decrement post count.
        final updatedComments =
            state.comments.where((c) => c.id != event.commentId).toList();
        final updatedPosts = state.posts.map((p) {
          if (p.id != event.postId) return p;
          return FellowshipPostEntity(
            id: p.id,
            fellowshipId: p.fellowshipId,
            authorUserId: p.authorUserId,
            content: p.content,
            postType: p.postType,
            reactionCounts: p.reactionCounts,
            isDeleted: p.isDeleted,
            createdAt: p.createdAt,
            authorDisplayName: p.authorDisplayName,
            authorAvatarUrl: p.authorAvatarUrl,
            userReaction: p.userReaction,
            commentCount: (p.commentCount - 1).clamp(0, p.commentCount),
          );
        }).toList();
        emit(state.copyWith(
          comments: updatedComments,
          posts: updatedPosts,
        ));
      },
    );
  }

  Future<void> _onReportRequested(
    FellowshipReportRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(reportStatus: FellowshipReportStatus.loading));

    final result = await _repository.reportContent(
      fellowshipId: event.fellowshipId,
      contentType: event.contentType,
      contentId: event.contentId,
      reason: event.reason,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        reportStatus: FellowshipReportStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(reportStatus: FellowshipReportStatus.success)),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extracts a pagination cursor from the last post in [posts].
  ///
  /// Uses the [createdAt] timestamp of the oldest (last) post as the opaque
  /// cursor string that the backend expects.  Returns null when [posts] is
  /// empty.
  String? _extractCursor(List<FellowshipPostEntity> posts) {
    if (posts.isEmpty) return null;
    return posts.last.createdAt;
  }

  /// Resolves the new [userReaction] value after a toggle:
  /// - If the server no longer has any count for [toggled], the reaction was
  ///   removed → return null.
  /// - Otherwise keep [toggled] as the active reaction.
  String? _resolveUserReaction({
    required String? previous,
    required String toggled,
    required Map<String, int> updatedCounts,
  }) {
    final count = updatedCounts[toggled] ?? 0;
    if (count == 0) return null;
    return toggled;
  }

  Future<void> _onTopicCountsRequested(
    FellowshipTopicCountsRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final result = await _repository.getTopicPostCounts(event.fellowshipId);
    result.fold(
      (_) {},
      (counts) => emit(state.copyWith(topicPostCounts: counts)),
    );
  }
}
