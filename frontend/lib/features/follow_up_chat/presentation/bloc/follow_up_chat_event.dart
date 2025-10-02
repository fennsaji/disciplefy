import 'package:equatable/equatable.dart';

/// Events for the follow-up chat feature
abstract class FollowUpChatEvent extends Equatable {
  const FollowUpChatEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start a new conversation for a study guide
class StartConversationEvent extends FollowUpChatEvent {
  final String studyGuideId;
  final String studyGuideTitle;

  const StartConversationEvent({
    required this.studyGuideId,
    required this.studyGuideTitle,
  });

  @override
  List<Object?> get props => [studyGuideId, studyGuideTitle];
}

/// Event to send a question to the conversation
class SendQuestionEvent extends FollowUpChatEvent {
  final String question;

  const SendQuestionEvent({
    required this.question,
  });

  @override
  List<Object?> get props => [question];
}

/// Event triggered when streaming response chunk is received
class StreamingChunkReceivedEvent extends FollowUpChatEvent {
  final String chunk;

  const StreamingChunkReceivedEvent(this.chunk);

  @override
  List<Object?> get props => [chunk];
}

/// Event triggered when streaming response is complete
class StreamingCompleteEvent extends FollowUpChatEvent {
  final String messageId;

  const StreamingCompleteEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

/// Event triggered when streaming error occurs
class StreamingErrorEvent extends FollowUpChatEvent {
  final String error;

  const StreamingErrorEvent(this.error);

  @override
  List<Object?> get props => [error];
}

/// Event to load conversation history
class LoadConversationHistoryEvent extends FollowUpChatEvent {
  const LoadConversationHistoryEvent();
}

/// Event to clear the current conversation
class ClearConversationEvent extends FollowUpChatEvent {
  const ClearConversationEvent();
}

/// Event to retry a failed message
class RetryMessageEvent extends FollowUpChatEvent {
  final String messageId;

  const RetryMessageEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

/// Event to cancel an ongoing request
class CancelRequestEvent extends FollowUpChatEvent {
  const CancelRequestEvent();
}
