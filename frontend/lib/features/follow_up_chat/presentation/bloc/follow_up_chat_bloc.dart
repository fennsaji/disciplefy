import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/http_service.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../data/services/conversation_service.dart';
import 'follow_up_chat_event.dart';
import 'follow_up_chat_state.dart';

import '../../../../core/utils/event_source_bridge.dart';

/// BLoC for managing follow-up chat conversations with streaming support
class FollowUpChatBloc extends Bloc<FollowUpChatEvent, FollowUpChatState> {
  final HttpService _httpService;
  final ConversationService _conversationService;
  final Uuid _uuid = const Uuid();

  StreamSubscription? _streamSubscription;

  FollowUpChatBloc({
    required HttpService httpService,
    required ConversationService conversationService,
  })  : _httpService = httpService,
        _conversationService = conversationService,
        super(const FollowUpChatInitial()) {
    on<StartConversationEvent>(_onStartConversation);
    on<SendQuestionEvent>(_onSendQuestion);
    on<StreamingChunkReceivedEvent>(_onStreamingChunkReceived);
    on<StreamingCompleteEvent>(_onStreamingComplete);
    on<StreamingErrorEvent>(_onStreamingError);
    on<LoadConversationHistoryEvent>(_onLoadConversationHistory);
    on<ClearConversationEvent>(_onClearConversation);
    on<RetryMessageEvent>(_onRetryMessage);
    on<CancelRequestEvent>(_onCancelRequest);
  }

  @override
  Future<void> close() {
    _cleanupStream();
    return super.close();
  }

  /// Handles starting a new conversation or loading existing one
  Future<void> _onStartConversation(
    StartConversationEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    print(
        '[FollowUpChat] 🚀 Starting conversation for study guide: ${event.studyGuideId}');
    print('[FollowUpChat] 📝 Study guide title: ${event.studyGuideTitle}');

    emit(const FollowUpChatLoading());
    print('[FollowUpChat] ⏳ Emitted FollowUpChatLoading state');

    try {
      // Try to load existing conversation history
      print('[FollowUpChat] 🔍 Loading existing conversation history...');
      final conversationHistory = await _conversationService
          .loadConversationHistory(event.studyGuideId);

      String conversationId;
      List<ChatMessage> messages;

      if (conversationHistory.isEmpty) {
        // No existing conversation - create new one
        conversationId = _uuid.v4();
        messages = [];
        print(
            '[FollowUpChat] 🆕 No existing conversation found, created new ID: $conversationId');
      } else {
        // Load existing conversation
        conversationId = conversationHistory.conversationId;
        messages = conversationHistory.messages;
        print(
            '[FollowUpChat] 📥 Loaded existing conversation: $conversationId with ${messages.length} messages');
      }

      final loadedState = FollowUpChatLoaded(
        studyGuideId: event.studyGuideId,
        studyGuideTitle: event.studyGuideTitle,
        conversationId: conversationId,
        messages: messages,
      );

      emit(loadedState);
      print('[FollowUpChat] ✅ Emitted FollowUpChatLoaded state successfully');
      print(
          '[FollowUpChat] 📊 Loaded state details: studyGuideId=${loadedState.studyGuideId}, conversationId=${loadedState.conversationId}, messageCount=${messages.length}');
    } catch (e) {
      print('[FollowUpChat] ❌ Error starting conversation: ${e.toString()}');
      emit(FollowUpChatError('Failed to start conversation: ${e.toString()}'));
    }
  }

  /// Handles sending a question with streaming support
  Future<void> _onSendQuestion(
    SendQuestionEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    print('[FollowUpChat] 🚀 Sending question: ${event.question}');
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) {
      print('[FollowUpChat] ❌ No active conversation');
      emit(const FollowUpChatError('No active conversation'));
      return;
    }
    print('[FollowUpChat] ✅ Current state is loaded, proceeding...');

