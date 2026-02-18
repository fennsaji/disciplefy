import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/topic_progress_model.dart';
import '../../../../core/utils/logger.dart';

/// Remote data source for topic progress API operations.
///
/// Provides network-based access to track user progress on study topics,
/// including starting, completing, and fetching in-progress topics.
abstract class TopicProgressRemoteDataSource {
  /// Starts tracking progress on a topic.
  ///
  /// Called when a user opens a topic for study.
  /// Returns the created/updated progress record.
  ///
  /// Throws [ServerException] for API errors.
  /// Throws [NetworkException] for connection failures.
  Future<TopicProgressActionResponse> startTopic(String topicId);

  /// Marks a topic as completed and awards XP.
  ///
  /// Called when a user finishes studying a topic.
  /// XP is only awarded on first completion.
  ///
  /// [topicId] - The topic being completed
  /// [timeSpentSeconds] - Total time spent on this session
  ///
  /// Returns completion response with XP earned info.
  ///
  /// Throws [ServerException] for API errors.
  /// Throws [NetworkException] for connection failures.
  Future<TopicProgressActionResponse> completeTopic(
    String topicId, {
    int timeSpentSeconds = 0,
    String? generationMode,
  });

  /// Updates time spent on a topic without completing it.
  ///
  /// Called periodically during study sessions to track engagement.
  ///
  /// [topicId] - The topic being studied
  /// [timeSpentSeconds] - Additional time to add
  ///
  /// Throws [ServerException] for API errors.
  /// Throws [NetworkException] for connection failures.
  Future<TopicProgressActionResponse> updateTimeSpent(
    String topicId,
    int timeSpentSeconds,
  );

  /// Fetches in-progress topics for the "Continue Learning" section.
  ///
  /// Returns topics the user has started but not completed,
  /// ordered by most recently accessed.
  ///
  /// [language] - Language code for localization (defaults to 'en')
  /// [limit] - Maximum number of topics to return (defaults to 5)
  ///
  /// Throws [ServerException] for API errors.
  /// Throws [NetworkException] for connection failures.
  Future<ContinueLearningResponse> getInProgressTopics({
    String language = 'en',
    int limit = 5,
  });
}

class TopicProgressRemoteDataSourceImpl
    implements TopicProgressRemoteDataSource {
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _progressEndpoint = '/functions/v1/topic-progress';
  static const String _continueEndpoint = '/functions/v1/continue-learning';

  final HttpService _httpService;

  TopicProgressRemoteDataSourceImpl({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  @override
  Future<TopicProgressActionResponse> startTopic(String topicId) async {
    return _executeProgressAction('start', topicId);
  }

  @override
  Future<TopicProgressActionResponse> completeTopic(
    String topicId, {
    int timeSpentSeconds = 0,
    String? generationMode,
  }) async {
    return _executeProgressAction(
      'complete',
      topicId,
      timeSpentSeconds: timeSpentSeconds,
      generationMode: generationMode,
    );
  }

  @override
  Future<TopicProgressActionResponse> updateTimeSpent(
    String topicId,
    int timeSpentSeconds,
  ) async {
    return _executeProgressAction(
      'update_time',
      topicId,
      timeSpentSeconds: timeSpentSeconds,
    );
  }

  Future<TopicProgressActionResponse> _executeProgressAction(
    String action,
    String topicId, {
    int? timeSpentSeconds,
    String? generationMode,
  }) async {
    try {
      _logDebug('Executing progress action: $action for topic: $topicId');

      final headers = await _httpService.createHeaders();
      final body = <String, dynamic>{
        'action': action,
        'topic_id': topicId,
      };

      if (timeSpentSeconds != null) {
        body['time_spent_seconds'] = timeSpentSeconds;
      }

      if (generationMode != null) {
        body['generation_mode'] = generationMode;
      }

      final response = await _httpService.post(
        '$_baseUrl$_progressEndpoint',
        headers: headers,
        body: json.encode(body),
      );

      _logDebug('Progress action response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return TopicProgressActionResponse.fromJson(jsonData);
      } else {
        _logDebug('Progress action error: status=${response.statusCode}');
        throw ServerException(
          message: 'Failed to $action topic: ${response.statusCode}',
          code: 'PROGRESS_ACTION_ERROR',
        );
      }
    } catch (e) {
      _logDebug('Progress action exception: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to $action topic: $e',
        code: 'PROGRESS_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<ContinueLearningResponse> getInProgressTopics({
    String language = 'en',
    int limit = 5,
  }) async {
    try {
      _logDebug(
          'Fetching in-progress topics: language=$language, limit=$limit');

      final headers = await _httpService.createHeaders();
      final uri = Uri.parse('$_baseUrl$_continueEndpoint').replace(
        queryParameters: {
          'language': language,
          'limit': limit.toString(),
        },
      );

      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      _logDebug('In-progress topics response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return ContinueLearningResponse.fromJson(jsonData);
      } else {
        _logDebug('In-progress topics error: status=${response.statusCode}');
        throw ServerException(
          message: 'Failed to fetch in-progress topics: ${response.statusCode}',
          code: 'CONTINUE_LEARNING_ERROR',
        );
      }
    } catch (e) {
      _logDebug('In-progress topics exception: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to fetch in-progress topics: $e',
        code: 'CONTINUE_LEARNING_NETWORK_ERROR',
      );
    }
  }

  void _logDebug(String message) {
    Logger.debug('[TopicProgress] $message');
  }
}
