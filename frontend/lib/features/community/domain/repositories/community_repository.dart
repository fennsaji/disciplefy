import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/fellowship_comment_entity.dart';
import '../entities/fellowship_entity.dart';
import '../entities/fellowship_meeting_entity.dart';
import '../entities/fellowship_member_entity.dart';
import '../entities/sync_calendar_result.dart';
import '../entities/fellowship_post_entity.dart';
import '../entities/public_fellowship_entity.dart';

/// Represents a single page of publicly discoverable fellowships.
///
/// [hasMore] is true when additional pages exist. Pass [nextCursor] as the
/// `cursor` parameter to [CommunityRepository.discoverFellowships] to load
/// the next page.
class DiscoverPage {
  final List<PublicFellowshipEntity> fellowships;
  final bool hasMore;
  final String? nextCursor;

  const DiscoverPage({
    required this.fellowships,
    required this.hasMore,
    this.nextCursor,
  });
}

/// Abstract repository interface for all community/fellowship operations.
///
/// Follows the Clean Architecture pattern: the domain layer owns this contract,
/// and the data layer provides the concrete implementation. Each method returns
/// an [Either] where [Left] is a [Failure] and [Right] is the success value.
abstract class CommunityRepository {
  /// Returns the list of fellowships the current user belongs to.
  Future<Either<Failure, List<FellowshipEntity>>> getFellowships(
      String language);

  /// Returns the member list for the fellowship identified by [fellowshipId].
  Future<Either<Failure, List<FellowshipMemberEntity>>> getFellowshipMembers(
      String fellowshipId);

  /// Returns a paginated list of posts for the fellowship identified by
  /// [fellowshipId].
  ///
  /// Pass [cursor] (an ISO-8601 timestamp or opaque string from the previous
  /// response) to fetch the next page. [limit] defaults to 20.
  Future<Either<Failure, List<FellowshipPostEntity>>> getFellowshipPosts({
    required String fellowshipId,
    String? cursor,
    int limit = 20,
    String? topicId,
  });

