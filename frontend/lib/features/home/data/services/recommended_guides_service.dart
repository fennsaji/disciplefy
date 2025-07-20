import 'dart:convert';
import 'package:dartz/dartz.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../models/recommended_guide_topic_response.dart';

/// Service for fetching recommended study guide topics from the backend API.
class RecommendedGuidesService {
  // API Configuration
  static String get _baseUrl => AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _topicsEndpoint = '/functions/v1/topics-recommended';
  
  final HttpService _httpService;

  RecommendedGuidesService({HttpService? httpService}) 
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Fetches all recommended guide topics from the API.
  /// 
  /// Returns [Right] with list of topics on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, List<RecommendedGuideTopic>>> getAllTopics() async {
    try {
      print('🚀 [TOPICS] Fetching topics from API...');
      
      // Prepare headers for API request
      final headers = await _httpService.createHeaders();
      
      // Make API request
      final response = await _httpService.get(
        '$_baseUrl$_topicsEndpoint',
        headers: headers,
      );

      print('📡 [TOPICS] API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseTopicsResponse(response.body);
      } else {
        print('❌ [TOPICS] API error: ${response.statusCode} - ${response.body}');
        return Left(ServerFailure(message: 'Failed to fetch topics: ${response.statusCode}'));
      }
    } catch (e, stackTrace) {
      print('💥 [TOPICS] Exception: $e');
      print('📚 [TOPICS] Stack trace: $stackTrace');
      
      return Left(NetworkFailure(message: 'Failed to connect to topics service: $e'));
    }
  }

  /// Fetches filtered topics based on category, difficulty, and limit.
  /// 
  /// [category] - Filter by topic category (optional)
  /// [difficulty] - Filter by difficulty level (optional)  
  /// [limit] - Maximum number of topics to return (optional)
  Future<Either<Failure, List<RecommendedGuideTopic>>> getFilteredTopics({
    String? category,
    String? difficulty,
    int? limit,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$_baseUrl$_topicsEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('🚀 [TOPICS] Fetching filtered topics: $uri');

      // Prepare headers for API request
      final headers = await _httpService.createHeaders();

      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return _parseTopicsResponse(response.body);
      } else {
        print('💥 [TOPICS] API error ${response.statusCode}');
        return Left(ServerFailure(message: 'Failed to fetch filtered topics: ${response.statusCode}'));
      }
    } catch (e) {
      print('💥 [TOPICS] Filtered topics error: $e');
      return Left(NetworkFailure(message: 'Failed to fetch filtered topics: $e'));
    }
  }



  /// Parses the API response and converts to domain entities.
  Either<Failure, List<RecommendedGuideTopic>> _parseTopicsResponse(String responseBody) {
    try {
      print('📄 [TOPICS] Parsing response...');
      final Map<String, dynamic> jsonData = json.decode(responseBody);
      
      // Parse the expected API format: {"success": true, "data": {"topics": [...], "total": 15}}
      if (jsonData.containsKey('success') && jsonData['success'] == true) {
        final apiResponse = RecommendedGuideTopicsApiResponse.fromJson(jsonData);
        final topics = apiResponse.toEntities();
        
        print('✅ [TOPICS] Successfully parsed ${topics.length} topics');
        return Right(topics);
      } else {
        print('❌ [TOPICS] API response indicates failure: $jsonData');
        return const Left(ClientFailure(message: 'API returned failure response'));
      }
    } catch (e) {
      print('💥 [TOPICS] JSON parsing error: $e');
      print('📄 [TOPICS] Raw response: $responseBody');
      return Left(ClientFailure(message: 'Failed to parse topics response: $e'));
    }
  }


  /// Disposes of the HTTP client.
  void dispose() {
    _httpService.dispose();
  }
}