import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/logger.dart';

/// Remote data source for personalization API calls
class PersonalizationRemoteDataSource {
  final SupabaseClient _supabaseClient;

  PersonalizationRemoteDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

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

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      Logger.error(
        'Failed to get personalization',
        tag: 'PERSONALIZATION',
        error: e,
      );
      rethrow;
    }
  }

  /// Saves the user's questionnaire responses
  Future<Map<String, dynamic>> savePersonalization({
    required String? faithJourney,
    required List<String> seeking,
    required String? timeCommitment,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'save-personalization',
        body: {
          'action': 'save',
          'data': {
            'faith_journey': faithJourney,
            'seeking': seeking,
            'time_commitment': timeCommitment,
          },
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to save personalization: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return data['data'] as Map<String, dynamic>;
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

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return data['data'] as Map<String, dynamic>;
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
