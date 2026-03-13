import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/fellowship_comment_entity.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/entities/fellowship_meeting_entity.dart';
import '../../domain/entities/fellowship_member_entity.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../../domain/entities/public_fellowship_entity.dart';
import '../../domain/entities/sync_calendar_result.dart';
import '../../domain/repositories/community_repository.dart';
import '../datasources/community_remote_datasource.dart';

/// [CommunityRemoteDatasource]-backed implementation of [CommunityRepository].
///
/// Each method delegates to the datasource, maps model results to entities
/// via [toEntity()], and wraps the outcome in [Either]:
/// - Success → [Right]
/// - [ServerException] / [NetworkException] / unexpected errors → [Left]
class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDatasource _datasource;

  CommunityRepositoryImpl({required CommunityRemoteDatasource datasource})
      : _datasource = datasource;

  // ---------------------------------------------------------------------------
  // Fellowship list
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<FellowshipEntity>>> getFellowships() async {
    try {
      final models = await _datasource.getFellowships();
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch fellowships: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship members
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<FellowshipMemberEntity>>> getFellowshipMembers(
      String fellowshipId) async {
    try {
      final models = await _datasource.getFellowshipMembers(fellowshipId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to fetch fellowship members: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — list (paginated)
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<FellowshipPostEntity>>> getFellowshipPosts({
    required String fellowshipId,
    String? cursor,
    int limit = 20,
    String? topicId,
  }) async {
    try {
      final models = await _datasource.getFellowshipPosts(
        fellowshipId: fellowshipId,
        cursor: cursor,
        limit: limit,
        topicId: topicId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to fetch fellowship posts: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, FellowshipPostEntity>> createPost({
    required String fellowshipId,
    required String content,
    required String postType,
    String? topicId,
    String? topicTitle,
    String? guideTitle,
    int? lessonIndex,
    String? studyGuideId,
    String? guideInputType,
    String? guideLanguage,
  }) async {
    try {
      final model = await _datasource.createPost(
        fellowshipId: fellowshipId,
        content: content,
        postType: postType,
        topicId: topicId,
        topicTitle: topicTitle,
        guideTitle: guideTitle,
        lessonIndex: lessonIndex,
        studyGuideId: studyGuideId,
        guideInputType: guideInputType,
        guideLanguage: guideLanguage,
      );
      return Right(model.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create post: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — delete
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      await _datasource.deletePost(postId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete post: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — list
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<FellowshipCommentEntity>>> getComments(
      String postId) async {
    try {
      final models = await _datasource.getComments(postId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch comments: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, FellowshipCommentEntity>> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final model = await _datasource.createComment(
        postId: postId,
        content: content,
      );
      return Right(model.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create comment: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — delete
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      await _datasource.deleteComment(commentId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete comment: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Reactions — toggle
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Map<String, int>>> toggleReaction({
    required String postId,
    required String reactionType,
  }) async {
    try {
      final counts = await _datasource.toggleReaction(
        postId: postId,
        reactionType: reactionType,
      );
      return Right(counts);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to toggle reaction: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Invite — join fellowship
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> joinFellowship(String inviteToken) async {
    try {
      await _datasource.joinFellowship(inviteToken);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to join fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> createFellowship({
    required String name,
    String? description,
    int? maxMembers,
    bool isPublic = false,
    String language = 'en',
  }) async {
    try {
      await _datasource.createFellowship(
        name: name,
        description: description,
        maxMembers: maxMembers,
        isPublic: isPublic,
        language: language,
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship study — set
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, String>> setFellowshipStudy({
    required String fellowshipId,
    required String learningPathId,
  }) async {
    try {
      final title = await _datasource.setFellowshipStudy(
        fellowshipId: fellowshipId,
        learningPathId: learningPathId,
      );
      return Right(title);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to set fellowship study: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship study — advance
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Map<String, dynamic>>> advanceStudy(
      String fellowshipId) async {
    try {
      final result = await _datasource.advanceStudy(fellowshipId);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to advance study: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — leave
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> leaveFellowship(String fellowshipId) async {
    try {
      await _datasource.leaveFellowship(fellowshipId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to leave fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship members — mute / unmute
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> muteMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      await _datasource.muteMember(fellowshipId: fellowshipId, userId: userId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mute member: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unmuteMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      await _datasource.unmuteMember(
          fellowshipId: fellowshipId, userId: userId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to unmute member: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      await _datasource.removeMember(
          fellowshipId: fellowshipId, userId: userId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to remove member: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Map<String, dynamic>>> createInvite(
      String fellowshipId) async {
    try {
      final result = await _datasource.createInvite(fellowshipId);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create invite: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — get
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Map<String, dynamic>>> getFellowship(
      String fellowshipId) async {
    try {
      final result = await _datasource.getFellowship(fellowshipId);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — update
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> updateFellowship({
    required String fellowshipId,
    String? name,
    String? description,
    int? maxMembers,
  }) async {
    try {
      await _datasource.updateFellowship(
        fellowshipId: fellowshipId,
        name: name,
        description: description,
        maxMembers: maxMembers,
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — list
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> listInvites(
      String fellowshipId) async {
    try {
      final result = await _datasource.listInvites(fellowshipId);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to list invites: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — revoke
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> revokeInvite({
    required String fellowshipId,
    required String inviteId,
  }) async {
    try {
      await _datasource.revokeInvite(
          fellowshipId: fellowshipId, inviteId: inviteId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to revoke invite: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — transfer mentor
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> transferMentor({
    required String fellowshipId,
    required String newMentorUserId,
  }) async {
    try {
      await _datasource.transferMentor(
          fellowshipId: fellowshipId, newMentorUserId: newMentorUserId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to transfer mentor: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship reports — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> reportContent({
    required String fellowshipId,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    try {
      await _datasource.reportContent(
        fellowshipId: fellowshipId,
        contentType: contentType,
        contentId: contentId,
        reason: reason,
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to submit report: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getTopicPostCounts(
      String fellowshipId) async {
    try {
      final counts = await _datasource.getTopicPostCounts(fellowshipId);
      return Right(counts);
    } catch (e) {
      return Right(const {}); // non-critical — degrade gracefully
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — discover public
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, DiscoverPage>> discoverFellowships({
    String? language,
    String? search,
    String? cursor,
    int limit = 10,
  }) async {
    try {
      final result = await _datasource.discoverFellowships(
        language: language,
        search: search,
        cursor: cursor,
        limit: limit,
      );
      return Right(DiscoverPage(
        fellowships: result.fellowships.map((m) => m.toEntity()).toList(),
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to discover fellowships: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — join public
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, String>> joinPublicFellowship(
      String fellowshipId) async {
    try {
      final name = await _datasource.joinPublicFellowship(fellowshipId);
      return Right(name);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to join public fellowship: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — list
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<FellowshipMeetingEntity>>> getMeetings(
      String fellowshipId) async {
    try {
      final models = await _datasource.getMeetings(fellowshipId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch meetings: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — create
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, FellowshipMeetingEntity>> createMeeting({
    required String fellowshipId,
    required String title,
    String? description,
    required String startsAt,
    required int durationMinutes,
    required String timeZone,
    String? recurrence,
    String? location,
    String? googleAccessToken,
    String? googleRefreshToken,
  }) async {
    try {
      final model = await _datasource.createMeeting(
        fellowshipId: fellowshipId,
        title: title,
        description: description,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        timeZone: timeZone,
        recurrence: recurrence,
        location: location,
        googleAccessToken: googleAccessToken,
        googleRefreshToken: googleRefreshToken,
      );
      return Right(model.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create meeting: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — cancel
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> cancelMeeting(
    String meetingId, {
    String? googleAccessToken,
  }) async {
    try {
      await _datasource.cancelMeeting(
        meetingId,
        googleAccessToken: googleAccessToken,
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to cancel meeting: $e'));
    }
  }

  @override
  Future<Either<Failure, SyncCalendarResult>> syncFellowshipCalendar(
      String fellowshipId) async {
    try {
      final result = await _datasource.syncFellowshipCalendar(fellowshipId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Calendar sync failed: $e'));
    }
  }
}
