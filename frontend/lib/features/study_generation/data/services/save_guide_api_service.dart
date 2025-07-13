import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';

/// API service for saving/unsaving study guides
class SaveGuideApiService {
  static String get _baseUrl => AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _saveGuideEndpoint = '/functions/v1/study-guides';
  
  final http.Client _httpClient;

  SaveGuideApiService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  /// Save or unsave a study guide
  Future<bool> toggleSaveGuide({
    required String guideId,
    required bool save,
  }) async {
    try {
      final headers = await ApiAuthHelper.getAuthHeaders();
      
      final body = json.encode({
        'guide_id': guideId,
        'action': save ? 'save' : 'unsave',
      });

      final response = await _httpClient.post(
        Uri.parse('$_baseUrl$_saveGuideEndpoint'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to save guides',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Study guide not found',
          code: 'NOT_FOUND',
        );
      } else {
        final Map<String, dynamic>? errorData = 
            json.decode(response.body) as Map<String, dynamic>?;
        
        throw ServerException(
          message: errorData?['message'] ?? 'Failed to ${save ? 'save' : 'unsave'} study guide',
          code: errorData?['error'] ?? 'SERVER_ERROR',
        );
      }
    } catch (e) {
      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }
      throw NetworkException(
        message: 'Failed to connect to save guide service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }



  /// Dispose HTTP client
  void dispose() {
    _httpClient.close();
  }
}