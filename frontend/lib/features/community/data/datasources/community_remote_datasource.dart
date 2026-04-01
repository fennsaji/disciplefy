import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/sync_calendar_result.dart';
import '../models/fellowship_comment_model.dart';
import '../models/fellowship_meeting_model.dart';
import '../models/fellowship_member_model.dart';
import '../models/fellowship_model.dart';
import '../models/fellowship_post_model.dart';
import '../models/public_fellowship_model.dart';

/// Abstract interface for all community/fellowship remote API operations.
///
/// Each method maps to a dedicated Supabase Edge Function. All responses
/// follow the shape `{ success: true, data: { ... } }` and errors are
/// wrapped as [ServerException] with a domain-specific error code.
abstract class CommunityRemoteDatasource {
  /// Returns the list of fellowships the current user belongs to.
  Future<List<FellowshipModel>> getFellowships(String language);

  /// Returns the member list for [fellowshipId].
  Future<List<FellowshipMemberModel>> getFellowshipMembers(String fellowshipId);

  /// Returns a paginated list of posts for [fellowshipId].
  ///
  /// Pass [cursor] (an ISO-8601 timestamp or opaque string from the previous
  /// response) to fetch the next page. [limit] defaults to 20.
  Future<List<FellowshipPostModel>> getFellowshipPosts({
    required String fellowshipId,
    String? cursor,
    int limit = 20,
    String? topicId,
  });

