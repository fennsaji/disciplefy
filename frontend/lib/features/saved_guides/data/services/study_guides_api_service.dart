import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/saved_guide_model.dart';

/// API service for managing study guides (saved/recent)
class StudyGuidesApiService {
  static String get _baseUrl => AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _studyGuidesEndpoint = '/functions/v1/study-guides';
  
  final HttpService _httpService;

  StudyGuidesApiService({HttpService? httpService}) 
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Fetch study guides from API
  /// [savedOnly] - if true, only fetch saved guides
  /// [limit] - maximum number of guides to fetch
  /// [offset] - offset for pagination
  Future<List<SavedGuideModel>> getStudyGuides({
    bool savedOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (savedOnly) {
        queryParams['saved'] = 'true';
      } else {
        queryParams['saved'] = 'false';
      }

      final uri = Uri.parse('$_baseUrl$_studyGuidesEndpoint')
          .replace(queryParameters: queryParams);

      // Prepare headers
      final headers = await _httpService.createHeaders();
      
      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final guidesData = jsonData['data']['guides'] as List<dynamic>? ?? [];
          
          return guidesData.map((guideJson) => 
            SavedGuideModel.fromApiResponse(guideJson as Map<String, dynamic>)
          ).toList();
        } else {
          throw const ServerException(
            message: 'API returned failure response',
            code: 'API_ERROR',
          );
        }
      } else {
        throw ServerException(
          message: 'Failed to fetch study guides: ${response.statusCode}',
          code: 'SERVER_ERROR',
        );
      }
    } catch (e) {
      if (e is ServerException || e is AuthenticationException) {
        rethrow;
      }
      throw NetworkException(
        message: 'Failed to connect to study guides service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Save or unsave a study guide
  Future<SavedGuideModel> saveUnsaveGuide({
    required String guideId,
    required bool save,
  }) async {
    try {
      final headers = await _httpService.createHeaders();
      
      final body = json.encode({
        'guide_id': guideId,
        'action': save ? 'save' : 'unsave',
      });

      final response = await _httpService.post(
        '$_baseUrl$_studyGuidesEndpoint',
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final guideData = jsonData['data']['guide'] as Map<String, dynamic>;
          return SavedGuideModel.fromApiResponse(guideData);
        } else {
          throw const ServerException(
            message: 'API returned failure response',
            code: 'API_ERROR',
          );
        }
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Study guide not found',
          code: 'NOT_FOUND',
        );
      } else {
        throw ServerException(
          message: 'Failed to ${save ? 'save' : 'unsave'} study guide: ${response.statusCode}',
          code: 'SERVER_ERROR',
        );
      }
    } catch (e) {
      if (e is ServerException || e is AuthenticationException) {
        rethrow;
      }
      throw NetworkException(
        message: 'Failed to connect to study guides service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }



  /// Dispose HTTP client
  void dispose() {
    _httpService.dispose();
  }
}