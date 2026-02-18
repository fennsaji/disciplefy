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

  // User preferences
  final bool showTranscription;
  final bool autoPlayResponse;
  final bool autoDetectLanguage;
  final bool notifyDailyQuotaReached;

  // TTS voice preferences
  final double speakingRate;
  final double pitch;
  final String voiceGender; // 'male' or 'female'

  const VoiceConversationState({
    this.status = VoiceConversationStatus.initial,
    this.conversation,
    this.messages = const [],
    this.currentTranscription,
    this.streamingResponse = '',
    this.isListening = false,
    this.isPlaying = false,
    this.isContinuousMode = true,
    this.languageCode = 'en-US',
    this.quota,
    this.errorMessage,
    this.conversationHistory = const [],
    // Preference defaults
    this.showTranscription = true,
    this.autoPlayResponse = true,
    this.autoDetectLanguage = true,
    this.notifyDailyQuotaReached = true,
    // TTS voice preference defaults
    this.speakingRate = 1.0,
    this.pitch = 0.0,
    this.voiceGender = 'female',
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
        showTranscription,
        autoPlayResponse,
        autoDetectLanguage,
        notifyDailyQuotaReached,
        speakingRate,
        pitch,
        voiceGender,
      ];

  VoiceConversationState copyWith({
    VoiceConversationStatus? status,
    VoiceConversationEntity? conversation,
    List<ConversationMessageEntity>? messages,
    String? currentTranscription,
    bool clearCurrentTranscription = false,
    String? streamingResponse,
    bool? isListening,
    bool? isPlaying,
    bool? isContinuousMode,
    String? languageCode,
    VoiceQuotaEntity? quota,
    String? errorMessage,
    List<VoiceConversationEntity>? conversationHistory,
    bool? showTranscription,
    bool? autoPlayResponse,
    bool? autoDetectLanguage,
    bool? notifyDailyQuotaReached,
    double? speakingRate,
    double? pitch,
    String? voiceGender,
  }) {
    return VoiceConversationState(
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      currentTranscription: clearCurrentTranscription
          ? null
          : (currentTranscription ?? this.currentTranscription),
      streamingResponse: streamingResponse ?? this.streamingResponse,
      isListening: isListening ?? this.isListening,
      isPlaying: isPlaying ?? this.isPlaying,
      isContinuousMode: isContinuousMode ?? this.isContinuousMode,
      languageCode: languageCode ?? this.languageCode,
      quota: quota ?? this.quota,
      errorMessage: errorMessage,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      showTranscription: showTranscription ?? this.showTranscription,
      autoPlayResponse: autoPlayResponse ?? this.autoPlayResponse,
      autoDetectLanguage: autoDetectLanguage ?? this.autoDetectLanguage,
      notifyDailyQuotaReached:
          notifyDailyQuotaReached ?? this.notifyDailyQuotaReached,
      speakingRate: speakingRate ?? this.speakingRate,
      pitch: pitch ?? this.pitch,
      voiceGender: voiceGender ?? this.voiceGender,
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
  monthlyLimitExceeded,
}

/// Specific state when monthly conversation limit is exceeded.
/// Contains detailed information about the limit for display in UI.
class VoiceConversationMonthlyLimitExceeded extends VoiceConversationState {
  final int conversationsUsed;
  final int limit;
  final int remaining;
  final String tier;
  final String month;
  final String message;

  const VoiceConversationMonthlyLimitExceeded({
    required this.conversationsUsed,
    required this.limit,
    required this.remaining,
    required this.tier,
    required this.month,
    required this.message,
    // Pass through other state properties
    super.quota,
    super.languageCode,
    super.conversationHistory,
    super.showTranscription,
    super.autoPlayResponse,
    super.autoDetectLanguage,
    super.notifyDailyQuotaReached,
    super.speakingRate,
    super.pitch,
    super.voiceGender,
  }) : super(
          status: VoiceConversationStatus.monthlyLimitExceeded,
          errorMessage: message,
        );

  @override
  List<Object?> get props => [
        ...super.props,
        conversationsUsed,
        limit,
        remaining,
        tier,
        month,
        message,
      ];
}
