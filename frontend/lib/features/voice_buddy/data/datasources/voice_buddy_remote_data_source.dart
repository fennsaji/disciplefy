import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../models/voice_conversation_model.dart';
import '../models/voice_preferences_model.dart';

/// Abstract contract for remote voice buddy operations.
abstract class VoiceBuddyRemoteDataSource {
  /// Gets voice preferences for the authenticated user.
  Future<VoicePreferencesModel> getPreferences();

  /// Updates voice preferences for the authenticated user.
  Future<VoicePreferencesModel> updatePreferences(
      VoicePreferencesModel preferences);

  /// Resets voice preferences to defaults.
  Future<VoicePreferencesModel> resetPreferences();

  /// Checks if user can start a voice conversation (quota check).
  Future<VoiceQuotaModel> checkQuota();

  /// Starts a new voice conversation.
  Future<VoiceConversationModel> startConversation({
    required String languageCode,
    required String conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
  });

  /// Gets conversation history for the authenticated user.
  Future<List<VoiceConversationModel>> getConversationHistory({
    int limit = 20,
    int offset = 0,
  });

  /// Gets a conversation by ID with its messages.
  Future<VoiceConversationModel> getConversationById(String conversationId);

  /// Ends a voice conversation.
  Future<VoiceConversationModel> endConversation({
    required String conversationId,
    int? rating,
    String? feedbackText,
    bool? wasHelpful,
  });

  /// Adds a message to a conversation.
  Future<ConversationMessageModel> addMessage({
    required String conversationId,
    required String role,
    required String contentText,
    required String contentLanguage,
    double? audioDurationSeconds,
    String? audioUrl,
    double? transcriptionConfidence,
    String? llmModelUsed,
    int? llmTokensUsed,
    List<String>? scriptureReferences,
  });
}

/// Implementation of VoiceBuddyRemoteDataSource using Supabase.
class VoiceBuddyRemoteDataSourceImpl implements VoiceBuddyRemoteDataSource {
  final SupabaseClient _supabaseClient;

  VoiceBuddyRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<VoicePreferencesModel> getPreferences() async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Fetching voice preferences...');

      final response = await _supabaseClient.rpc('get_voice_preferences');

      print('🎙️ [VOICE_API] Preferences response: $response');

