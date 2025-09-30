import '../../presentation/bloc/follow_up_chat_state.dart';

/// Response model for conversation history API
class ConversationHistoryResponse {
  final String conversationId;
  final String studyGuideId;
  final List<ChatMessage> messages;

  const ConversationHistoryResponse({
    required this.conversationId,
    required this.studyGuideId,
    required this.messages,
  });

  /// Creates an empty conversation response
  factory ConversationHistoryResponse.empty(String studyGuideId) {
    return ConversationHistoryResponse(
      conversationId: '',
      studyGuideId: studyGuideId,
      messages: [],
    );
  }

  /// Creates a response from JSON
  factory ConversationHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final messagesJson = data['messages'] as List<dynamic>? ?? [];

    final messages = messagesJson.map((messageJson) {
      final msg = messageJson as Map<String, dynamic>;

      return ChatMessage(
        id: msg['id'] as String,
        content: msg['content'] as String,
        isUser: (msg['role'] as String) == 'user',
        timestamp: DateTime.parse(msg['created_at'] as String),
        tokensConsumed: msg['tokens_consumed'] as int? ?? 0,
      );
    }).toList();

    return ConversationHistoryResponse(
      conversationId: data['conversation_id'] as String? ?? '',
      studyGuideId: data['study_guide_id'] as String? ?? '',
      messages: messages,
    );
  }

  /// Whether this is an empty conversation (no existing history)
  bool get isEmpty => conversationId.isEmpty || messages.isEmpty;
}
