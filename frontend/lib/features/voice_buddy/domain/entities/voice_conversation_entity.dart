import 'package:equatable/equatable.dart';

/// Entity representing a voice conversation session.
class VoiceConversationEntity extends Equatable {
  final String id;
  final String userId;
  final String sessionId;
  final String languageCode;
  final ConversationType conversationType;
  final String? relatedStudyGuideId;
  final String? relatedScripture;
  final int totalMessages;
  final int totalDurationSeconds;
  final ConversationStatus status;
  final int? rating;
  final String? feedbackText;
  final bool? wasHelpful;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationMessageEntity>? messages;

  const VoiceConversationEntity({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.languageCode,
    required this.conversationType,
    this.relatedStudyGuideId,
    this.relatedScripture,
    required this.totalMessages,
    required this.totalDurationSeconds,
    required this.status,
    this.rating,
    this.feedbackText,
    this.wasHelpful,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        sessionId,
        languageCode,
        conversationType,
        relatedStudyGuideId,
        relatedScripture,
        totalMessages,
        totalDurationSeconds,
        status,
        rating,
        feedbackText,
        wasHelpful,
        startedAt,
        endedAt,
        createdAt,
        updatedAt,
        messages,
      ];

  VoiceConversationEntity copyWith({
    String? id,
    String? userId,
    String? sessionId,
    String? languageCode,
    ConversationType? conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
    int? totalMessages,
    int? totalDurationSeconds,
    ConversationStatus? status,
    int? rating,
    String? feedbackText,
    bool? wasHelpful,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationMessageEntity>? messages,
  }) {
    return VoiceConversationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      languageCode: languageCode ?? this.languageCode,
      conversationType: conversationType ?? this.conversationType,
      relatedStudyGuideId: relatedStudyGuideId ?? this.relatedStudyGuideId,
      relatedScripture: relatedScripture ?? this.relatedScripture,
      totalMessages: totalMessages ?? this.totalMessages,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      feedbackText: feedbackText ?? this.feedbackText,
      wasHelpful: wasHelpful ?? this.wasHelpful,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}

/// Entity representing a single message in a conversation.
class ConversationMessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String userId;
  final int messageOrder;
  final MessageRole role;
  final String contentText;
  final String contentLanguage;
  final double? audioDurationSeconds;
  final String? audioUrl;
  final double? transcriptionConfidence;
  final String? llmModelUsed;
  final int? llmTokensUsed;
  final List<String>? scriptureReferences;
  final DateTime createdAt;

  const ConversationMessageEntity({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.messageOrder,
    required this.role,
    required this.contentText,
    required this.contentLanguage,
    this.audioDurationSeconds,
    this.audioUrl,
    this.transcriptionConfidence,
    this.llmModelUsed,
    this.llmTokensUsed,
    this.scriptureReferences,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        conversationId,
        userId,
        messageOrder,
        role,
        contentText,
        contentLanguage,
        audioDurationSeconds,
        audioUrl,
        transcriptionConfidence,
        llmModelUsed,
        llmTokensUsed,
        scriptureReferences,
        createdAt,
      ];
}

/// Types of voice conversations.
enum ConversationType {
  general,
  studyEnhancement,
  scriptureInquiry,
  prayerGuidance,
  theologicalDebate,
}

/// Status of a voice conversation.
enum ConversationStatus {
  active,
  completed,
  abandoned,
}

/// Role of a message sender.
enum MessageRole {
  user,
  assistant,
}

/// Extension to convert enum to/from string.
extension ConversationTypeExtension on ConversationType {
  String get value {
    switch (this) {
      case ConversationType.general:
        return 'general';
      case ConversationType.studyEnhancement:
        return 'study_enhancement';
      case ConversationType.scriptureInquiry:
        return 'scripture_inquiry';
      case ConversationType.prayerGuidance:
        return 'prayer_guidance';
      case ConversationType.theologicalDebate:
        return 'theological_debate';
    }
  }

  static ConversationType fromString(String value) {
    switch (value) {
      case 'general':
        return ConversationType.general;
      case 'study_enhancement':
        return ConversationType.studyEnhancement;
      case 'scripture_inquiry':
        return ConversationType.scriptureInquiry;
      case 'prayer_guidance':
        return ConversationType.prayerGuidance;
      case 'theological_debate':
        return ConversationType.theologicalDebate;
      default:
        return ConversationType.general;
    }
  }
}

extension ConversationStatusExtension on ConversationStatus {
  String get value {
    switch (this) {
      case ConversationStatus.active:
        return 'active';
      case ConversationStatus.completed:
        return 'completed';
      case ConversationStatus.abandoned:
        return 'abandoned';
    }
  }

  static ConversationStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ConversationStatus.active;
      case 'completed':
        return ConversationStatus.completed;
      case 'abandoned':
        return ConversationStatus.abandoned;
      default:
        return ConversationStatus.active;
    }
  }
}

extension MessageRoleExtension on MessageRole {
  String get value {
    switch (this) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
    }
  }

  static MessageRole fromString(String value) {
    switch (value) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      default:
        return MessageRole.user;
    }
  }
}
