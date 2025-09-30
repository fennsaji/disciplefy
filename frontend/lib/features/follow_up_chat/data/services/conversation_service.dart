import 'dart:convert';
import '../../../../core/services/http_service.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../../../core/config/app_config.dart';
import '../models/conversation_history_response.dart';

/// Service for managing follow-up conversation history
class ConversationService {
  final HttpService _httpService;

  const ConversationService({
    required HttpService httpService,
  }) : _httpService = httpService;

  /// Loads existing conversation history for a study guide
  Future<ConversationHistoryResponse> loadConversationHistory(
      String studyGuideId) async {
    try {
      final headers = await ApiAuthHelper.getAuthHeaders();
      const baseUrl = AppConfig.supabaseUrl;

      // Build URL with query parameters
      final uri =
          Uri.parse('$baseUrl/functions/v1/conversation-history').replace(
        queryParameters: {
          'study_guide_id': studyGuideId,
        },
      );

      final response = await _httpService.get(
        uri.toString(),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConversationHistoryResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        // No conversation history found - return empty
        return ConversationHistoryResponse.empty(studyGuideId);
      } else {
        throw Exception(
            'Failed to load conversation history: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load conversation history: $e');
    }
  }
}