  /// Creates a new post in [fellowshipId] with the given [content] and
  /// [postType] (`'general'`, `'prayer'`, `'praise'`, or `'question'`).
  /// Pass [topicId] to attach the post to a specific guide discussion.
  Future<FellowshipPostModel> createPost({
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
  Future<void> deletePost(String postId);

  /// Returns all comments for [postId].
  Future<List<FellowshipCommentModel>> getComments(String postId);

  /// Adds a comment with [content] to [postId].
  Future<FellowshipCommentModel> createComment({
    required String postId,
    required String content,
  });

  /// Soft-deletes the comment identified by [commentId].
  Future<void> deleteComment(String commentId);

  /// Toggles the current user's [reactionType] emoji on [postId].
  ///
  /// Returns the updated reaction counts map, e.g. `{'🙏': 3, '❤️': 1}`.
  Future<Map<String, int>> toggleReaction({
    required String postId,
    required String reactionType,
  });

  /// Joins a fellowship using the invite [token].
  Future<void> joinFellowship(String inviteToken);

  /// Creates a new fellowship with the given [name], optional [description],
  /// and optional [maxMembers] cap (defaults to 12 on the server).
  ///
  /// The caller automatically becomes the mentor of the new fellowship.
  /// [isPublic] controls visibility in the Discover tab (admin only).
  /// [language] sets the fellowship's primary language (admin only).
  Future<void> createFellowship({
    required String name,
    String? description,
    int? maxMembers,
    bool isPublic = false,
    String language = 'en',
  });

  /// Sets (or replaces) the active learning path for [fellowshipId].
  ///
  /// Only the fellowship mentor may call this. Returns the learning path title
  /// from the server so it can be displayed immediately.
  Future<String> setFellowshipStudy({
    required String fellowshipId,
    required String learningPathId,
  });

  /// Advances the fellowship study to the next guide (mentor only).
  ///
  /// Returns a map with `is_complete` (bool) and `current_guide_index` (int).
  Future<Map<String, dynamic>> advanceStudy(String fellowshipId);

  /// Resets the fellowship study progress back to Guide 1 (mentor only).
  Future<void> resetStudy(String fellowshipId);

  /// Leaves the fellowship. Blocks if the caller is the sole mentor.
  Future<void> leaveFellowship(String fellowshipId);

  /// Permanently deletes the fellowship (mentor only).
  Future<void> deleteFellowship(String fellowshipId);

  /// Mutes a member in the fellowship (mentor only).
  Future<void> muteMember({
    required String fellowshipId,
    required String userId,
  });

  /// Unmutes a muted member in the fellowship (mentor only).
  Future<void> unmuteMember({
    required String fellowshipId,
    required String userId,
  });

  /// Removes (kicks) a member from the fellowship (mentor only).
  Future<void> removeMember({
    required String fellowshipId,
    required String userId,
  });

  /// Generates a new invite token for the fellowship (mentor only).
  ///
  /// Returns a map with `token` and `join_url`.
  Future<Map<String, dynamic>> createInvite(String fellowshipId);

  /// Returns full details for the fellowship identified by [fellowshipId].
  Future<Map<String, dynamic>> getFellowship(
      String fellowshipId, String language);

  /// Updates fellowship settings (mentor only).
  Future<void> updateFellowship({
    required String fellowshipId,
    String? name,
    String? description,
    int? maxMembers,
  });

  /// Lists active invite links for [fellowshipId] (mentor only).
  Future<List<Map<String, dynamic>>> listInvites(String fellowshipId);

  /// Revokes the invite identified by [inviteId] (mentor only).
  Future<void> revokeInvite({
    required String fellowshipId,
    required String inviteId,
  });

  /// Transfers the mentor role to [newMentorUserId] (current mentor only).
  Future<void> transferMentor({
    required String fellowshipId,
    required String newMentorUserId,
  });

  /// Reports a post or comment.
  Future<void> reportContent({
    required String fellowshipId,
    required String contentType,
    required String contentId,
    required String reason,
  });

  /// Returns a map of `topicId → post count` for all guide-specific posts in
  /// [fellowshipId]. Uses the lightweight `count_by_topic=true` endpoint mode.
  Future<Map<String, int>> getTopicPostCounts(String fellowshipId);

  /// Discovers public fellowships, optionally filtered by [language] and/or
  /// a case-insensitive text [search] against the fellowship name.
  ///
  /// Returns a record with the model list, a [hasMore] flag, and an optional
  /// [nextCursor] ISO-8601 timestamp for the next page request.
  Future<
      ({
        List<PublicFellowshipModel> fellowships,
        bool hasMore,
        String? nextCursor
      })> discoverFellowships({
    String? language,
    String? search,
    String? cursor,
    int limit = 10,
  });

  /// Joins a public fellowship directly (no invite code).
  /// Returns the fellowship name on success.
  Future<String> joinPublicFellowship(String fellowshipId);

  // ---------------------------------------------------------------------------
  // Fellowship meetings
  // ---------------------------------------------------------------------------

  /// Returns the list of upcoming meetings for [fellowshipId].
  Future<List<FellowshipMeetingModel>> getMeetings(String fellowshipId);

  /// Schedules a new meeting. Returns the created [FellowshipMeetingModel].
  Future<FellowshipMeetingModel> createMeeting({
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
  Future<void> cancelMeeting(String meetingId, {String? googleAccessToken});

  /// Syncs Google Calendar attendees for all upcoming meetings of [fellowshipId].
  Future<SyncCalendarResult> syncFellowshipCalendar(String fellowshipId,
      {String? googleAccessToken});
}

/// [HttpService]-backed implementation of [CommunityRemoteDatasource].
///
/// All requests are authenticated via [HttpService.createHeaders], which
/// injects the `Authorization: Bearer <token>` header. Responses are parsed
/// from the shared `{ success, data }` envelope used by all Edge Functions.
class CommunityRemoteDatasourceImpl implements CommunityRemoteDatasource {
  // ---------------------------------------------------------------------------
  // Endpoints — all relative to AppConfig.supabaseUrl
  // ---------------------------------------------------------------------------
  static String get _baseUrl => AppConfig.supabaseUrl;

  // Merged: fellowship (list, get, create, update, discover, join, leave)
  static const String _fellowshipListEndpoint = '/functions/v1/fellowship';
  static const String _fellowshipGetEndpoint = '/functions/v1/fellowship';
  static const String _fellowshipCreateEndpoint = '/functions/v1/fellowship';
  static const String _fellowshipUpdateEndpoint = '/functions/v1/fellowship';
  static const String _fellowshipDiscoverEndpoint =
      '/functions/v1/fellowship/discover';
  static const String _fellowshipJoinPublicEndpoint =
      '/functions/v1/fellowship/join';
  static const String _fellowshipLeaveEndpoint =
      '/functions/v1/fellowship/leave';

  // Merged: fellowship-study (set, advance)
  static const String _fellowshipStudySetEndpoint =
      '/functions/v1/fellowship-study/set';
  static const String _fellowshipStudyAdvanceEndpoint =
      '/functions/v1/fellowship-study/advance';
  static const String _fellowshipStudyResetEndpoint =
      '/functions/v1/fellowship-study/reset';

  // Merged: fellowship-members (list, mute, unmute, remove, transfer)
  static const String _fellowshipMembersListEndpoint =
      '/functions/v1/fellowship-members';
  static const String _fellowshipMembersmuteEndpoint =
      '/functions/v1/fellowship-members/mute';
  static const String _fellowshipMembersUnmuteEndpoint =
      '/functions/v1/fellowship-members/unmute';
  static const String _fellowshipMembersRemoveEndpoint =
      '/functions/v1/fellowship-members/remove';
  static const String _fellowshipTransferMentorEndpoint =
      '/functions/v1/fellowship-members/transfer';

  // Merged: fellowship-posts (list, create, delete)
  static const String _fellowshipPostsListEndpoint =
      '/functions/v1/fellowship-posts';
  static const String _fellowshipPostsCreateEndpoint =
      '/functions/v1/fellowship-posts';
  static const String _fellowshipPostsDeleteEndpoint =
      '/functions/v1/fellowship-posts';

  // Merged: fellowship-comments (list, create, delete)
  static const String _fellowshipCommentsListEndpoint =
      '/functions/v1/fellowship-comments';
  static const String _fellowshipCommentsCreateEndpoint =
      '/functions/v1/fellowship-comments';
  static const String _fellowshipCommentsDeleteEndpoint =
      '/functions/v1/fellowship-comments';

  // Merged: fellowship-invites (list, create, join, revoke)
  static const String _fellowshipInvitesJoinEndpoint =
      '/functions/v1/fellowship-invites/join';
  static const String _fellowshipInvitesCreateEndpoint =
      '/functions/v1/fellowship-invites';
  static const String _fellowshipInvitesListEndpoint =
      '/functions/v1/fellowship-invites';
  static const String _fellowshipInvitesRevokeEndpoint =
      '/functions/v1/fellowship-invites/revoke';

  // Merged: fellowship-meetings (list, create, cancel)
  static const String _fellowshipMeetingsListEndpoint =
      '/functions/v1/fellowship-meetings';
  static const String _fellowshipMeetingsCreateEndpoint =
      '/functions/v1/fellowship-meetings';
  static const String _fellowshipMeetingsCancelEndpoint =
      '/functions/v1/fellowship-meetings/cancel';
  static const String _fellowshipMeetingsSyncCalendarEndpoint =
      '/functions/v1/fellowship-meetings/sync-calendar';

  // Merged into fellowship-posts: reactions toggle, reports create
  static const String _fellowshipReactionsToggleEndpoint =
      '/functions/v1/fellowship-posts/react';
  static const String _fellowshipReportsCreateEndpoint =
      '/functions/v1/fellowship-posts/report';

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final HttpService _httpService;

  CommunityRemoteDatasourceImpl({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parses a raw JSON response body into a [Map] and validates the success
  /// flag. Throws [ServerException] when the server reports a failure.
  Map<String, dynamic> _parseResponseBody(
    String body,
    String errorCode,
    String errorMessage,
  ) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true) {
      throw ServerException(
        message: (json['error'] as String?) ?? errorMessage,
        code: errorCode,
      );
    }
    return json['data'] as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Fellowship list
  // ---------------------------------------------------------------------------

  @override
  Future<List<FellowshipModel>> getFellowships(String language) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipListEndpoint')
          .replace(queryParameters: {'language': language});
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch fellowships: ${response.statusCode}',
          code: 'FELLOWSHIP_LIST_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_LIST_ERROR',
        'Failed to fetch fellowships',
      );

      final list = data['fellowships'] as List<dynamic>;
      return list
          .map((json) => FellowshipModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch fellowships: $e',
        code: 'FELLOWSHIP_LIST_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship members
  // ---------------------------------------------------------------------------

  @override
  Future<List<FellowshipMemberModel>> getFellowshipMembers(
      String fellowshipId) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipMembersListEndpoint')
          .replace(queryParameters: {'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch fellowship members: ${response.statusCode}',
          code: 'FELLOWSHIP_MEMBERS_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_MEMBERS_ERROR',
        'Failed to fetch fellowship members',
      );

      final list = data['members'] as List<dynamic>;
      return list
          .map((json) =>
              FellowshipMemberModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch fellowship members: $e',
        code: 'FELLOWSHIP_MEMBERS_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — list (paginated)
  // ---------------------------------------------------------------------------

  @override
  Future<List<FellowshipPostModel>> getFellowshipPosts({
    required String fellowshipId,
    String? cursor,
    int limit = 20,
    String? topicId,
  }) async {
    try {
      final queryParams = <String, String>{
        'fellowship_id': fellowshipId,
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor,
        if (topicId != null) 'topic_id': topicId,
      };

      final uri = Uri.parse('$_baseUrl$_fellowshipPostsListEndpoint')
          .replace(queryParameters: queryParams);

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch fellowship posts: ${response.statusCode}',
          code: 'FELLOWSHIP_POSTS_LIST_ERROR',
        );
      }

      // Backend returns { success, data: [...], pagination: {...} }
      // where data is a direct array — not wrapped in { posts: [...] }.
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to fetch posts',
          code: 'FELLOWSHIP_POSTS_LIST_ERROR',
        );
      }
      final list = json['data'] as List<dynamic>;
      return list
          .map((item) =>
              FellowshipPostModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch fellowship posts: $e',
        code: 'FELLOWSHIP_POSTS_LIST_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — topic counts
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, int>> getTopicPostCounts(String fellowshipId) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipPostsListEndpoint').replace(
        queryParameters: {
          'fellowship_id': fellowshipId,
          'count_by_topic': 'true',
        },
      );
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);
      if (response.statusCode != 200) {
        return {};
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) return {};
      final data = json['data'] as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — create
  // ---------------------------------------------------------------------------

  @override
  Future<FellowshipPostModel> createPost({
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
      final url = '$_baseUrl$_fellowshipPostsCreateEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'content': content,
        'post_type': postType,
        if (topicId != null) 'topic_id': topicId,
        if (topicTitle != null) 'topic_title': topicTitle,
        if (guideTitle != null) 'guide_title': guideTitle,
        if (lessonIndex != null) 'lesson_index': lessonIndex,
        if (studyGuideId != null) 'study_guide_id': studyGuideId,
        if (guideInputType != null) 'guide_input_type': guideInputType,
        if (guideLanguage != null) 'guide_language': guideLanguage,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to create post: ${response.statusCode}',
          code: 'FELLOWSHIP_POST_CREATE_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_POST_CREATE_ERROR',
        'Failed to create post',
      );

      return FellowshipPostModel.fromJson(data);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create post: $e',
        code: 'FELLOWSHIP_POST_CREATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship posts — delete
  // ---------------------------------------------------------------------------

  @override
  Future<void> deletePost(String postId) async {
    try {
      final url = '$_baseUrl$_fellowshipPostsDeleteEndpoint';
      final body = jsonEncode({'post_id': postId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.delete(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        throw ServerException(
          message: 'Failed to delete post: ${response.statusCode}',
          code: 'FELLOWSHIP_POST_DELETE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to delete post: $e',
        code: 'FELLOWSHIP_POST_DELETE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — list
  // ---------------------------------------------------------------------------

  @override
  Future<List<FellowshipCommentModel>> getComments(String postId) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipCommentsListEndpoint')
          .replace(queryParameters: {'post_id': postId});

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch comments: ${response.statusCode}',
          code: 'FELLOWSHIP_COMMENTS_LIST_ERROR',
        );
      }

      // Backend returns { success, data: [...] } where data is a direct array.
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to fetch comments',
          code: 'FELLOWSHIP_COMMENTS_LIST_ERROR',
        );
      }
      final list = json['data'] as List<dynamic>;
      return list
          .map((item) =>
              FellowshipCommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch comments: $e',
        code: 'FELLOWSHIP_COMMENTS_LIST_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — create
  // ---------------------------------------------------------------------------

  @override
  Future<FellowshipCommentModel> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipCommentsCreateEndpoint';
      final body = jsonEncode({
        'post_id': postId,
        'content': content,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to create comment: ${response.statusCode}',
          code: 'FELLOWSHIP_COMMENT_CREATE_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_COMMENT_CREATE_ERROR',
        'Failed to create comment',
      );

      return FellowshipCommentModel.fromJson(data);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create comment: $e',
        code: 'FELLOWSHIP_COMMENT_CREATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship comments — delete
  // ---------------------------------------------------------------------------

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      final url = '$_baseUrl$_fellowshipCommentsDeleteEndpoint';
      final body = jsonEncode({'comment_id': commentId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.delete(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        throw ServerException(
          message: 'Failed to delete comment: ${response.statusCode}',
          code: 'FELLOWSHIP_COMMENT_DELETE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to delete comment: $e',
        code: 'FELLOWSHIP_COMMENT_DELETE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reactions — toggle
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, int>> toggleReaction({
    required String postId,
    required String reactionType,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipReactionsToggleEndpoint';
      final body = jsonEncode({
        'post_id': postId,
        'reaction_type': reactionType,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to toggle reaction: ${response.statusCode}',
          code: 'FELLOWSHIP_REACTION_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_REACTION_ERROR',
        'Failed to toggle reaction',
      );

      final rawCounts = data['reaction_counts'] as Map<String, dynamic>? ?? {};
      return rawCounts
          .map((key, value) => MapEntry(key, (value as num).toInt()));
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to toggle reaction: $e',
        code: 'FELLOWSHIP_REACTION_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Invite — join fellowship
  // ---------------------------------------------------------------------------

  @override
  Future<void> joinFellowship(String inviteToken) async {
    try {
      final url = '$_baseUrl$_fellowshipInvitesJoinEndpoint';
      final body = jsonEncode({'token': inviteToken});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        String errorMessage =
            'Failed to join fellowship: ${response.statusCode}';
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'];
          if (error is Map<String, dynamic>) {
            errorMessage = (error['message'] as String?) ?? errorMessage;
          } else if (error is String) {
            errorMessage = error;
          }
        } catch (_) {}
        throw ServerException(
          message: errorMessage,
          code: 'FELLOWSHIP_JOIN_ERROR',
        );
      }

      // Validate success flag; ignore data payload (void return).
      _parseResponseBody(
        response.body,
        'FELLOWSHIP_JOIN_ERROR',
        'Failed to join fellowship',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to join fellowship: $e',
        code: 'FELLOWSHIP_JOIN_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — create
  // ---------------------------------------------------------------------------

  @override
  Future<void> createFellowship({
    required String name,
    String? description,
    int? maxMembers,
    bool isPublic = false,
    String language = 'en',
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipCreateEndpoint';
      final bodyMap = <String, dynamic>{'name': name};
      if (description != null && description.isNotEmpty) {
        bodyMap['description'] = description;
      }
      if (maxMembers != null) {
        bodyMap['max_members'] = maxMembers;
      }
      bodyMap['is_public'] = isPublic;
      bodyMap['language'] = language;
      final body = jsonEncode(bodyMap);

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to create fellowship: ${response.statusCode}',
          code: 'FELLOWSHIP_CREATE_ERROR',
        );
      }

      _parseResponseBody(
        response.body,
        'FELLOWSHIP_CREATE_ERROR',
        'Failed to create fellowship',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create fellowship: $e',
        code: 'FELLOWSHIP_CREATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship study — set
  // ---------------------------------------------------------------------------

  @override
  Future<String> setFellowshipStudy({
    required String fellowshipId,
    required String learningPathId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipStudySetEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'learning_path_id': learningPathId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to set fellowship study: ${response.statusCode}',
          code: 'FELLOWSHIP_STUDY_SET_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_STUDY_SET_ERROR',
        'Failed to set fellowship study',
      );

      return (data['learning_path_title'] as String?) ?? '';
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to set fellowship study: $e',
        code: 'FELLOWSHIP_STUDY_SET_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship study — advance
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> advanceStudy(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipStudyAdvanceEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to advance study: ${response.statusCode}',
          code: 'FELLOWSHIP_STUDY_ADVANCE_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_STUDY_ADVANCE_ERROR',
        'Failed to advance study',
      );

      return data;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to advance study: $e',
        code: 'FELLOWSHIP_STUDY_ADVANCE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship study — reset
  // ---------------------------------------------------------------------------

  @override
  Future<void> resetStudy(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipStudyResetEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to reset study: ${response.statusCode}',
          code: 'FELLOWSHIP_STUDY_RESET_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to reset study: $e',
        code: 'FELLOWSHIP_STUDY_RESET_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — leave
  // ---------------------------------------------------------------------------

  @override
  Future<void> deleteFellowship(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipUpdateEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});
      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.delete(url, headers: headers, body: body);
      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to delete fellowship',
          code: 'FELLOWSHIP_DELETE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to delete fellowship: $e',
        code: 'FELLOWSHIP_DELETE_ERROR',
      );
    }
  }

  @override
  Future<void> leaveFellowship(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipLeaveEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to leave fellowship',
          code: 'FELLOWSHIP_LEAVE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to leave fellowship: $e',
        code: 'FELLOWSHIP_LEAVE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship members — mute / unmute
  // ---------------------------------------------------------------------------

  @override
  Future<void> muteMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipMembersmuteEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'user_id': userId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to mute member',
          code: 'FELLOWSHIP_MUTE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to mute member: $e',
        code: 'FELLOWSHIP_MUTE_ERROR',
      );
    }
  }

  @override
  Future<void> unmuteMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipMembersUnmuteEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'user_id': userId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to unmute member',
          code: 'FELLOWSHIP_UNMUTE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to unmute member: $e',
        code: 'FELLOWSHIP_UNMUTE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship members — remove
  // ---------------------------------------------------------------------------

  @override
  Future<void> removeMember({
    required String fellowshipId,
    required String userId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipMembersRemoveEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'user_id': userId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to remove member',
          code: 'FELLOWSHIP_REMOVE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to remove member: $e',
        code: 'FELLOWSHIP_REMOVE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — create
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> createInvite(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipInvitesCreateEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to create invite',
          code: 'FELLOWSHIP_INVITE_CREATE_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_INVITE_CREATE_ERROR',
        'Failed to create invite',
      );

      return data;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create invite: $e',
        code: 'FELLOWSHIP_INVITE_CREATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — get
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> getFellowship(
      String fellowshipId, String language) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipGetEndpoint').replace(
          queryParameters: {
            'fellowship_id': fellowshipId,
            'language': language
          });

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch fellowship: ${response.statusCode}',
          code: 'FELLOWSHIP_GET_ERROR',
        );
      }

      return _parseResponseBody(
        response.body,
        'FELLOWSHIP_GET_ERROR',
        'Failed to fetch fellowship',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch fellowship: $e',
        code: 'FELLOWSHIP_GET_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — update
  // ---------------------------------------------------------------------------

  @override
  Future<void> updateFellowship({
    required String fellowshipId,
    String? name,
    String? description,
    int? maxMembers,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipUpdateEndpoint';
      final bodyMap = <String, dynamic>{'fellowship_id': fellowshipId};
      if (name != null) bodyMap['name'] = name;
      if (description != null) bodyMap['description'] = description;
      if (maxMembers != null) bodyMap['max_members'] = maxMembers;
      final body = jsonEncode(bodyMap);

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.patch(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to update fellowship',
          code: 'FELLOWSHIP_UPDATE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to update fellowship: $e',
        code: 'FELLOWSHIP_UPDATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — list
  // ---------------------------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> listInvites(String fellowshipId) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipInvitesListEndpoint')
          .replace(queryParameters: {'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to list invites: ${response.statusCode}',
          code: 'FELLOWSHIP_INVITES_LIST_ERROR',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to list invites',
          code: 'FELLOWSHIP_INVITES_LIST_ERROR',
        );
      }

      final list = json['data'] as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to list invites: $e',
        code: 'FELLOWSHIP_INVITES_LIST_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship invites — revoke
  // ---------------------------------------------------------------------------

  @override
  Future<void> revokeInvite({
    required String fellowshipId,
    required String inviteId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipInvitesRevokeEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'invite_id': inviteId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to revoke invite',
          code: 'FELLOWSHIP_INVITE_REVOKE_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to revoke invite: $e',
        code: 'FELLOWSHIP_INVITE_REVOKE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — transfer mentor
  // ---------------------------------------------------------------------------

  @override
  Future<void> transferMentor({
    required String fellowshipId,
    required String newMentorUserId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipTransferMentorEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'new_mentor_user_id': newMentorUserId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to transfer mentor',
          code: 'FELLOWSHIP_TRANSFER_MENTOR_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to transfer mentor: $e',
        code: 'FELLOWSHIP_TRANSFER_MENTOR_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship reports — create
  // ---------------------------------------------------------------------------

  @override
  Future<void> reportContent({
    required String fellowshipId,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipReportsCreateEndpoint';
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to submit report',
          code: 'FELLOWSHIP_REPORT_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to submit report: $e',
        code: 'FELLOWSHIP_REPORT_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — discover public
  // ---------------------------------------------------------------------------

  @override
  Future<
      ({
        List<PublicFellowshipModel> fellowships,
        bool hasMore,
        String? nextCursor
      })> discoverFellowships({
    String? language,
    String? search,
    String? cursor,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (language != null) 'language': language,
        if (search != null && search.isNotEmpty) 'search': search,
        if (cursor != null) 'cursor': cursor,
      };

      final uri = Uri.parse('$_baseUrl$_fellowshipDiscoverEndpoint')
          .replace(queryParameters: queryParams);

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to discover fellowships: ${response.statusCode}',
          code: 'FELLOWSHIP_DISCOVER_ERROR',
        );
      }

      // Parse the full response — pagination lives at the top level, not inside data.
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message:
              (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
                  'Failed to discover fellowships',
          code: 'FELLOWSHIP_DISCOVER_ERROR',
        );
      }

      final data = json['data'] as Map<String, dynamic>;
      final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

      final list = data['fellowships'] as List<dynamic>;
      final models = list
          .map((j) => PublicFellowshipModel.fromJson(j as Map<String, dynamic>))
          .toList();

      return (
        fellowships: models,
        hasMore: pagination['has_more'] as bool? ?? false,
        nextCursor: pagination['next_cursor'] as String?,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to discover fellowships: $e',
        code: 'FELLOWSHIP_DISCOVER_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship — join public
  // ---------------------------------------------------------------------------

  @override
  Future<String> joinPublicFellowship(String fellowshipId) async {
    try {
      final url = '$_baseUrl$_fellowshipJoinPublicEndpoint';
      final body = jsonEncode({'fellowship_id': fellowshipId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to join public fellowship: ${response.statusCode}',
          code: 'FELLOWSHIP_JOIN_PUBLIC_ERROR',
        );
      }

      final data = _parseResponseBody(
        response.body,
        'FELLOWSHIP_JOIN_PUBLIC_ERROR',
        'Failed to join public fellowship',
      );

      return (data['fellowship_name'] as String?) ?? '';
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to join public fellowship: $e',
        code: 'FELLOWSHIP_JOIN_PUBLIC_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — list
  // ---------------------------------------------------------------------------

  @override
  Future<List<FellowshipMeetingModel>> getMeetings(String fellowshipId) async {
    try {
      final uri = Uri.parse('$_baseUrl$_fellowshipMeetingsListEndpoint')
          .replace(queryParameters: {'fellowship_id': fellowshipId});
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to fetch meetings: ${response.statusCode}',
          code: 'FELLOWSHIP_MEETINGS_LIST_ERROR',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message: (json['error'] as Map?)?['message'] as String? ??
              'Failed to fetch meetings',
          code: 'FELLOWSHIP_MEETINGS_LIST_ERROR',
        );
      }

      final data = json['data'] as List<dynamic>;
      return data
          .map(
              (e) => FellowshipMeetingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch meetings: $e',
        code: 'FELLOWSHIP_MEETINGS_LIST_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — create
  // ---------------------------------------------------------------------------

  @override
  Future<FellowshipMeetingModel> createMeeting({
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
      final url = '$_baseUrl$_fellowshipMeetingsCreateEndpoint';
      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'fellowship_id': fellowshipId,
        'title': title,
        if (description != null) 'description': description,
        'starts_at': startsAt,
        'duration_minutes': durationMinutes,
        'time_zone': timeZone,
        if (recurrence != null) 'recurrence': recurrence,
        if (location != null) 'location': location,
        if (googleAccessToken != null) 'google_access_token': googleAccessToken,
        if (googleRefreshToken != null)
          'google_refresh_token': googleRefreshToken,
      });

      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 201) {
        throw ServerException(
          message: 'Failed to create meeting: ${response.statusCode}',
          code: 'FELLOWSHIP_MEETINGS_CREATE_ERROR',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ServerException(
          message: (json['error'] as Map?)?['message'] as String? ??
              'Failed to create meeting',
          code: 'FELLOWSHIP_MEETINGS_CREATE_ERROR',
        );
      }

      return FellowshipMeetingModel.fromJson(
          json['data'] as Map<String, dynamic>);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create meeting: $e',
        code: 'FELLOWSHIP_MEETINGS_CREATE_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — cancel
  // ---------------------------------------------------------------------------

  @override
  Future<void> cancelMeeting(String meetingId,
      {String? googleAccessToken}) async {
    try {
      final url = '$_baseUrl$_fellowshipMeetingsCancelEndpoint';
      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'meeting_id': meetingId,
        if (googleAccessToken != null) 'google_access_token': googleAccessToken,
      });

      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to cancel meeting: ${response.statusCode}',
          code: 'FELLOWSHIP_MEETINGS_CANCEL_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to cancel meeting: $e',
        code: 'FELLOWSHIP_MEETINGS_CANCEL_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Fellowship meetings — sync calendar
  // ---------------------------------------------------------------------------

  @override
  Future<SyncCalendarResult> syncFellowshipCalendar(String fellowshipId,
      {String? googleAccessToken}) async {
    try {
      final url = '$_baseUrl$_fellowshipMeetingsSyncCalendarEndpoint';
      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'fellowshipId': fellowshipId,
        if (googleAccessToken != null) 'googleAccessToken': googleAccessToken,
      });
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to sync calendar: ${response.statusCode}',
          code: 'CALENDAR_SYNC_ERROR',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SyncCalendarResult.fromJson(json);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to sync calendar: $e',
        code: 'CALENDAR_SYNC_ERROR',
      );
    }
  }
}
