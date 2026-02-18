import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/api_error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/memory_verse_model.dart';
import '../models/review_statistics_model.dart';
import '../models/suggested_verse_model.dart';

/// Remote data source for memory verse API operations.
///
/// Handles all HTTP requests to Supabase Edge Functions for memory verses.
class MemoryVerseRemoteDataSource {
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _addFromDailyEndpoint =
      '/functions/v1/add-memory-verse-from-daily';
  static const String _addManualEndpoint =
      '/functions/v1/add-memory-verse-manual';
  static const String _getDueVersesEndpoint =
      '/functions/v1/get-due-memory-verses';
  static const String _submitReviewEndpoint =
      '/functions/v1/submit-memory-verse-review';
  static const String _fetchVerseEndpoint = '/functions/v1/fetch-verse';

  // Gamification endpoints
  static const String _submitPracticeEndpoint =
      '/functions/v1/submit-memory-practice';
  static const String _getPracticeStatsEndpoint =
      '/functions/v1/get-memory-practice-stats';
  static const String _getStreakEndpoint = '/functions/v1/get-memory-streak';
  static const String _useStreakFreezeEndpoint =
      '/functions/v1/use-streak-freeze';
  static const String _checkStreakMilestoneEndpoint =
      '/functions/v1/check-streak-milestone';
  static const String _getMasteryProgressEndpoint =
      '/functions/v1/get-mastery-progress';
  static const String _updateMasteryLevelEndpoint =
      '/functions/v1/update-mastery-level';
  static const String _getDailyGoalEndpoint = '/functions/v1/get-daily-goal';
  static const String _updateDailyGoalProgressEndpoint =
      '/functions/v1/update-daily-goal-progress';
  static const String _setDailyGoalTargetsEndpoint =
      '/functions/v1/set-daily-goal-targets';
  static const String _getActiveChallengesEndpoint =
      '/functions/v1/get-active-challenges';
  static const String _claimChallengeRewardEndpoint =
      '/functions/v1/claim-challenge-reward';

  // Leaderboard and Statistics endpoints
  static const String _getMemoryChampionsEndpoint =
      '/functions/v1/get-memory-champions-leaderboard';
  static const String _getMemoryStatisticsEndpoint =
      '/functions/v1/get-memory-statistics';

  // Suggested Verses endpoint
  static const String _getSuggestedVersesEndpoint =
      '/functions/v1/get-suggested-verses';

  final HttpService _httpService;
  final ApiErrorHandler _errorHandler;

  MemoryVerseRemoteDataSource({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance,
        _errorHandler = const ApiErrorHandler(feature: 'MEMORY_VERSES');

  /// Adds a verse from Daily Verse to memory deck
  ///
  /// [dailyVerseId] - UUID of the Daily Verse to add
  /// [language] - Optional language code ('en', 'hi', 'ml') - if not provided, auto-detects
  Future<MemoryVerseModel> addVerseFromDaily(
    String dailyVerseId, {
    String? language,
  }) async {
    try {
      _errorHandler.logDebug(
          'Adding verse from daily: $dailyVerseId (language: ${language ?? 'auto'})');

      final url = '$_baseUrl$_addFromDailyEndpoint';
      final body = jsonEncode({
        'daily_verse_id': dailyVerseId,
        if (language != null) 'language': language,
      });

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final verseData = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Verse added successfully');

        return MemoryVerseModel.fromJson(verseData);
      } else if (response.statusCode == 409) {
        throw const ServerException(
          message: 'This verse is already in your memory deck',
          code: 'VERSE_ALREADY_EXISTS',
        );
      } else if (response.statusCode == 403) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorCode = jsonData['error']?['code'] as String? ?? 'FORBIDDEN';
        final errorMessage = jsonData['error']?['message'] as String? ??
            'You have reached your verse limit. Upgrade to add more.';
        throw ServerException(message: errorMessage, code: errorCode);
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Daily verse not found',
          code: 'DAILY_VERSE_NOT_FOUND',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'adding verse from daily');
    }
  }

