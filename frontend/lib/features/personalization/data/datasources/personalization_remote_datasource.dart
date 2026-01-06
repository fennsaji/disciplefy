import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/logger.dart';

/// Remote data source for personalization API calls
class PersonalizationRemoteDataSource {
  final SupabaseClient _supabaseClient;

  PersonalizationRemoteDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  /// Safely parses the response data as a Map, throwing a clear exception if invalid
  Map<String, dynamic> _parseResponseData(dynamic responseData) {
    if (responseData == null) {
      throw Exception('Response body is null');
    }
    if (responseData is! Map<String, dynamic>) {
      throw Exception(
          'Invalid response body type: expected Map, got ${responseData.runtimeType}');
    }
    return responseData;
  }

  /// Safely extracts the nested 'data' field from a successful response
  Map<String, dynamic> _extractDataField(Map<String, dynamic> data) {
    final nestedData = data['data'];
    if (nestedData == null) {
      throw Exception('Response missing "data" field');
    }
    if (nestedData is! Map<String, dynamic>) {
      throw Exception(
          'Invalid "data" field type: expected Map, got ${nestedData.runtimeType}');
    }
    return nestedData;
  }

  /// Gets the user's personalization data from the API
  Future<Map<String, dynamic>> getPersonalization() async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'save-personalization',
        body: {'action': 'get'},
      );

      if (response.status != 200) {
        throw Exception('Failed to get personalization: ${response.status}');
      }

      final data = _parseResponseData(response.data);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return _extractDataField(data);
    } catch (e) {
      Logger.error(
        'Failed to get personalization',
        tag: 'PERSONALIZATION',
        error: e,
      );
      rethrow;
    }
  }

  /// Saves the user's questionnaire responses (6 questions)
  Future<Map<String, dynamic>> savePersonalization({
    required String? faithStage,
    required List<String> spiritualGoals,
    required String? timeAvailability,
    required String? learningStyle,
    required String? lifeStageFocus,
    required String? biggestChallenge,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'save-personalization',
        body: {
          'action': 'save',
          'data': {
            'faith_stage': faithStage,
            'spiritual_goals': spiritualGoals,
            'time_availability': timeAvailability,
            'learning_style': learningStyle,
            'life_stage_focus': lifeStageFocus,
            'biggest_challenge': biggestChallenge,
          },
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to save personalization: ${response.status}');
      }

      final data = _parseResponseData(response.data);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return _extractDataField(data);
    } catch (e) {
      Logger.error(
        'Failed to save personalization',
        tag: 'PERSONALIZATION',
        error: e,
      );
      rethrow;
    }
  }

  /// Marks the questionnaire as skipped
  Future<Map<String, dynamic>> skipQuestionnaire() async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'save-personalization',
        body: {'action': 'skip'},
      );

      if (response.status != 200) {
        throw Exception('Failed to skip questionnaire: ${response.status}');
      }

      final data = _parseResponseData(response.data);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return _extractDataField(data);
    } catch (e) {
      Logger.error(
        'Failed to skip questionnaire',
        tag: 'PERSONALIZATION',
        error: e,
      );
      rethrow;
    }
  }
}
