import 'package:equatable/equatable.dart';

/// Message model for chat conversations
class ChatMessage extends Equatable {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final int? tokensConsumed;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.tokensConsumed,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    ChatMessageStatus? status,
    int? tokensConsumed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      tokensConsumed: tokensConsumed ?? this.tokensConsumed,
    );
  }

  @override
  List<Object?> get props =>
      [id, content, isUser, timestamp, status, tokensConsumed];
}

/// Status of a chat message
enum ChatMessageStatus {
  sending,
  sent,
  streaming,
  failed,
  cancelled,
}

/// Token information for follow-up requests
class TokenInfo extends Equatable {
  final int consumed;
  final int remaining;
  final int dailyLimit;
  final String userPlan;

  const TokenInfo({
    required this.consumed,
    required this.remaining,
    required this.dailyLimit,
    required this.userPlan,
  });

  @override
  List<Object?> get props => [consumed, remaining, dailyLimit, userPlan];
}

/// States for the follow-up chat feature
abstract class FollowUpChatState extends Equatable {
  const FollowUpChatState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no conversation is active
class FollowUpChatInitial extends FollowUpChatState {
  const FollowUpChatInitial();
}

/// State when conversation is being loaded
class FollowUpChatLoading extends FollowUpChatState {
  const FollowUpChatLoading();
}

/// State with an active conversation
class FollowUpChatLoaded extends FollowUpChatState {
  final String studyGuideId;
  final String studyGuideTitle;
  final String conversationId;
  final List<ChatMessage> messages;
  final bool isProcessing;
  final String? currentStreamingMessageId;
  final String? error;
  final TokenInfo? tokenInfo;

  const FollowUpChatLoaded({
    required this.studyGuideId,
    required this.studyGuideTitle,
    required this.conversationId,
    required this.messages,
    this.isProcessing = false,
    this.currentStreamingMessageId,
    this.error,
    this.tokenInfo,
  });

  FollowUpChatLoaded copyWith({
    String? studyGuideId,
    String? studyGuideTitle,
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isProcessing,
    String? currentStreamingMessageId,
    String? error,
    TokenInfo? tokenInfo,
    bool clearError = false,
    bool clearStreamingMessage = false,
  }) {
    return FollowUpChatLoaded(
      studyGuideId: studyGuideId ?? this.studyGuideId,
      studyGuideTitle: studyGuideTitle ?? this.studyGuideTitle,
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      currentStreamingMessageId: clearStreamingMessage
          ? null
          : (currentStreamingMessageId ?? this.currentStreamingMessageId),
      error: clearError ? null : (error ?? this.error),
      tokenInfo: tokenInfo ?? this.tokenInfo,
    );
  }

  /// Gets the current assistant message being streamed
  ChatMessage? get currentStreamingMessage {
    if (currentStreamingMessageId == null) return null;
    try {
      return messages.firstWhere(
        (msg) => msg.id == currentStreamingMessageId && !msg.isUser,
      );
    } catch (e) {
      return null;
    }
  }

  /// Updates a specific message in the messages list
  FollowUpChatLoaded updateMessage(
      String messageId, ChatMessage updatedMessage) {
    final updatedMessages = messages.map((msg) {
      return msg.id == messageId ? updatedMessage : msg;
    }).toList();

    return copyWith(messages: updatedMessages);
  }

  /// Adds a new message to the conversation
  FollowUpChatLoaded addMessage(ChatMessage message) {
    return copyWith(messages: [...messages, message]);
  }

  @override
  List<Object?> get props => [
        studyGuideId,
        studyGuideTitle,
        conversationId,
        messages,
        isProcessing,
        currentStreamingMessageId,
        error,
        tokenInfo,
      ];
}

/// State when an error occurs
class FollowUpChatError extends FollowUpChatState {
  final String message;
  final String? code;

  const FollowUpChatError(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// State when insufficient tokens for follow-up
class FollowUpChatInsufficientTokens extends FollowUpChatState {
  final int required;
  final int available;
  final String userPlan;

  const FollowUpChatInsufficientTokens({
    required this.required,
    required this.available,
    required this.userPlan,
  });

  @override
  List<Object?> get props => [required, available, userPlan];
}

/// State when follow-up limit is exceeded for the plan
class FollowUpChatLimitExceeded extends FollowUpChatState {
  final int current;
  final int max;
  final String userPlan;
  final String message;

  const FollowUpChatLimitExceeded({
    required this.current,
    required this.max,
    required this.userPlan,
    required this.message,
  });

  @override
  List<Object?> get props => [current, max, userPlan, message];
}

/// State when follow-up feature is not available for user's plan
class FollowUpChatFeatureNotAvailable extends FollowUpChatState {
  final String userPlan;
  final String message;

  const FollowUpChatFeatureNotAvailable({
    required this.userPlan,
    required this.message,
  });

  @override
  List<Object?> get props => [userPlan, message];
}