  /// Adds a custom verse manually to memory deck
  Future<MemoryVerseModel> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  }) async {
    try {
      _errorHandler.logDebug('Adding manual verse: $verseReference');

      final url = '$_baseUrl$_addManualEndpoint';
      final body = jsonEncode({
        'verse_reference': verseReference,
        'verse_text': verseText,
        if (language != null) 'language': language,
      });

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final verseData = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Manual verse added successfully');

        return MemoryVerseModel.fromJson(verseData);
      } else if (response.statusCode == 409) {
        throw const ServerException(
          message: 'This verse is already in your memory deck',
          code: 'VERSE_ALREADY_EXISTS',
        );
      } else if (response.statusCode == 403) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorCode = jsonData['error']?['code'] as String? ?? 'FORBIDDEN';
        final errorMessage = jsonData['error']?['message'] as String? ??
            'You have reached your verse limit. Upgrade to add more.';
        throw ServerException(message: errorMessage, code: errorCode);
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'adding manual verse');
    }
  }

  /// Fetches verses that are due for review
  Future<(List<MemoryVerseModel>, ReviewStatisticsModel)> getDueVerses({
    int limit = 20,
    int offset = 0,
    String? language,
    bool showAll = true,
  }) async {
    try {
      _errorHandler.logDebug(
          'Fetching due verses (limit: $limit, offset: $offset, showAll: $showAll)');

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'show_all': showAll.toString(),
        if (language != null) 'language': language,
      };

      final uri = Uri.parse('$_baseUrl$_getDueVersesEndpoint')
          .replace(queryParameters: queryParams);

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        // Parse verses
        final versesList = data['verses'] as List<dynamic>;
        final verses = versesList
            .map((json) =>
                MemoryVerseModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Parse statistics
        final statsData = data['statistics'] as Map<String, dynamic>;
        final statistics = ReviewStatisticsModel.fromJson(statsData);

        _errorHandler.logSuccess('Fetched ${verses.length} due verses');

        return (verses, statistics);
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching due verses');
    }
  }

  /// Submits a review for a memory verse
  Future<Map<String, dynamic>> submitReview({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  }) async {
    try {
      _errorHandler.logDebug('Submitting review (quality: $qualityRating)');

      final url = '$_baseUrl$_submitReviewEndpoint';
      final body = jsonEncode({
        'memory_verse_id': memoryVerseId,
        'quality_rating': qualityRating,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      });

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Review submitted successfully');

        return data;
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Memory verse not found',
          code: 'VERSE_NOT_FOUND',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'submitting review');
    }
  }

  // TODO: PERFORMANCE OPTIMIZATION REQUIRED
  // This method is INEFFICIENT and should be replaced with a dedicated backend endpoint.
  // Current implementation fetches up to 1000 verses and filters client-side, which:
  // - Wastes bandwidth by transferring unnecessary data
  // - Increases API response time (scales with total verse count)
  // - Consumes excessive memory on the client
  // - May fail to find verses if user has > 1000 memory verses
  //
  // PLANNED FIX: Add a dedicated backend endpoint:
  // GET /functions/v1/get-memory-verse?memory_verse_id={id}
  // This should return a single MemoryVerseModel or 404 if not found.
  //
  // Until the backend endpoint is implemented, this temporary solution remains.
  /// Gets a single verse by ID from remote (TEMPORARY INEFFICIENT IMPLEMENTATION)
  Future<MemoryVerseModel> getVerseById(String id) async {
    try {
      _errorHandler.logDebug(
          'Fetching verse by ID: $id (using inefficient getDueVerses filter)');
      _errorHandler.logWarning(
          'Performance risk: Fetching up to 1000 verses to find one');

      // Fetches all verses (showAll defaults to true), not just due ones
      final (verses, _) = await getDueVerses(
        limit: 1000, // WARNING: Hard limit - fails if user has > 1000 verses
      );

      final verse = verses.firstWhere(
        (v) => v.id == id,
        orElse: () => throw const ServerException(
          message: 'Verse not found on server',
          code: 'VERSE_NOT_FOUND',
        ),
      );

      _errorHandler.logSuccess('Found verse: ${verse.verseReference}');
      return verse;
    } catch (e) {
      _errorHandler.handleException(e, 'fetching verse by ID');
    }
  }

  /// Deletes a memory verse from the server
  Future<void> deleteVerse(String memoryVerseId) async {
    try {
      _errorHandler.logDebug('Deleting verse: $memoryVerseId');

      const deleteEndpoint = '/functions/v1/delete-memory-verse';
      // Include verse ID as query parameter
      final url = '$_baseUrl$deleteEndpoint?memory_verse_id=$memoryVerseId';

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response = await _httpService.delete(url, headers: headers);

      if (response.statusCode >= 400) {
        _errorHandler.handleErrorResponse(response);
      }

      _errorHandler.logSuccess('Verse deleted successfully');
    } catch (e) {
      _errorHandler.handleException(e, 'deleting verse');
    }
  }

  /// Fetches verse text from Bible API
  ///
  /// [book] - Book name (e.g., "John", "Genesis")
  /// [chapter] - Chapter number
  /// [verseStart] - Starting verse number
  /// [verseEnd] - Optional ending verse for ranges
  /// [language] - Language code ('en', 'hi', 'ml')
  ///
  /// Returns map with 'text' and 'localizedReference' keys
  Future<Map<String, String>> fetchVerseText({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    required String language,
  }) async {
    try {
      _errorHandler.logDebug(
          'Fetching verse: $book $chapter:$verseStart${verseEnd != null ? '-$verseEnd' : ''} ($language)');

      final url = '$_baseUrl$_fetchVerseEndpoint';
      final body = jsonEncode({
        'book': book,
        'chapter': chapter,
        'verse_start': verseStart,
        if (verseEnd != null) 'verse_end': verseEnd,
        'language': language,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Verse text fetched successfully');

        return {
          'text': data['text'] as String,
          'localizedReference': data['localizedReference'] as String,
        };
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Verse not found',
          code: 'VERSE_NOT_FOUND',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching verse text');
    }
  }

  // ==================== Gamification API Methods ====================

  /// Submits a practice session for a memory verse
  Future<Map<String, dynamic>> submitPracticeSession({
    required String memoryVerseId,
    required String practiceMode,
    required int qualityRating,
    required int confidenceRating,
    double? accuracyPercentage,
    required int timeSpentSeconds,
    int? hintsUsed,
  }) async {
    try {
      _errorHandler.logDebug(
          'Submitting practice session (mode: $practiceMode, quality: $qualityRating)');

      final url = '$_baseUrl$_submitPracticeEndpoint';
      final body = jsonEncode({
        'memory_verse_id': memoryVerseId,
        'practice_mode': practiceMode,
        'quality_rating': qualityRating,
        'confidence_rating': confidenceRating,
        if (accuracyPercentage != null)
          'accuracy_percentage': accuracyPercentage,
        'time_spent_seconds': timeSpentSeconds,
        if (hintsUsed != null) 'hints_used': hintsUsed,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Practice session submitted successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'submitting practice session');
    }
  }

  /// Gets practice mode statistics for the user
  Future<List<Map<String, dynamic>>> getPracticeModeStatistics() async {
    try {
      _errorHandler.logDebug('Fetching practice mode statistics');

      final url = '$_baseUrl$_getPracticeStatsEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List<dynamic>;

        _errorHandler
            .logSuccess('Fetched practice statistics for ${data.length} modes');
        return data.cast<Map<String, dynamic>>();
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching practice mode statistics');
    }
  }

  /// Gets the user's memory verse streak data
  Future<Map<String, dynamic>> getMemoryStreak() async {
    try {
      _errorHandler.logDebug('Fetching memory streak');

      final url = '$_baseUrl$_getStreakEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Memory streak fetched successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching memory streak');
    }
  }

  /// Uses a streak freeze day to protect the streak
  Future<Map<String, dynamic>> useStreakFreeze({
    required String freezeDate,
  }) async {
    try {
      _errorHandler.logDebug('Using streak freeze for date: $freezeDate');

      final url = '$_baseUrl$_useStreakFreezeEndpoint';
      final body = jsonEncode({'freeze_date': freezeDate});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Streak freeze applied successfully');
        return data;
      } else if (response.statusCode == 400) {
        throw const ServerException(
          message: 'No freeze days available or invalid date',
          code: 'INVALID_FREEZE_REQUEST',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'using streak freeze');
    }
  }

  /// Checks if a streak milestone has been reached
  Future<Map<String, dynamic>> checkStreakMilestone() async {
    try {
      _errorHandler.logDebug('Checking streak milestone');

      final url = '$_baseUrl$_checkStreakMilestoneEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.post(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Streak milestone checked');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'checking streak milestone');
    }
  }

  /// Gets mastery progress for a specific verse
  Future<Map<String, dynamic>> getMasteryProgress({
    required String verseId,
  }) async {
    try {
      _errorHandler.logDebug('Fetching mastery progress for verse: $verseId');

      final queryParams = <String, String>{'verse_id': verseId};
      final uri = Uri.parse('$_baseUrl$_getMasteryProgressEndpoint')
          .replace(queryParameters: queryParams);

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Mastery progress fetched successfully');
        return data;
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Mastery progress not found for verse',
          code: 'MASTERY_NOT_FOUND',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching mastery progress');
    }
  }

  /// Updates the mastery level for a verse
  Future<Map<String, dynamic>> updateMasteryLevel({
    required String verseId,
    required String masteryLevel,
  }) async {
    try {
      _errorHandler.logDebug(
          'Updating mastery level for verse: $verseId to $masteryLevel');

      final url = '$_baseUrl$_updateMasteryLevelEndpoint';
      final body = jsonEncode({
        'verse_id': verseId,
        'mastery_level': masteryLevel,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Mastery level updated successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'updating mastery level');
    }
  }

  /// Gets the user's daily goal and progress
  Future<Map<String, dynamic>> getDailyGoal() async {
    try {
      _errorHandler.logDebug('Fetching daily goal');

      final url = '$_baseUrl$_getDailyGoalEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Daily goal fetched successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching daily goal');
    }
  }

  /// Updates daily goal progress after practice
  Future<Map<String, dynamic>> updateDailyGoalProgress({
    required bool isNewVerse,
  }) async {
    try {
      _errorHandler
          .logDebug('Updating daily goal progress (isNewVerse: $isNewVerse)');

      final url = '$_baseUrl$_updateDailyGoalProgressEndpoint';
      final body = jsonEncode({'is_new_verse': isNewVerse});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Daily goal progress updated');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'updating daily goal progress');
    }
  }

  /// Sets custom daily goal targets
  Future<Map<String, dynamic>> setDailyGoalTargets({
    required int targetReviews,
    required int targetNewVerses,
  }) async {
    try {
      _errorHandler.logDebug(
          'Setting daily goal targets (reviews: $targetReviews, new: $targetNewVerses)');

      final url = '$_baseUrl$_setDailyGoalTargetsEndpoint';
      final body = jsonEncode({
        'target_reviews': targetReviews,
        'target_new_verses': targetNewVerses,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Daily goal targets set successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'setting daily goal targets');
    }
  }

  /// Gets active challenges for the user
  Future<List<Map<String, dynamic>>> getActiveChallenges() async {
    try {
      _errorHandler.logDebug('Fetching active challenges');

      final url = '$_baseUrl$_getActiveChallengesEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List<dynamic>;

        _errorHandler.logSuccess('Fetched ${data.length} active challenges');
        return data.cast<Map<String, dynamic>>();
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching active challenges');
    }
  }

  /// Claims reward for a completed challenge
  Future<Map<String, dynamic>> claimChallengeReward({
    required String challengeId,
  }) async {
    try {
      _errorHandler.logDebug('Claiming challenge reward for: $challengeId');

      final url = '$_baseUrl$_claimChallengeRewardEndpoint';
      final body = jsonEncode({'challenge_id': challengeId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Challenge reward claimed successfully');
        return data;
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Challenge not found or not completed',
          code: 'CHALLENGE_NOT_FOUND',
        );
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'claiming challenge reward');
    }
  }

  // ==========================================================================
  // LEADERBOARD AND STATISTICS METHODS
  // ==========================================================================

  /// Fetches Memory Champions Leaderboard
  ///
  /// Returns tuple of (leaderboard entries, user's stats and rank)
  Future<(List<Map<String, dynamic>>, Map<String, dynamic>)>
      getMemoryChampionsLeaderboard({
    required String period,
    int limit = 100,
  }) async {
    try {
      _errorHandler.logDebug(
          'Fetching Memory Champions leaderboard (period: $period, limit: $limit)');

      final queryParams = <String, String>{
        'period': period,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_getMemoryChampionsEndpoint')
          .replace(queryParameters: queryParams);

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        final leaderboardList = data['leaderboard'] as List<dynamic>;
        final leaderboard = leaderboardList.cast<Map<String, dynamic>>();

        final userStats = data['user_stats'] as Map<String, dynamic>;

        _errorHandler
            .logSuccess('Fetched ${leaderboard.length} leaderboard entries');
        return (leaderboard, userStats);
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching Memory Champions leaderboard');
    }
  }

  /// Fetches comprehensive memory verse statistics
  ///
  /// Includes activity heat map, mastery distribution, practice mode stats, and overall stats
  Future<Map<String, dynamic>> getMemoryStatistics() async {
    try {
      _errorHandler.logDebug('Fetching memory statistics');

      final url = '$_baseUrl$_getMemoryStatisticsEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Memory statistics fetched successfully');
        return data;
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching memory statistics');
    }
  }

  // ==========================================================================
  // SUGGESTED VERSES METHODS
  // ==========================================================================

  /// Fetches suggested/popular Bible verses
  ///
  /// [category] - Optional category filter
  /// [language] - Language code ('en', 'hi', 'ml')
  ///
  /// Returns SuggestedVersesResponseModel with verses, categories, and total count
  Future<SuggestedVersesResponseModel> getSuggestedVerses({
    String? category,
    String language = 'en',
  }) async {
    try {
      _errorHandler.logDebug(
          'Fetching suggested verses (category: ${category ?? 'all'}, language: $language)');

      final queryParams = <String, String>{
        'language': language,
        if (category != null) 'category': category,
      };

      final uri = Uri.parse('$_baseUrl$_getSuggestedVersesEndpoint')
          .replace(queryParameters: queryParams);

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(uri.toString(), headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as Map<String, dynamic>;

        _errorHandler.logSuccess('Fetched ${data['total']} suggested verses');
        return SuggestedVersesResponseModel.fromJson(data);
      } else {
        _errorHandler.handleErrorResponse(response);
      }
    } catch (e) {
      _errorHandler.handleException(e, 'fetching suggested verses');
    }
  }
}
