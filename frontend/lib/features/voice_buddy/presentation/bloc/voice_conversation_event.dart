import 'package:equatable/equatable.dart';

import '../../domain/entities/voice_conversation_entity.dart';

/// Events for voice conversation BLoC.
abstract class VoiceConversationEvent extends Equatable {
  const VoiceConversationEvent();

  @override
  List<Object?> get props => [];
}

/// Start a new voice conversation.
class StartConversation extends VoiceConversationEvent {
  final String languageCode;
  final ConversationType conversationType;
  final String? relatedStudyGuideId;
  final String? relatedScripture;

  const StartConversation({
    required this.languageCode,
    this.conversationType = ConversationType.general,
    this.relatedStudyGuideId,
    this.relatedScripture,
  });

  @override
  List<Object?> get props => [
        languageCode,
        conversationType,
        relatedStudyGuideId,
        relatedScripture,
      ];
}

/// End the current conversation.
class EndConversation extends VoiceConversationEvent {
  final int? rating;
  final String? feedbackText;
  final bool? wasHelpful;

  const EndConversation({
    this.rating,
    this.feedbackText,
    this.wasHelpful,
  });

  @override
  List<Object?> get props => [rating, feedbackText, wasHelpful];
}

/// Start listening for user speech.
class StartListening extends VoiceConversationEvent {
  const StartListening();
}

/// Stop listening for user speech.
class StopListening extends VoiceConversationEvent {
  const StopListening();
}

/// Process transcribed speech text.
class ProcessSpeechText extends VoiceConversationEvent {
  final String text;
  final double? confidence;

  const ProcessSpeechText({
    required this.text,
    this.confidence,
  });

  @override
  List<Object?> get props => [text, confidence];
}

/// Send a text message (typed input).
class SendTextMessage extends VoiceConversationEvent {
  final String message;

  const SendTextMessage(this.message);

  @override
  List<Object?> get props => [message];
}

/// Handle streaming response chunk.
class ReceiveStreamChunk extends VoiceConversationEvent {
  final String chunk;

  const ReceiveStreamChunk(this.chunk);

  @override
  List<Object?> get props => [chunk];
}

/// Handle stream completion.
class StreamCompleted extends VoiceConversationEvent {
  final List<String>? scriptureReferences;

  const StreamCompleted({this.scriptureReferences});

  @override
  List<Object?> get props => [scriptureReferences];
}

/// Handle stream error.
class StreamError extends VoiceConversationEvent {
  final String message;

  const StreamError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Monthly conversation limit exceeded.
class MonthlyLimitExceeded extends VoiceConversationEvent {
  final int conversationsUsed;
  final int limit;
  final int remaining;
  final String tier;
  final String month;
  final String message;

  const MonthlyLimitExceeded({
    required this.conversationsUsed,
    required this.limit,
    required this.remaining,
    required this.tier,
    required this.month,
    required this.message,
  });

  @override
  List<Object?> get props => [
        conversationsUsed,
        limit,
        remaining,
        tier,
        month,
        message,
      ];
}

/// Play the AI response audio.
class PlayResponse extends VoiceConversationEvent {
  const PlayResponse();
}

/// Stop playing audio.
class StopPlayback extends VoiceConversationEvent {
  const StopPlayback();
}

/// Check voice quota status.
class CheckQuota extends VoiceConversationEvent {
  const CheckQuota();
}

/// Load user's voice preferences to get default language.
class LoadPreferences extends VoiceConversationEvent {
  const LoadPreferences();
}

/// Load conversation history.
class LoadConversationHistory extends VoiceConversationEvent {
  final int limit;
  final int offset;

  const LoadConversationHistory({
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Load a specific conversation.
class LoadConversation extends VoiceConversationEvent {
  final String conversationId;

  const LoadConversation(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

/// Toggle continuous listening mode.
class ToggleContinuousMode extends VoiceConversationEvent {
  final bool enabled;

  const ToggleContinuousMode(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Change conversation language.
class ChangeLanguage extends VoiceConversationEvent {
  final String languageCode;

  const ChangeLanguage(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

/// Handle playback completion.
class PlaybackCompleted extends VoiceConversationEvent {
  final bool shouldContinueListening;

  const PlaybackCompleted({required this.shouldContinueListening});

  @override
  List<Object?> get props => [shouldContinueListening];
}

/// Handle speech recognition status change.
class SpeechStatusChanged extends VoiceConversationEvent {
  final String status;

  const SpeechStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}
