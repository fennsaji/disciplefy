import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/voice_conversation_entity.dart';
import '../entities/voice_preferences_entity.dart';

/// Repository interface for voice buddy feature.
abstract class VoiceBuddyRepository {
  // ============================================================================
  // Conversation Management
  // ============================================================================

  /// Start a new voice conversation.
  Future<Either<Failure, VoiceConversationEntity>> startConversation({
    required String languageCode,
    required ConversationType conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
  });

  /// End a conversation and save feedback.
  Future<Either<Failure, void>> endConversation({
    required String conversationId,
    int? rating,
    String? feedbackText,
    bool? wasHelpful,
  });

  /// Get conversation history for the current user.
  Future<Either<Failure, List<VoiceConversationEntity>>>
      getConversationHistory({
    int limit = 20,
    int offset = 0,
  });

  /// Get a specific conversation with messages.
  Future<Either<Failure, VoiceConversationEntity>> getConversation(
      String conversationId);

  /// Save a message to a conversation.
  Future<Either<Failure, ConversationMessageEntity>> saveMessage({
    required String conversationId,
    required int messageOrder,
    required MessageRole role,
    required String contentText,
    required String contentLanguage,
    double? audioDurationSeconds,
    double? transcriptionConfidence,
    String? llmModelUsed,
    int? llmTokensUsed,
    List<String>? scriptureReferences,
  });

  // ============================================================================
  // Quota Management
  // ============================================================================

  /// Check current voice quota status.
  Future<Either<Failure, VoiceQuotaEntity>> checkQuota();

  /// Increment usage when starting a conversation.
  Future<Either<Failure, void>> incrementUsage(String languageCode);

  // ============================================================================
  // Preferences Management
  // ============================================================================

  /// Get user voice preferences.
  Future<Either<Failure, VoicePreferencesEntity>> getPreferences();

  /// Update user voice preferences.
  Future<Either<Failure, VoicePreferencesEntity>> updatePreferences(
      VoicePreferencesEntity preferences);

  /// Reset preferences to defaults.
  Future<Either<Failure, VoicePreferencesEntity>> resetPreferences();
}
