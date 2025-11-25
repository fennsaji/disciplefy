import 'package:equatable/equatable.dart';

import '../../domain/entities/voice_conversation_entity.dart';
import '../../domain/entities/voice_preferences_entity.dart';

/// State for voice conversation BLoC.
class VoiceConversationState extends Equatable {
  final VoiceConversationStatus status;
  final VoiceConversationEntity? conversation;
  final List<ConversationMessageEntity> messages;
  final String? currentTranscription;
  final String streamingResponse;
  final bool isListening;
  final bool isPlaying;
  final bool isContinuousMode;
  final String languageCode;
  final VoiceQuotaEntity? quota;
  final String? errorMessage;
  final List<VoiceConversationEntity> conversationHistory;

  const VoiceConversationState({
    this.status = VoiceConversationStatus.initial,
    this.conversation,
    this.messages = const [],
    this.currentTranscription,
    this.streamingResponse = '',
    this.isListening = false,
    this.isPlaying = false,
    this.isContinuousMode = false,
    this.languageCode = 'en-US',
    this.quota,
    this.errorMessage,
    this.conversationHistory = const [],
  });

  @override
  List<Object?> get props => [
        status,
        conversation,
        messages,
        currentTranscription,
        streamingResponse,
        isListening,
        isPlaying,
        isContinuousMode,
        languageCode,
        quota,
        errorMessage,
        conversationHistory,
      ];

  VoiceConversationState copyWith({
    VoiceConversationStatus? status,
    VoiceConversationEntity? conversation,
    List<ConversationMessageEntity>? messages,
    String? currentTranscription,
    String? streamingResponse,
    bool? isListening,
    bool? isPlaying,
    bool? isContinuousMode,
    String? languageCode,
    VoiceQuotaEntity? quota,
    String? errorMessage,
    List<VoiceConversationEntity>? conversationHistory,
  }) {
    return VoiceConversationState(
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      streamingResponse: streamingResponse ?? this.streamingResponse,
      isListening: isListening ?? this.isListening,
      isPlaying: isPlaying ?? this.isPlaying,
      isContinuousMode: isContinuousMode ?? this.isContinuousMode,
      languageCode: languageCode ?? this.languageCode,
      quota: quota ?? this.quota,
      errorMessage: errorMessage,
      conversationHistory: conversationHistory ?? this.conversationHistory,
    );
  }

  /// Whether the conversation is active.
  bool get hasActiveConversation =>
      conversation != null && conversation!.status == ConversationStatus.active;

  /// Whether the user can start a new conversation (has quota).
  bool get canStartConversation => quota == null || quota!.canStart;

  /// Get remaining quota as a string.
  String get quotaDisplay {
    if (quota == null) return '';
    if (quota!.quotaRemaining < 0) return 'Unlimited';
    return '${quota!.quotaRemaining}/${quota!.quotaLimit}';
  }
}

/// Status of the voice conversation.
enum VoiceConversationStatus {
  initial,
  loading,
  ready,
  listening,
  processing,
  streaming,
  playing,
  error,
  quotaExceeded,
}
