import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failures.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../models/recommended_guide_topic_response.dart';

/// Service for fetching recommended study guide topics from the backend API.
class RecommendedGuidesService {
  // API Configuration
  static const String _baseUrl = 'http://127.0.0.1:54321';
  static const String _topicsEndpoint = '/functions/v1/topics-recommended';
  
  // Secure storage for auth token
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  final http.Client _httpClient;

  RecommendedGuidesService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  /// Fetches all recommended guide topics from the API.
  /// 
  /// Returns [Right] with list of topics on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, List<RecommendedGuideTopic>>> getAllTopics() async {
    try {
      // Get auth token from secure storage
      final authToken = await _secureStorage.read(key: 'auth_token');
      
      if (authToken == null || authToken.isEmpty) {
        print('⚠️ [TOPICS] No auth token found, using mock data');
        return Right(_getMockTopics());
      }

      print('🚀 [TOPICS] Fetching topics from API...');
      
      // Make API request
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl$_topicsEndpoint'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 [TOPICS] API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseTopicsResponse(response.body);
      } else if (response.statusCode == 401) {
        print('🔒 [TOPICS] Unauthorized - token may be expired');
        return Left(AuthenticationFailure(message: 'Authentication token expired or invalid'));
      } else {
        print('❌ [TOPICS] API error: ${response.statusCode} - ${response.body}');
        return Left(ServerFailure(message: 'Failed to fetch topics: ${response.statusCode}'));
      }
    } catch (e, stackTrace) {
      print('💥 [TOPICS] Exception: $e');
      print('📚 [TOPICS] Stack trace: $stackTrace');
      
      // Return mock data as fallback
      print('🔄 [TOPICS] Falling back to mock data');
      return Right(_getMockTopics());
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
      final authToken = await _secureStorage.read(key: 'auth_token');
      
      if (authToken == null || authToken.isEmpty) {
        return Right(_getMockTopics().take(limit ?? 10).toList());
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$_baseUrl$_topicsEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('🚀 [TOPICS] Fetching filtered topics: $uri');

      final response = await _httpClient.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseTopicsResponse(response.body);
      } else {
        return Left(ServerFailure(message: 'Failed to fetch filtered topics: ${response.statusCode}'));
      }
    } catch (e) {
      print('💥 [TOPICS] Filtered topics error: $e');
      return Right(_getMockTopics().take(limit ?? 6).toList());
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
        print('❌ [TOPICS] API response indicates failure: ${jsonData}');
        return Left(ClientFailure(message: 'API returned failure response'));
      }
    } catch (e) {
      print('💥 [TOPICS] JSON parsing error: $e');
      print('📄 [TOPICS] Raw response: $responseBody');
      return Left(ClientFailure(message: 'Failed to parse topics response: $e'));
    }
  }

  /// Returns mock topics for fallback/offline use.
  List<RecommendedGuideTopic> _getMockTopics() {
    return [
      RecommendedGuideTopic(
        id: 'mock-1',
        title: 'Understanding Faith',
        description: 'Explore the biblical foundations of faith and trust in God.',
        category: 'Faith Foundations',
        difficulty: 'beginner',
        estimatedMinutes: 30,
        scriptureCount: 5,
        tags: ['faith', 'foundation', 'beginner'],
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      RecommendedGuideTopic(
        id: 'mock-2',
        title: 'The Power of Prayer',
        description: 'Learn how to communicate effectively with God through prayer.',
        category: 'Spiritual Disciplines',
        difficulty: 'beginner',
        estimatedMinutes: 35,
        scriptureCount: 4,
        tags: ['prayer', 'communication', 'discipline'],
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      RecommendedGuideTopic(
        id: 'mock-3',
        title: 'God\'s Amazing Grace',
        description: 'Understand the depth and breadth of God\'s unmerited favor.',
        category: 'Salvation',
        difficulty: 'intermediate',
        estimatedMinutes: 45,
        scriptureCount: 6,
        tags: ['grace', 'salvation', 'mercy'],
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      RecommendedGuideTopic(
        id: 'mock-4',
        title: 'Following Jesus',
        description: 'What it means to be a disciple in today\'s world.',
        category: 'Christian Living',
        difficulty: 'intermediate',
        estimatedMinutes: 50,
        scriptureCount: 7,
        tags: ['discipleship', 'following', 'obedience'],
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      RecommendedGuideTopic(
        id: 'mock-5',
        title: 'God\'s Love',
        description: 'Experience and understand the depth of God\'s love for humanity.',
        category: 'Character of God',
        difficulty: 'beginner',
        estimatedMinutes: 40,
        scriptureCount: 5,
        tags: ['love', 'character', 'relationship'],
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      RecommendedGuideTopic(
        id: 'mock-6',
        title: 'Forgiveness and Healing',
        description: 'Learn to forgive others as God has forgiven us.',
        category: 'Relationships',
        difficulty: 'intermediate',
        estimatedMinutes: 55,
        scriptureCount: 8,
        tags: ['forgiveness', 'healing', 'relationships'],
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Disposes of the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}