    // Add user message immediately
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: event.question,
      isUser: true,
      timestamp: DateTime.now(),
      tokensConsumed: 5, // Fixed cost for follow-up questions
    );

    // Update state with user message first
    final stateWithUserMessage = currentState.addMessage(userMessage).copyWith(
          isProcessing: true,
        );
    emit(stateWithUserMessage);

    try {
      // Create placeholder assistant message for streaming
      final assistantMessage = ChatMessage(
        id: _uuid.v4(),
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.streaming,
      );

      // Update state with both messages and streaming info
      emit(stateWithUserMessage.addMessage(assistantMessage).copyWith(
            isProcessing: true,
            currentStreamingMessageId: assistantMessage.id,
          ));

      // Start streaming request
      await _startStreamingRequest(
        currentState.studyGuideId,
        event.question,
        assistantMessage.id,
        emit,
      );
    } catch (e) {
      emit(stateWithUserMessage.copyWith(
        isProcessing: false,
        error: 'Failed to send question: ${e.toString()}',
      ));
    }
  }

  /// Starts a streaming request to the backend
  Future<void> _startStreamingRequest(
    String studyGuideId,
    String question,
    String assistantMessageId,
    Emitter<FollowUpChatState> emit,
  ) async {
    try {
      // Clean up any existing stream
      _cleanupStream();

      // Get authentication headers
      final headers = await ApiAuthHelper.getAuthHeaders();
      const baseUrl = AppConfig.supabaseUrl;

      // Check if browser supports EventSource (only on web)
      // Note: We assume EventSource is supported on modern web browsers
      const supportsEventSource = kIsWeb;

      if (supportsEventSource) {
        await _startEventSourceStream(
          baseUrl,
          studyGuideId,
          question,
          headers,
          assistantMessageId,
          emit,
        );
      } else {
        // Fallback to regular HTTP request
        await _fallbackHttpRequest(
          baseUrl,
          studyGuideId,
          question,
          headers,
          assistantMessageId,
          emit,
        );
      }
    } catch (e) {
      add(StreamingErrorEvent('Failed to start streaming: ${e.toString()}'));
    }
  }

  /// Starts EventSource streaming
  Future<void> _startEventSourceStream(
    String baseUrl,
    String studyGuideId,
    String question,
    Map<String, String> headers,
    String assistantMessageId,
    Emitter<FollowUpChatState> emit,
  ) async {
    try {
      // Extract all required authentication parameters from headers
      String? authToken;
      String? apiKey;
      String? sessionId;

      if (headers.containsKey('Authorization')) {
        final authHeader = headers['Authorization']!;
        if (authHeader.startsWith('Bearer ')) {
          authToken = authHeader.substring(7); // Remove 'Bearer ' prefix
        }
      }

      if (headers.containsKey('apikey')) {
        apiKey = headers['apikey'];
      }

      if (headers.containsKey('x-session-id')) {
        sessionId = headers['x-session-id'];
      }

      // Create URL with query parameters for GET request, including all auth parameters
      final queryParams = <String, String>{
        'study_guide_id': studyGuideId,
        'question': question,
      };

      // Add authentication parameters to query (since EventSource can't send headers)
      if (authToken != null) {
        queryParams['authorization'] = authToken;
        print('[FollowUpChat] 🔐 Added auth token to query parameters');
      }

      if (apiKey != null) {
        queryParams['apikey'] = apiKey;
        print('[FollowUpChat] 🔑 Added API key to query parameters');
      }

      if (sessionId != null) {
        queryParams['x-session-id'] = sessionId;
        print('[FollowUpChat] 🆔 Added session ID to query parameters');
      }

      if (authToken == null && apiKey == null) {
        print('[FollowUpChat] ⚠️ No authentication found - request may fail');
      }

      // Create URI with query parameters
      final uri = Uri.parse('$baseUrl/functions/v1/study-followup').replace(
        queryParameters: queryParams,
      );

      print('[FollowUpChat] 🌐 EventSource URL: ${uri.toString()}');

      // Create EventSource connection with fetch-event-source bridge
      final stream = EventSourceBridge.connect(
        url: uri.toString(),
        headers: headers,
      );

      _streamSubscription = stream.listen(
        (String data) {
          try {
            final jsonData = json.decode(data);
            _handleStreamingData(jsonData, assistantMessageId);
          } catch (e) {
            print('[FollowUpChat] Error parsing streaming data: $e');
          }
        },
        onError: (error) {
          print('[FollowUpChat] EventSource error: $error');

          // Check if it's a token limit error (429)
          if (error.toString().contains('TOKEN_LIMIT_EXCEEDED')) {
            // Try to parse JSON error details
            try {
              final errorData = json.decode(error.toString());
              if (errorData['error'] == 'TOKEN_LIMIT_EXCEEDED') {
                add(StreamingErrorEvent(
                    'TOKEN_LIMIT_EXCEEDED: ${errorData['message']}'));
                return;
              }
            } catch (e) {
              // Not JSON, use generic message
            }
            add(const StreamingErrorEvent('TOKEN_LIMIT_EXCEEDED'));
          } else if (error.toString().contains('FEATURE_NOT_AVAILABLE')) {
            // Feature not available for plan (403)
            try {
              final errorData = json.decode(error.toString());
              add(StreamingErrorEvent(
                  'FEATURE_NOT_AVAILABLE:${json.encode(errorData)}'));
              return;
            } catch (e) {
              // Not JSON, use generic message
            }
            add(const StreamingErrorEvent('FEATURE_NOT_AVAILABLE'));
          } else if (error.toString().contains('FOLLOW_UP_LIMIT_EXCEEDED')) {
            // Follow-up limit reached (403)
            try {
              final errorData = json.decode(error.toString());
              add(StreamingErrorEvent(
                  'FOLLOW_UP_LIMIT_EXCEEDED:${json.encode(errorData)}'));
              return;
            } catch (e) {
              // Not JSON, use generic message
            }
            add(const StreamingErrorEvent('FOLLOW_UP_LIMIT_EXCEEDED'));
          } else {
            add(const StreamingErrorEvent('Streaming connection error'));
          }
        },
        onDone: () {
          print('[FollowUpChat] EventSource connection closed');
        },
      );
    } catch (e) {
      throw Exception('Failed to create EventSource: $e');
    }
  }

  /// Fallback HTTP request for non-streaming browsers or mobile
  Future<void> _fallbackHttpRequest(
    String baseUrl,
    String studyGuideId,
    String question,
    Map<String, String> headers,
    String assistantMessageId,
    Emitter<FollowUpChatState> emit,
  ) async {
    try {
      final response = await _httpService.post(
        '$baseUrl/functions/v1/study-followup',
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'study_guide_id': studyGuideId,
          'question': question,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseText = data['data']['response'] as String;
        final messageId = data['data']['message_id'] as String;

        // Simulate streaming by adding chunks
        final chunks = _chunkText(responseText, 50);
        for (final chunk in chunks) {
          add(StreamingChunkReceivedEvent(chunk));
          await Future.delayed(const Duration(milliseconds: 100));
        }

        add(StreamingCompleteEvent(messageId));
      } else {
        add(StreamingErrorEvent(
            'HTTP ${response.statusCode}: ${response.body}'));
      }
    } catch (e) {
      add(StreamingErrorEvent('HTTP request failed: ${e.toString()}'));
    }
  }

  /// Handles streaming data from EventSource
  void _handleStreamingData(
      Map<String, dynamic> data, String assistantMessageId) {
    final type = data['type'] as String?;

    switch (type) {
      case 'connection':
        print('[FollowUpChat] Connection established');
        break;
      case 'content':
        final content = data['content'] as String?;
        if (content != null) {
          add(StreamingChunkReceivedEvent(content));
        }
        break;
      case 'complete':
        final messageId = data['message_id'] as String?;
        add(StreamingCompleteEvent(messageId ?? assistantMessageId));
        break;
      case 'error':
        final error = data['error'] as String?;
        add(StreamingErrorEvent(error ?? 'Unknown streaming error'));
        break;
    }
  }

  /// Handles receiving streaming chunks
  Future<void> _onStreamingChunkReceived(
    StreamingChunkReceivedEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) return;

    final streamingMessage = currentState.currentStreamingMessage;
    if (streamingMessage == null) return;

    // Append chunk to the streaming message
    final updatedMessage = streamingMessage.copyWith(
      content: streamingMessage.content + event.chunk,
    );

    emit(currentState.updateMessage(streamingMessage.id, updatedMessage));
  }

  /// Handles streaming completion
  Future<void> _onStreamingComplete(
    StreamingCompleteEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) return;

    final streamingMessage = currentState.currentStreamingMessage;
    if (streamingMessage == null) return;

    // Mark message as complete
    final updatedMessage = streamingMessage.copyWith(
      status: ChatMessageStatus.sent,
    );

    emit(currentState
        .updateMessage(streamingMessage.id, updatedMessage)
        .copyWith(
          isProcessing: false,
          clearStreamingMessage: true,
        ));

    _cleanupStream();
  }

  /// Handles streaming errors
  Future<void> _onStreamingError(
    StreamingErrorEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) return;

    // Check if it's a feature not available error
    if (event.error.contains('FEATURE_NOT_AVAILABLE')) {
      _cleanupStream();

      // Remove the streaming message since it failed
      final streamingMessage = currentState.currentStreamingMessage;
      List<ChatMessage> updatedMessages = currentState.messages;
      if (streamingMessage != null) {
        updatedMessages = currentState.messages
            .where((msg) => msg.id != streamingMessage.id)
            .toList();
      }

      // Parse error details
      try {
        final errorDataStr = event.error.split('FEATURE_NOT_AVAILABLE:')[1];
        final errorData = json.decode(errorDataStr);

        emit(FollowUpChatFeatureNotAvailable(
          userPlan: errorData['plan'] ?? 'free',
          message: errorData['message'] ??
              'Follow-up questions are not available for your plan',
        ));
      } catch (e) {
        // Fallback if parsing fails
        emit(const FollowUpChatFeatureNotAvailable(
          userPlan: 'free',
          message: 'Follow-up questions are not available for free plan',
        ));
      }
      return;
    }

    // Check if it's a follow-up limit exceeded error
    if (event.error.contains('FOLLOW_UP_LIMIT_EXCEEDED')) {
      _cleanupStream();

      // Remove the streaming message since it failed
      final streamingMessage = currentState.currentStreamingMessage;
      List<ChatMessage> updatedMessages = currentState.messages;
      if (streamingMessage != null) {
        updatedMessages = currentState.messages
            .where((msg) => msg.id != streamingMessage.id)
            .toList();
      }

      // Parse error details
      try {
        final errorDataStr = event.error.split('FOLLOW_UP_LIMIT_EXCEEDED:')[1];
        final errorData = json.decode(errorDataStr);

        emit(FollowUpChatLimitExceeded(
          current: errorData['current'] ?? 0,
          max: errorData['max'] ?? 3,
          userPlan: errorData['plan'] ?? 'free',
          message: errorData['message'] ?? 'Follow-up limit exceeded',
        ));
      } catch (e) {
        // Fallback if parsing fails
        emit(const FollowUpChatLimitExceeded(
          current: 0,
          max: 3,
          userPlan: 'free',
          message: 'You have reached the follow-up limit for your plan',
        ));
      }
      return;
    }

    // Check if it's a token limit exceeded error
    if (event.error.contains('TOKEN_LIMIT_EXCEEDED')) {
      _cleanupStream();

      // Remove the streaming message since it failed
      final streamingMessage = currentState.currentStreamingMessage;
      List<ChatMessage> updatedMessages = currentState.messages;
      if (streamingMessage != null) {
        updatedMessages = currentState.messages
            .where((msg) => msg.id != streamingMessage.id)
            .toList();
      }

      // Emit insufficient tokens state
      emit(FollowUpChatInsufficientTokens(
        required: 5, // Fixed cost for follow-up
        available: 0, // We don't know the exact amount
        userPlan: 'standard',
      ));
      return;
    }

    final streamingMessage = currentState.currentStreamingMessage;
    if (streamingMessage != null) {
      // Mark message as failed
      final updatedMessage = streamingMessage.copyWith(
        status: ChatMessageStatus.failed,
      );

      emit(currentState.updateMessage(streamingMessage.id, updatedMessage));
    }

    emit(currentState.copyWith(
      isProcessing: false,
      error: event.error,
      clearStreamingMessage: true,
    ));

    _cleanupStream();
  }

  /// Loads conversation history (placeholder)
  Future<void> _onLoadConversationHistory(
    LoadConversationHistoryEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    // TODO: Implement loading conversation history from backend
    // This would fetch existing messages for the conversation
  }

  /// Clears the current conversation
  Future<void> _onClearConversation(
    ClearConversationEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    _cleanupStream();
    emit(const FollowUpChatInitial());
  }

  /// Retries a failed message
  Future<void> _onRetryMessage(
    RetryMessageEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) return;

    // Find the failed message and retry
    final failedMessage = currentState.messages
        .where((msg) =>
            msg.id == event.messageId && msg.status == ChatMessageStatus.failed)
        .firstOrNull;

    if (failedMessage != null && failedMessage.isUser) {
      // Remove the failed assistant response and retry
      final messages = currentState.messages
          .where((msg) => !(msg.id == event.messageId ||
              (msg.timestamp.isAfter(failedMessage.timestamp) && !msg.isUser)))
          .toList();

      emit(currentState.copyWith(messages: messages));

      // Retry the question
      add(SendQuestionEvent(
        question: failedMessage.content,
      ));
    }
  }

  /// Cancels an ongoing request
  Future<void> _onCancelRequest(
    CancelRequestEvent event,
    Emitter<FollowUpChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FollowUpChatLoaded) return;

    _cleanupStream();

    final streamingMessage = currentState.currentStreamingMessage;
    if (streamingMessage != null) {
      final updatedMessage = streamingMessage.copyWith(
        status: ChatMessageStatus.cancelled,
      );

      emit(currentState
          .updateMessage(streamingMessage.id, updatedMessage)
          .copyWith(
            isProcessing: false,
            clearStreamingMessage: true,
          ));
    } else {
      emit(currentState.copyWith(isProcessing: false));
    }
  }

  /// Cleans up streaming resources
  void _cleanupStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    EventSourceBridge.closeAll();
  }

  /// Chunks text for simulated streaming
  List<String> _chunkText(String text, int chunkSize) {
    final chunks = <String>[];
    for (int i = 0; i < text.length; i += chunkSize) {
      chunks.add(text.substring(i, (i + chunkSize).clamp(0, text.length)));
    }
    return chunks;
  }
}