      if (response != null) {
        return VoicePreferencesModel.fromJson(response as Map<String, dynamic>);
      } else {
        throw const ServerException(
          message: 'No voice preferences data available',
          code: 'NO_PREFERENCES_DATA',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected preferences error: $e');
      throw ClientException(
        message: 'Unable to fetch voice preferences. Please try again later.',
        code: 'VOICE_PREFERENCES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoicePreferencesModel> updatePreferences(
      VoicePreferencesModel preferences) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Updating voice preferences...');

      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Upsert preferences
      final response = await _supabaseClient
          .from('voice_preferences')
          .upsert({
            ...preferences.toJson(),
            'user_id': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print('🎙️ [VOICE_API] Updated preferences: $response');

      return VoicePreferencesModel.fromJson(response);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected update preferences error: $e');
      throw ClientException(
        message: 'Unable to update voice preferences. Please try again later.',
        code: 'UPDATE_PREFERENCES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoicePreferencesModel> resetPreferences() async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Resetting voice preferences to defaults...');

      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Delete existing preferences to reset to defaults
      await _supabaseClient
          .from('voice_preferences')
          .delete()
          .eq('user_id', user.id);

      // Get default preferences via RPC
      final response = await _supabaseClient.rpc('get_voice_preferences');

      print('🎙️ [VOICE_API] Reset preferences: $response');

      if (response != null) {
        return VoicePreferencesModel.fromJson(response as Map<String, dynamic>);
      } else {
        throw const ServerException(
          message: 'Failed to reset preferences',
          code: 'RESET_PREFERENCES_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected reset preferences error: $e');
      throw ClientException(
        message: 'Unable to reset voice preferences. Please try again later.',
        code: 'RESET_PREFERENCES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoiceQuotaModel> checkQuota() async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Checking voice quota...');

      final response = await _supabaseClient.rpc('check_voice_quota');

      print('🎙️ [VOICE_API] Quota response: $response');

      if (response != null) {
        return VoiceQuotaModel.fromJson(response as Map<String, dynamic>);
      } else {
        throw const ServerException(
          message: 'Failed to check quota',
          code: 'QUOTA_CHECK_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected quota check error: $e');
      throw ClientException(
        message: 'Unable to check voice quota. Please try again later.',
        code: 'QUOTA_CHECK_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoiceConversationModel> startConversation({
    required String languageCode,
    required String conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
  }) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Starting conversation...');

      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // First increment voice usage
      await _supabaseClient.rpc('increment_voice_usage');

      // Create conversation
      final sessionId =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();

      final response = await _supabaseClient
          .from('voice_conversations')
          .insert({
            'user_id': user.id,
            'session_id': sessionId,
            'language_code': languageCode,
            'conversation_type': conversationType,
            'related_study_guide_id': relatedStudyGuideId,
            'related_scripture': relatedScripture,
            'total_messages': 0,
            'total_duration_seconds': 0,
            'status': 'active',
            'started_at': now,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      print('🎙️ [VOICE_API] Started conversation: ${response['id']}');

      return VoiceConversationModel.fromJson(response);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected start conversation error: $e');
      throw ClientException(
        message: 'Unable to start conversation. Please try again later.',
        code: 'START_CONVERSATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<VoiceConversationModel>> getConversationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Fetching conversation history...');

      final response = await _supabaseClient.rpc(
        'get_voice_conversation_history',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      print(
          '🎙️ [VOICE_API] History response: ${(response as List?)?.length ?? 0} conversations');

      if (response is List) {
        return response
            .map((json) =>
                VoiceConversationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected conversation history error: $e');
      throw ClientException(
        message:
            'Unable to fetch conversation history. Please try again later.',
        code: 'CONVERSATION_HISTORY_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoiceConversationModel> getConversationById(
      String conversationId) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Fetching conversation: $conversationId');

      // Get conversation with messages
      final conversationResponse = await _supabaseClient
          .from('voice_conversations')
          .select()
          .eq('id', conversationId)
          .single();

      final messagesResponse = await _supabaseClient
          .from('voice_conversation_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('message_order', ascending: true);

      // Combine data
      final conversationData = {
        ...conversationResponse,
        'messages': messagesResponse,
      };

      print('🎙️ [VOICE_API] Fetched conversation with '
          '${(messagesResponse as List).length} messages');

      return VoiceConversationModel.fromJson(conversationData);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected get conversation error: $e');
      throw ClientException(
        message: 'Unable to fetch conversation. Please try again later.',
        code: 'GET_CONVERSATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<VoiceConversationModel> endConversation({
    required String conversationId,
    int? rating,
    String? feedbackText,
    bool? wasHelpful,
  }) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Ending conversation: $conversationId');

      final response = await _supabaseClient.rpc(
        'complete_voice_conversation',
        params: {
          'p_conversation_id': conversationId,
          'p_rating': rating,
          'p_feedback_text': feedbackText,
          'p_was_helpful': wasHelpful,
        },
      );

      print('🎙️ [VOICE_API] Ended conversation: $response');

      if (response != null) {
        return VoiceConversationModel.fromJson(
            response as Map<String, dynamic>);
      } else {
        // Fetch the conversation if RPC doesn't return it
        return getConversationById(conversationId);
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected end conversation error: $e');
      throw ClientException(
        message: 'Unable to end conversation. Please try again later.',
        code: 'END_CONVERSATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<ConversationMessageModel> addMessage({
    required String conversationId,
    required String role,
    required String contentText,
    required String contentLanguage,
    double? audioDurationSeconds,
    String? audioUrl,
    double? transcriptionConfidence,
    String? llmModelUsed,
    int? llmTokensUsed,
    List<String>? scriptureReferences,
  }) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();

      print('🎙️ [VOICE_API] Adding message to conversation: $conversationId');

      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Get current message count for ordering
      final countResponse = await _supabaseClient
          .from('voice_conversation_messages')
          .select('id')
          .eq('conversation_id', conversationId);
      final messageOrder = (countResponse as List).length;

      // Insert message
      final response = await _supabaseClient
          .from('voice_conversation_messages')
          .insert({
            'conversation_id': conversationId,
            'user_id': user.id,
            'message_order': messageOrder,
            'role': role,
            'content_text': contentText,
            'content_language': contentLanguage,
            'audio_duration_seconds': audioDurationSeconds,
            'audio_url': audioUrl,
            'transcription_confidence': transcriptionConfidence,
            'llm_model_used': llmModelUsed,
            'llm_tokens_used': llmTokensUsed,
            'scripture_references': scriptureReferences,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Update conversation message count and duration
      await _supabaseClient.from('voice_conversations').update({
        'total_messages': messageOrder + 1,
        'total_duration_seconds': await _calculateTotalDuration(conversationId),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);

      print('🎙️ [VOICE_API] Added message: ${response['id']}');

      return ConversationMessageModel.fromJson(response);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [VOICE_API] Unexpected add message error: $e');
      throw ClientException(
        message: 'Unable to add message. Please try again later.',
        code: 'ADD_MESSAGE_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  /// Calculates total duration of all messages in a conversation.
  Future<int> _calculateTotalDuration(String conversationId) async {
    final messages = await _supabaseClient
        .from('voice_conversation_messages')
        .select('audio_duration_seconds')
        .eq('conversation_id', conversationId);

    double total = 0;
    for (final msg in messages as List) {
      final duration = msg['audio_duration_seconds'];
      if (duration != null) {
        total += (duration as num).toDouble();
      }
    }

    return total.round();
  }
}
