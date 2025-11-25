import '../../domain/entities/voice_conversation_entity.dart';

/// Data model for VoiceConversation with JSON serialization.
class VoiceConversationModel extends VoiceConversationEntity {
  const VoiceConversationModel({
    required super.id,
    required super.userId,
    required super.sessionId,
    required super.languageCode,
    required super.conversationType,
    super.relatedStudyGuideId,
    super.relatedScripture,
    required super.totalMessages,
    required super.totalDurationSeconds,
    required super.status,
    super.rating,
    super.feedbackText,
    super.wasHelpful,
    required super.startedAt,
    super.endedAt,
    required super.createdAt,
    required super.updatedAt,
    super.messages,
  });

  factory VoiceConversationModel.fromJson(Map<String, dynamic> json) {
    return VoiceConversationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String,
      languageCode: json['language_code'] as String? ?? 'en-US',
      conversationType: ConversationTypeExtension.fromString(
          json['conversation_type'] as String? ?? 'general'),
      relatedStudyGuideId: json['related_study_guide_id'] as String?,
      relatedScripture: json['related_scripture'] as String?,
      totalMessages: json['total_messages'] as int? ?? 0,
      totalDurationSeconds: json['total_duration_seconds'] as int? ?? 0,
      status: ConversationStatusExtension.fromString(
          json['status'] as String? ?? 'active'),
      rating: json['rating'] as int?,
      feedbackText: json['feedback_text'] as String?,
      wasHelpful: json['was_helpful'] as bool?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) =>
                  ConversationMessageModel.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'language_code': languageCode,
      'conversation_type': conversationType.value,
      'related_study_guide_id': relatedStudyGuideId,
      'related_scripture': relatedScripture,
      'total_messages': totalMessages,
      'total_duration_seconds': totalDurationSeconds,
      'status': status.value,
      'rating': rating,
      'feedback_text': feedbackText,
      'was_helpful': wasHelpful,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VoiceConversationModel.fromEntity(VoiceConversationEntity entity) {
    return VoiceConversationModel(
      id: entity.id,
      userId: entity.userId,
      sessionId: entity.sessionId,
      languageCode: entity.languageCode,
      conversationType: entity.conversationType,
      relatedStudyGuideId: entity.relatedStudyGuideId,
      relatedScripture: entity.relatedScripture,
      totalMessages: entity.totalMessages,
      totalDurationSeconds: entity.totalDurationSeconds,
      status: entity.status,
      rating: entity.rating,
      feedbackText: entity.feedbackText,
      wasHelpful: entity.wasHelpful,
      startedAt: entity.startedAt,
      endedAt: entity.endedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      messages: entity.messages,
    );
  }
}

/// Data model for ConversationMessage with JSON serialization.
class ConversationMessageModel extends ConversationMessageEntity {
  const ConversationMessageModel({
    required super.id,
    required super.conversationId,
    required super.userId,
    required super.messageOrder,
    required super.role,
    required super.contentText,
    required super.contentLanguage,
    super.audioDurationSeconds,
    super.audioUrl,
    super.transcriptionConfidence,
    super.llmModelUsed,
    super.llmTokensUsed,
    super.scriptureReferences,
    required super.createdAt,
  });

  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    return ConversationMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      messageOrder: json['message_order'] as int,
      role: MessageRoleExtension.fromString(json['role'] as String),
      contentText: json['content_text'] as String,
      contentLanguage: json['content_language'] as String? ?? 'en-US',
      audioDurationSeconds: json['audio_duration_seconds'] != null
          ? (json['audio_duration_seconds'] as num).toDouble()
          : null,
      audioUrl: json['audio_url'] as String?,
      transcriptionConfidence: json['transcription_confidence'] != null
          ? (json['transcription_confidence'] as num).toDouble()
          : null,
      llmModelUsed: json['llm_model_used'] as String?,
      llmTokensUsed: json['llm_tokens_used'] as int?,
      scriptureReferences: json['scripture_references'] != null
          ? List<String>.from(json['scripture_references'] as List)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'message_order': messageOrder,
      'role': role.value,
      'content_text': contentText,
      'content_language': contentLanguage,
      'audio_duration_seconds': audioDurationSeconds,
      'audio_url': audioUrl,
      'transcription_confidence': transcriptionConfidence,
      'llm_model_used': llmModelUsed,
      'llm_tokens_used': llmTokensUsed,
      'scripture_references': scriptureReferences,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
