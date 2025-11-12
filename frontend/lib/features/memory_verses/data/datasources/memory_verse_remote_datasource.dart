import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/memory_verse_model.dart';
import '../models/review_statistics_model.dart';

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

  final HttpService _httpService;

  MemoryVerseRemoteDataSource({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Adds a verse from Daily Verse to memory deck
  Future<MemoryVerseModel> addVerseFromDaily(String dailyVerseId) async {
    try {
      if (kDebugMode) {
        print('🚀 [MEMORY_VERSES] Adding verse from daily: $dailyVerseId');
      }

      final url = '$_baseUrl$_addFromDailyEndpoint';
      final body = jsonEncode({'daily_verse_id': dailyVerseId});

      // Create headers with authentication
      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final verseData = jsonData['data'] as Map<String, dynamic>;

        if (kDebugMode) {
          print('✅ [MEMORY_VERSES] Verse added successfully');
        }

        return MemoryVerseModel.fromJson(verseData);
      } else if (response.statusCode == 409) {
        throw const ServerException(
          message: 'This verse is already in your memory deck',
          code: 'VERSE_ALREADY_EXISTS',
        );
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Daily verse not found',
          code: 'DAILY_VERSE_NOT_FOUND',
        );
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      _handleException(e, 'adding verse from daily');
    }
  }

  /// Adds a custom verse manually to memory deck
  Future<MemoryVerseModel> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 [MEMORY_VERSES] Adding manual verse: $verseReference');
      }

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

        if (kDebugMode) {
          print('✅ [MEMORY_VERSES] Manual verse added successfully');
        }

        return MemoryVerseModel.fromJson(verseData);
      } else if (response.statusCode == 409) {
        throw const ServerException(
          message: 'This verse is already in your memory deck',
          code: 'VERSE_ALREADY_EXISTS',
        );
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      _handleException(e, 'adding manual verse');
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
      if (kDebugMode) {
        print(
            '🚀 [MEMORY_VERSES] Fetching due verses (limit: $limit, offset: $offset, showAll: $showAll)');
      }

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

        if (kDebugMode) {
          print('✅ [MEMORY_VERSES] Fetched ${verses.length} due verses');
        }

        return (verses, statistics);
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      _handleException(e, 'fetching due verses');
    }
  }

  /// Submits a review for a memory verse
  Future<Map<String, dynamic>> submitReview({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 [MEMORY_VERSES] Submitting review (quality: $qualityRating)');
      }

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

        if (kDebugMode) {
          print('✅ [MEMORY_VERSES] Review submitted successfully');
        }

        return data;
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Memory verse not found',
          code: 'VERSE_NOT_FOUND',
        );
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      _handleException(e, 'submitting review');
    }
  }

  /// Handles error responses from the API
  Never _handleErrorResponse(dynamic response) {
    final statusCode = response.statusCode;
    String errorMessage = 'Unknown error occurred';
    String errorCode = 'UNKNOWN_ERROR';

    try {
      final jsonData = jsonDecode(response.body);
      if (jsonData['error'] != null && jsonData['error']['message'] != null) {
        errorMessage = jsonData['error']['message'] as String;
      }
      if (jsonData['error'] != null && jsonData['error']['code'] != null) {
        errorCode = jsonData['error']['code'] as String;
      }
    } catch (e) {
      errorMessage = 'Server error: ${response.body}';
    }

    if (kDebugMode) {
      print('❌ [MEMORY_VERSES] Error ($statusCode): $errorMessage');
    }

    throw ServerException(
      message: errorMessage,
      code: errorCode,
    );
  }

  /// Handles exceptions during API calls
  Never _handleException(dynamic error, String operation) {
    if (kDebugMode) {
      print('❌ [MEMORY_VERSES] Exception while $operation: $error');
    }

    if (error is ServerException) {
      throw error;
    }

    if (error is NetworkException) {
      throw error;
    }

    throw ServerException(
      message: 'Failed to complete $operation: ${error.toString()}',
      code: 'OPERATION_FAILED',
    );
  }
}
