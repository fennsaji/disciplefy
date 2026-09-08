import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection_container.dart';
import '../../../../../core/services/language_preference_service.dart';
import '../../../../../features/community/domain/entities/fellowship_comment_entity.dart';
import '../../../../../features/community/domain/entities/fellowship_post_entity.dart';
import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'fellowship_feed_event.dart';
import 'fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';

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
    on<FellowshipFeedContextRequested>(_onContextRequested);
    on<FellowshipFeedLoadRequested>(_onLoadRequested);
    on<FellowshipFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<FellowshipPostCreateRequested>(_onPostCreateRequested);
    on<FellowshipPostDeleteRequested>(_onPostDeleteRequested);
    on<FellowshipReactionToggleRequested>(_onReactionToggleRequested);
    on<FellowshipCommentsOpenRequested>(_onCommentsOpenRequested);
    on<FellowshipCommentCreateRequested>(_onCommentCreateRequested);
    on<FellowshipCommentDeleteRequested>(_onCommentDeleteRequested);
    on<FellowshipReportRequested>(_onReportRequested);
    on<FellowshipBlockUserRequested>(_onBlockUserRequested);
    on<FellowshipTopicCountsRequested>(_onTopicCountsRequested);
    on<FellowshipDisciplerCommentReviewed>(_onDisciplerCommentReviewed);
  }

  Future<void> _onInitialized(
    FellowshipFeedInitialized event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    emit(state.copyWith(
      isMentor: event.isMentor,
      currentUserId: event.currentUserId,
      postingPermission: event.postingPermission,
      postingContextResolved: event.postingContextResolved,
      disciplerAllowed: event.disciplerAllowed,
      mentors: event.mentors,
    ));
  }

  /// Fetches authoritative posting context from the server and updates the
  /// posting permission + mentor flag. Self-correcting: the optimistic values
  /// passed to [FellowshipFeedInitialized] may be stale or absent (deep link /
  /// web refresh), so this overrides them once the network responds.
  Future<void> _onContextRequested(
    FellowshipFeedContextRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final lang =
        await sl<LanguagePreferenceService>().getStudyContentLanguage();
    final result =
        await _repository.getFellowship(event.fellowshipId, lang.code);

    result.fold(
      // On failure, fall back to whatever optimistic values we have but still
      // mark resolved so the button isn't hidden forever.
      (_) => emit(state.copyWith(postingContextResolved: true)),
      (data) {
        final role = data['caller_role'] as String?;
        final permission = data['posting_permission'] as String?;
        emit(state.copyWith(
          postingPermission: permission ?? state.postingPermission,
          isMentor: role != null ? role == 'mentor' : state.isMentor,
          postingContextResolved: true,
        ));
      },
    );
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
        // Not an error to apologise for: the viewer simply has not joined.
        notAMember: failure is AuthorizationFailure,
      )),
      (posts) => emit(state.copyWith(
        status: FellowshipFeedStatus.success,
        posts: posts,
        notAMember: false,
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
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
      disciplerReplyOptOut: event.disciplerReplyOptOut,
      mentionedUserIds: event.mentionedUserIds,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        submitting: false,
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
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
      (failure) => emit(state.copyWith(
          errorMessage: ErrorMessageSanitizer.sanitize(failure))),
      (updatedCounts) {
        final updatedPosts = state.posts.map((post) {
          if (post.id != event.postId) return post;
          final resolvedReaction = _resolveUserReaction(
            previous: post.userReaction,
            toggled: event.reactionType,
            updatedCounts: updatedCounts,
          );
          return post.copyWith(
            reactionCounts: updatedCounts,
            userReaction: resolvedReaction,
            clearUserReaction: resolvedReaction == null,
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (newComment) {
        // Increment commentCount on the matching post.
        final updatedPosts = state.posts.map((p) {
          if (p.id != postId) return p;
          return p.copyWith(commentCount: p.commentCount + 1);
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
      (failure) => emit(state.copyWith(
          errorMessage: ErrorMessageSanitizer.sanitize(failure))),
      (_) {
        // Remove comment from local list and decrement post count.
        final updatedComments =
            state.comments.where((c) => c.id != event.commentId).toList();
        final updatedPosts = state.posts.map((p) {
          if (p.id != event.postId) return p;
          return p.copyWith(
              commentCount: (p.commentCount - 1).clamp(0, p.commentCount));
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
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (_) => emit(state.copyWith(reportStatus: FellowshipReportStatus.success)),
    );
  }

  /// Blocks a user and strips their content from the feed immediately.
  ///
  /// Removal happens before the network call completes because App Review
  /// checks that blocked content disappears instantly. On failure the removed
  /// posts and comments are restored.
  Future<void> _onBlockUserRequested(
    FellowshipBlockUserRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final previousPosts = state.posts;
    final previousComments = state.comments;

    emit(state.copyWith(
      blockStatus: FellowshipBlockStatus.loading,
      posts: previousPosts
          .where((p) => p.authorUserId != event.blockedUserId)
          .toList(),
      comments: previousComments
          .where((c) => c.authorUserId != event.blockedUserId)
          .toList(),
      clearErrorMessage: true,
    ));

    final result = await _repository.blockUser(
      blockedUserId: event.blockedUserId,
      fellowshipId: event.fellowshipId,
      contentType: event.contentType,
      contentId: event.contentId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        blockStatus: FellowshipBlockStatus.failure,
        posts: previousPosts,
        comments: previousComments,
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (_) => emit(state.copyWith(blockStatus: FellowshipBlockStatus.success)),
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

  /// Approves or discards a Discipler-authored draft comment. On approval
  /// the comment's [FellowshipCommentEntity.isPendingReview] flag is cleared
  /// in place; on discard the comment is removed from the local list.
  Future<void> _onDisciplerCommentReviewed(
    FellowshipDisciplerCommentReviewed event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final result = event.approve
        ? await _repository.approveDisciplerComment(event.commentId)
        : await _repository.discardDisciplerComment(event.commentId);

    result.fold(
      (failure) => emit(state.copyWith(
          errorMessage: ErrorMessageSanitizer.sanitize(failure))),
      (_) {
        final updated = event.approve
            ? state.comments
                .map((c) => c.id == event.commentId
                    ? c.copyWith(isPendingReview: false)
                    : c)
                .toList()
            : state.comments.where((c) => c.id != event.commentId).toList();
        emit(state.copyWith(comments: updated, clearErrorMessage: true));
      },
    );
  }
}
