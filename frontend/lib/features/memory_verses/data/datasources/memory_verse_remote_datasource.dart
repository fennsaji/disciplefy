import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/api_error_handler.dart';
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
  static const String _fetchVerseEndpoint = '/functions/v1/fetch-verse';

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
}