  /// Creates a new post in the fellowship identified by [fellowshipId].
  ///
  /// [postType] must be one of: `'general'`, `'prayer'`, `'praise'`, or
  /// `'question'`. Pass [topicId] to attach the post to a specific guide.
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
  });

  /// Soft-deletes the post identified by [postId].
  Future<Either<Failure, void>> deletePost(String postId);

  /// Returns all comments for the post identified by [postId].
  Future<Either<Failure, List<FellowshipCommentEntity>>> getComments(
      String postId);

  /// Adds a comment with [content] to the post identified by [postId].
  Future<Either<Failure, FellowshipCommentEntity>> createComment({
    required String postId,
    required String content,
  });

  /// Soft-deletes the comment identified by [commentId].
  Future<Either<Failure, void>> deleteComment(String commentId);

  /// Toggles the current user's [reactionType] emoji on the post identified by
  /// [postId].
  ///
  /// Returns the updated reaction counts map, e.g. `{'🙏': 3, '❤️': 1}`.
  Future<Either<Failure, Map<String, int>>> toggleReaction({
    required String postId,
    required String reactionType,
  });

  /// Joins a fellowship using the invite [inviteToken].
  Future<Either<Failure, void>> joinFellowship(String inviteToken);

  /// Creates a new fellowship. The caller automatically becomes the mentor.
  Future<Either<Failure, void>> createFellowship({
    required String name,
    String? description,
    int? maxMembers,
    bool isPublic = false,
    String language = 'en',
  });

  /// Sets (or replaces) the active learning path for [fellowshipId].
  ///
  /// Only the fellowship mentor may call this. Returns the learning path title.
  Future<Either<Failure, String>> setFellowshipStudy({
    required String fellowshipId,
    required String learningPathId,
  });

  /// Advances the study to the next guide (mentor only).
  Future<Either<Failure, Map<String, dynamic>>> advanceStudy(
      String fellowshipId);

  /// Leaves the fellowship identified by [fellowshipId].
  Future<Either<Failure, void>> leaveFellowship(String fellowshipId);

  /// Permanently deletes the fellowship (mentor only).
  Future<Either<Failure, void>> deleteFellowship(String fellowshipId);

  /// Mutes [userId] in [fellowshipId] (mentor only).
  Future<Either<Failure, void>> muteMember({
    required String fellowshipId,
    required String userId,
  });

  /// Unmutes [userId] in [fellowshipId] (mentor only).
  Future<Either<Failure, void>> unmuteMember({
    required String fellowshipId,
    required String userId,
  });

  /// Removes (kicks) [userId] from [fellowshipId] (mentor only).
  Future<Either<Failure, void>> removeMember({
    required String fellowshipId,
    required String userId,
  });

  /// Generates a new invite token for [fellowshipId] (mentor only).
  Future<Either<Failure, Map<String, dynamic>>> createInvite(
      String fellowshipId);

  /// Returns full details for the fellowship identified by [fellowshipId].
  Future<Either<Failure, Map<String, dynamic>>> getFellowship(
      String fellowshipId, String language);

  /// Updates fellowship settings (mentor only).
  ///
  /// All fields are optional — only non-null values are sent to the server.
  Future<Either<Failure, void>> updateFellowship({
    required String fellowshipId,
    String? name,
    String? description,
    int? maxMembers,
  });

  /// Lists active, non-expired invite links for [fellowshipId] (mentor only).
  Future<Either<Failure, List<Map<String, dynamic>>>> listInvites(
      String fellowshipId);

  /// Revokes the invite identified by [inviteId] in [fellowshipId] (mentor only).
  Future<Either<Failure, void>> revokeInvite({
    required String fellowshipId,
    required String inviteId,
  });

  /// Transfers the mentor role to [newMentorUserId] (current mentor only).
  Future<Either<Failure, void>> transferMentor({
    required String fellowshipId,
    required String newMentorUserId,
  });

  /// Reports a post or comment.
  ///
  /// [contentType] must be `'post'` or `'comment'`.
  /// [reason] must be 5–500 characters.
  Future<Either<Failure, void>> reportContent({
    required String fellowshipId,
    required String contentType,
    required String contentId,
    required String reason,
  });

  /// Returns a map of `topicId → post count` for guide-specific posts.
  Future<Either<Failure, Map<String, int>>> getTopicPostCounts(
      String fellowshipId);

  /// Discovers public fellowships, optionally filtered by [language] and/or
  /// a case-insensitive text [search] against the fellowship name.
  ///
  /// Returns the first page when [cursor] is null. Pass the previous
  /// [DiscoverPage.nextCursor] to load subsequent pages. [limit] defaults to 10.
  Future<Either<Failure, DiscoverPage>> discoverFellowships({
    String? language,
    String? search,
    String? cursor,
    int limit = 10,
  });

  /// Joins a public fellowship directly (no invite code).
  /// Returns the fellowship name on success — used to show a snackbar.
  Future<Either<Failure, String>> joinPublicFellowship(String fellowshipId);

  // ---------------------------------------------------------------------------
  // Fellowship meetings
  // ---------------------------------------------------------------------------

  /// Returns upcoming meetings for the fellowship identified by [fellowshipId].
  Future<Either<Failure, List<FellowshipMeetingEntity>>> getMeetings(
      String fellowshipId);

  /// Schedules a new meeting and returns the created [FellowshipMeetingEntity].
  ///
  /// [startsAt] must be an ISO-8601 string. [durationMinutes] is added to
  /// [startsAt] by the server to compute `ends_at`. [timeZone] is an IANA
  /// timezone string (e.g. `'America/New_York'`). Pass [recurrence] as
  /// `'daily'`, `'weekly'`, or `'monthly'` for a recurring series.
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
  });

  /// Cancels the meeting identified by [meetingId].
  Future<Either<Failure, void>> cancelMeeting(
    String meetingId, {
    String? googleAccessToken,
  });

  /// Syncs Google Calendar attendees for all upcoming meetings of [fellowshipId].
  ///
  /// Returns [Right(SyncCalendarResult)] on success.
  /// If [SyncCalendarResult.requiresReconnect] is true, prompt the mentor to
  /// re-authenticate with Google Calendar.
  Future<Either<Failure, SyncCalendarResult>> syncFellowshipCalendar(
      String fellowshipId,
      {String? googleAccessToken});
}
