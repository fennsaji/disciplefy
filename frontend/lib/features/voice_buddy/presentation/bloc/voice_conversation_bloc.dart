import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../../../core/utils/event_source_bridge.dart';
import '../../data/services/speech_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/vad_service.dart';
import '../../domain/entities/voice_conversation_entity.dart';
import '../../domain/repositories/voice_buddy_repository.dart';
import 'voice_conversation_event.dart';
import 'voice_conversation_state.dart';

/// BLoC for managing voice conversations.
class VoiceConversationBloc
    extends Bloc<VoiceConversationEvent, VoiceConversationState> {
  final VoiceBuddyRepository _repository;
  final SpeechService _speechService;
  final TTSService _ttsService;
  final SupabaseClient _supabaseClient;

  /// Voice Activity Detection service for intelligent silence detection
  late final VADService _vadService;

  StreamSubscription? _speechSubscription;
  StreamSubscription? _streamSubscription;

  /// Current transcription text and confidence for VAD
  String _currentTranscription = '';
  double _currentConfidence = 0.0;

  /// Timer for detecting silence after speech (3 seconds)
  Timer? _silenceAfterSpeechTimer;

  /// Whether user has started speaking in current session
  bool _hasStartedSpeaking = false;

  /// Buffer for accumulating text chunks during streaming TTS
  String _streamingSentenceBuffer = '';

  /// Whether streaming TTS session has been started
  bool _streamingTTSStarted = false;

  VoiceConversationBloc({
    required VoiceBuddyRepository repository,
    required SpeechService speechService,
    required TTSService ttsService,
    required SupabaseClient supabaseClient,
    VADConfig? vadConfig,
  })  : _repository = repository,
        _speechService = speechService,
        _ttsService = ttsService,
        _supabaseClient = supabaseClient,
        super(const VoiceConversationState()) {
    // Initialize VAD service with configuration
    _vadService = (vadConfig ?? VADConfig.defaultConfig).createService();
    _vadService.onSilenceDetected = _onVADSilenceDetected;
    _vadService.onStateChanged = _onVADStateChanged;

    on<StartConversation>(_onStartConversation);
    on<EndConversation>(_onEndConversation);
    on<StartListening>(_onStartListening);
    on<StopListening>(_onStopListening);
    on<ProcessSpeechText>(_onProcessSpeechText);
    on<SendTextMessage>(_onSendTextMessage);
    on<ReceiveStreamChunk>(_onReceiveStreamChunk);
    on<StreamCompleted>(_onStreamCompleted);
    on<StreamError>(_onStreamError);
    on<PlayResponse>(_onPlayResponse);
    on<StopPlayback>(_onStopPlayback);
    on<CheckQuota>(_onCheckQuota);
    on<LoadPreferences>(_onLoadPreferences);
    on<LoadConversationHistory>(_onLoadHistory);
    on<LoadConversation>(_onLoadConversation);
    on<ToggleContinuousMode>(_onToggleContinuousMode);
    on<ChangeLanguage>(_onChangeLanguage);
    on<PlaybackCompleted>(_onPlaybackCompleted);
    on<SpeechStatusChanged>(_onSpeechStatusChanged);
  }

  /// Called by VAD service when silence is detected (ready to auto-send)
  void _onVADSilenceDetected(String text, double confidence) {
    if (!state.isContinuousMode) return;
    if (!state.isListening) return;
    if (text.isEmpty) return;

    print('🎙️ [VAD] Silence detected - auto-sending message');
    print(
        '  - Text: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"');
    print('  - Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

    add(const StopListening());
    add(SendTextMessage(text));
  }

  /// Called by VAD service when state changes
  void _onVADStateChanged(VADState vadState) {
    // Log VAD state changes for debugging
    switch (vadState) {
      case VADState.calibrating:
        print('🎙️ [VAD] Calibrating ambient noise...');
        break;
      case VADState.listening:
        print('🎙️ [VAD] Ready - listening for speech');
        break;
      case VADState.speaking:
        // Don't log every speaking state change (too noisy)
        break;
      case VADState.silenceDetected:
        print('🎙️ [VAD] Silence detected');
        break;
      case VADState.stopped:
        print('🎙️ [VAD] Stopped');
        break;
    }
  }

  Future<void> _onLoadPreferences(
    LoadPreferences event,
    Emitter<VoiceConversationState> emit,
  ) async {
    final result = await _repository.getPreferences();

    result.fold(
      (failure) {
        // On failure, keep default language (en-US)
        print('Failed to load preferences: ${failure.message}');
      },
      (preferences) {
        emit(state.copyWith(
          languageCode: preferences.preferredLanguage,
          isContinuousMode: preferences.continuousMode,
          showTranscription: preferences.showTranscription,
          autoPlayResponse: preferences.autoPlayResponse,
          autoDetectLanguage: preferences.autoDetectLanguage,
          notifyDailyQuotaReached: preferences.notifyDailyQuotaReached,
        ));
      },
    );
  }

  Future<void> _onStartConversation(
    StartConversation event,
    Emitter<VoiceConversationState> emit,
  ) async {
    emit(state.copyWith(status: VoiceConversationStatus.loading));

    // Check quota first
    final quotaResult = await _repository.checkQuota();

    final quota = quotaResult.fold(
      (failure) => null,
      (quota) => quota,
    );

    if (quota != null && !quota.canStart) {
      emit(state.copyWith(
        status: VoiceConversationStatus.quotaExceeded,
        quota: quota,
        errorMessage: 'Daily voice conversation quota exceeded',
      ));
      return;
    }

    // Start conversation
    final result = await _repository.startConversation(
      languageCode: event.languageCode,
      conversationType: event.conversationType,
      relatedStudyGuideId: event.relatedStudyGuideId,
      relatedScripture: event.relatedScripture,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: VoiceConversationStatus.error,
        errorMessage: failure.message,
      )),
      (conversation) => emit(state.copyWith(
        status: VoiceConversationStatus.ready,
        conversation: conversation,
        messages: [],
        languageCode: event.languageCode,
        quota: quota,
      )),
    );
  }

  Future<void> _onEndConversation(
    EndConversation event,
    Emitter<VoiceConversationState> emit,
  ) async {
    if (state.conversation == null) return;

    emit(state.copyWith(status: VoiceConversationStatus.loading));

    // Stop any ongoing activities
    await _speechService.stopListening();
    await _ttsService.stop();

    final result = await _repository.endConversation(
      conversationId: state.conversation!.id,
      rating: event.rating,
      feedbackText: event.feedbackText,
      wasHelpful: event.wasHelpful,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: VoiceConversationStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(const VoiceConversationState()),
    );
  }

  Future<void> _onStartListening(
    StartListening event,
    Emitter<VoiceConversationState> emit,
  ) async {
    if (!state.hasActiveConversation) return;

    // Stop any ongoing TTS playback when user starts speaking
    if (state.isPlaying || _streamingTTSStarted) {
      print('🎙️ [VOICE] User started speaking - stopping TTS playback');
      _playbackFallbackTimer?.cancel();
      _playbackFallbackTimer = null;
      if (_streamingTTSStarted) {
        await _ttsService.cancelStreaming();
        _streamingTTSStarted = false;
        _streamingSentenceBuffer = '';
      } else {
        await _ttsService.stop();
      }
    }

    emit(state.copyWith(
      status: VoiceConversationStatus.listening,
      isListening: true,
      isPlaying: false,
      clearCurrentTranscription:
          true, // Clear old transcription when starting fresh
    ));

    // Initialize speech service if needed
    final available = await _speechService.initialize();
    if (!available) {
      emit(state.copyWith(
        status: VoiceConversationStatus.error,
        isListening: false,
        errorMessage: 'Speech recognition not available',
      ));
      return;
    }

    // Reset transcription tracking
    _currentTranscription = '';
    _currentConfidence = 0.0;
    _hasStartedSpeaking = false;
    _silenceAfterSpeechTimer?.cancel();
    _silenceAfterSpeechTimer = null;

    // Start VAD in continuous mode (with calibration on first start)
    if (state.isContinuousMode) {
      _vadService.start();
    }

    // Start listening
    _speechSubscription?.cancel();

    // Capture continuous mode state for the callback
    final isContinuousMode = state.isContinuousMode;

    try {
      await _speechService.startListening(
        languageCode: state.languageCode,
        // Defaults: listenFor=60s, pauseFor=60s
        // 3-second silence detection is handled by _silenceAfterSpeechTimer
        onResult: (result) {
          final text = result.recognizedWords;
          final confidence = result.confidence;

          // Update tracking variables
          _currentTranscription = text;
          _currentConfidence = confidence;

          add(ProcessSpeechText(text: text, confidence: confidence));

          // Feed transcription to VAD for debounced silence detection
          if (isContinuousMode) {
            _vadService.processTranscription(
                text, confidence, result.finalResult);
          }

          // Simplified 3-second silence detection for continuous mode
          if (isContinuousMode && text.isNotEmpty && !result.finalResult) {
            _hasStartedSpeaking = true;

            // Cancel existing timer and start new 3-second timer
            _silenceAfterSpeechTimer?.cancel();
            _silenceAfterSpeechTimer = Timer(const Duration(seconds: 3), () {
              // After 3 seconds of no new transcription, send the message
              if (_hasStartedSpeaking && _currentTranscription.isNotEmpty) {
                print(
                    '🎙️ [VOICE] 3-second silence detected - sending message');
                print(
                    '  - Text: "${_currentTranscription.length > 50 ? '${_currentTranscription.substring(0, 50)}...' : _currentTranscription}"');
                add(const StopListening());
                add(SendTextMessage(_currentTranscription));
              }
            });
          }

          // Handle finalResult - send message in both modes
          if (result.finalResult && text.isNotEmpty) {
            // Cancel silence timer since we're sending via finalResult
            _silenceAfterSpeechTimer?.cancel();
            _silenceAfterSpeechTimer = null;

            if (isContinuousMode) {
              // In continuous mode, send message but don't stop listening
              // VAD might have already sent via silence detection, but that's ok
              // as SendTextMessage checks for empty/duplicate
              print(
                  '🎙️ [VOICE] FinalResult in continuous mode - sending message');
              add(SendTextMessage(text));
            } else {
              // In normal mode, stop listening and send
              add(const StopListening());
              add(SendTextMessage(text));
            }
          }
        },
        onSoundLevelChange: (level) {
          // Feed sound levels to VAD for audio-based silence detection
          if (isContinuousMode) {
            _vadService.processSoundLevel(level);
          }
        },
        onStatusChange: (status) {
          // Handle speech recognition status changes
          add(SpeechStatusChanged(status));
        },
      );
    } catch (e) {
      add(StreamError(e.toString()));
    }
  }

  Future<void> _onStopListening(
    StopListening event,
    Emitter<VoiceConversationState> emit,
  ) async {
    // Stop VAD service
    _vadService.stop();

    // Cancel silence timer
    _silenceAfterSpeechTimer?.cancel();
    _silenceAfterSpeechTimer = null;
    _hasStartedSpeaking = false;

    await _speechService.stopListening();
    _speechSubscription?.cancel();

    emit(state.copyWith(
      isListening: false,
      status: state.hasActiveConversation
          ? VoiceConversationStatus.ready
          : state.status,
    ));
  }

  void _onProcessSpeechText(
    ProcessSpeechText event,
    Emitter<VoiceConversationState> emit,
  ) {
    emit(state.copyWith(currentTranscription: event.text));
    // Note: In continuous mode, VAD service handles silence detection via
    // processTranscription() called in _onStartListening's onResult callback
  }

  Future<void> _onSendTextMessage(
    SendTextMessage event,
    Emitter<VoiceConversationState> emit,
  ) async {
    if (!state.hasActiveConversation || event.message.isEmpty) return;

    // Prevent duplicate submissions if already processing/streaming
    if (state.status == VoiceConversationStatus.processing ||
        state.status == VoiceConversationStatus.streaming) {
      print(
          '🎙️ [VOICE] Ignoring duplicate SendTextMessage - already processing');
      return;
    }

    // Clear transcription and reset internal tracking
    _currentTranscription = '';
    _currentConfidence = 0.0;

    emit(state.copyWith(
      status: VoiceConversationStatus.processing,
      streamingResponse: '',
      clearCurrentTranscription: true, // Clear the displayed transcription
    ));

    // Add user message to local state
    final userMessage = ConversationMessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: state.conversation!.id,
      userId: _supabaseClient.auth.currentUser?.id ?? '',
      messageOrder: state.messages.length,
      role: MessageRole.user,
      contentText: event.message,
      contentLanguage: state.languageCode,
      createdAt: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, userMessage],
    ));

    // Stream response from edge function
    await _streamResponse(emit, event.message);
  }

  Future<void> _streamResponse(
    Emitter<VoiceConversationState> emit,
    String message,
  ) async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        emit(state.copyWith(
          status: VoiceConversationStatus.error,
          errorMessage: 'Not authenticated',
        ));
        return;
      }

      emit(state.copyWith(status: VoiceConversationStatus.streaming));

      // Get the access token for authentication
      final session = _supabaseClient.auth.currentSession;
      if (session == null) {
        emit(state.copyWith(
          status: VoiceConversationStatus.error,
          errorMessage: 'No active session',
        ));
        return;
      }

      // Check if we're on web and can use EventSource for true streaming
      const supportsEventSource = kIsWeb;

      if (supportsEventSource) {
        await _startEventSourceStream(message);
      } else {
        // Fallback to regular HTTP request for mobile
        await _fallbackHttpRequest(message);
      }
    } catch (e) {
      add(StreamError(e.toString()));
    }
  }

  /// Start true SSE streaming using EventSourceBridge (web only)
  Future<void> _startEventSourceStream(String message) async {
    try {
      // Clean up any existing stream
      _cleanupStream();

      // Get authentication headers (sent via EventSourceBridge, not in URL)
      final headers = await ApiAuthHelper.getAuthHeaders();
      const baseUrl = AppConfig.supabaseUrl;

      // Create URL with query parameters for GET request
      // Note: Authentication is handled via headers in EventSourceBridge.connect()
      // Do NOT include credentials in query params (insecure, redundant)
      final queryParams = <String, String>{
        'conversation_id': state.conversation!.id,
        'message': message,
        'language_code': state.languageCode,
      };

      // Create URI with query parameters
      final uri = Uri.parse('$baseUrl/functions/v1/voice-conversation').replace(
        queryParameters: queryParams,
      );

      print(
          '🎙️ [VOICE] Starting EventSource stream to: ${uri.toString().substring(0, 100)}...');

      // Create EventSource connection
      final stream = EventSourceBridge.connect(
        url: uri.toString(),
        headers: headers,
      );

      _streamSubscription = stream.listen(
        (String data) {
          try {
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            _handleStreamingEvent(jsonData);
          } catch (e) {
            print('🎙️ [VOICE] Error parsing streaming data: $e');
          }
        },
        onError: (error) {
          print('🎙️ [VOICE] EventSource error: $error');

          if (error.toString().contains('QUOTA_EXCEEDED')) {
            add(const StreamError('Daily voice conversation quota exceeded'));
          } else if (error.toString().contains('CONVERSATION_LIMIT_EXCEEDED')) {
            add(const StreamError(
                'Conversation message limit reached. Please start a new conversation.'));
          } else {
            add(StreamError('Streaming connection error: $error'));
          }
        },
        onDone: () {
          print('🎙️ [VOICE] EventSource connection closed');
        },
      );
    } catch (e) {
      add(StreamError('Failed to start streaming: $e'));
    }
  }

  /// Handle individual streaming events from the backend
  void _handleStreamingEvent(Map<String, dynamic> data) {
    // The backend sends event type as a separate SSE field, but our bridge
    // combines the JSON data. Check for known event patterns.

    // Check for error events
    if (data.containsKey('code')) {
      final code = data['code'] as String?;
      final message = data['message'] as String? ?? 'Unknown error';

      if (code == 'UNAUTHORIZED') {
        add(StreamError('Authentication required: $message'));
        return;
      } else if (code == 'SERVER_ERROR') {
        add(StreamError(message));
        return;
      }
    }

    // Check for quota_exceeded event
    if (data.containsKey('limit') &&
        data.containsKey('tier') &&
        !data.containsKey('remaining')) {
      final message = data['message'] as String? ?? 'Quota exceeded';
      add(StreamError(message));
      return;
    }

    // Check for content event (streaming chunk)
    if (data.containsKey('text')) {
      final text = data['text'] as String? ?? '';
      if (text.isNotEmpty) {
        add(ReceiveStreamChunk(text));
      }
      return;
    }

    // Check for stream_end event
    if (data.containsKey('scripture_references')) {
      final refs = (data['scripture_references'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      add(StreamCompleted(scriptureReferences: refs));
      _cleanupStream();
      return;
    }

    // Check for quota_status event (informational, can ignore)
    if (data.containsKey('remaining') && data.containsKey('limit')) {
      print('🎙️ [VOICE] Quota status: ${data['remaining']}/${data['limit']}');
      return;
    }

    // Check for stream_start event (informational)
    if (data.containsKey('timestamp') &&
        !data.containsKey('scripture_references')) {
      print('🎙️ [VOICE] Stream started');
      return;
    }

    // Check for conversation_limit_exceeded
    if (data.containsKey('messageCount') && data.containsKey('limit')) {
      final message =
          data['message'] as String? ?? 'Conversation message limit reached';
      add(StreamError(message));
      return;
    }
  }

  /// Fallback HTTP request for mobile platforms (non-streaming)
  Future<void> _fallbackHttpRequest(String message) async {
    try {
      // Use Supabase functions to call edge function
      final response = await _supabaseClient.functions.invoke(
        'voice-conversation',
        body: {
          'conversation_id': state.conversation!.id,
          'message': message,
          'language_code': state.languageCode,
        },
      );

      // Handle different response types
      String responseText = '';
      if (response.data is String) {
        responseText = response.data as String;
      } else if (response.data != null) {
        try {
          final bytes = await response.data.toBytes();
          responseText = utf8.decode(bytes);
        } catch (e) {
          responseText = response.data.toString();
        }
      }

      print('🎙️ [VOICE] Raw response: $responseText');

      // Parse SSE events from response text
      String fullContent = '';
      List<String> scriptureRefs = [];

      final events = responseText.split('\n\n');
      for (final event in events) {
        if (event.trim().isEmpty) continue;

        String? eventType;
        String? data;

        for (final line in event.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7);
          } else if (line.startsWith('data: ')) {
            data = line.substring(6);
          }
        }

        if (data != null) {
          try {
            final jsonData = jsonDecode(data) as Map<String, dynamic>;

            switch (eventType) {
              case 'content':
                final text = jsonData['text'] as String? ?? '';
                fullContent += text;
                break;
              case 'stream_end':
                scriptureRefs = (jsonData['scripture_references'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];
                break;
              case 'error':
                final errorMsg =
                    jsonData['message'] as String? ?? 'Unknown error';
                add(StreamError(errorMsg));
                return;
              case 'quota_exceeded':
                final errorMsg =
                    jsonData['message'] as String? ?? 'Quota exceeded';
                add(StreamError(errorMsg));
                return;
            }
          } catch (e) {
            print('Error parsing SSE data: $e');
          }
        }
      }

      // Send the full content as a single chunk
      if (fullContent.isNotEmpty) {
        add(ReceiveStreamChunk(fullContent));
        add(StreamCompleted(scriptureReferences: scriptureRefs));
      } else {
        add(StreamError('No response received'));
      }
    } catch (e) {
      add(StreamError(e.toString()));
    }
  }

  /// Cleans up streaming resources
  void _cleanupStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    EventSourceBridge.closeAll();
  }

  void _onReceiveStreamChunk(
    ReceiveStreamChunk event,
    Emitter<VoiceConversationState> emit,
  ) {
    // Check if we need to start streaming TTS with this chunk
    final shouldStartTTS = state.autoPlayResponse && !_streamingTTSStarted;

    if (shouldStartTTS) {
      // For the first chunk, combine streamingResponse AND isPlaying in one emit
      // This ensures the UI shows the speaking animation immediately
      emit(state.copyWith(
        streamingResponse: state.streamingResponse + event.chunk,
        isPlaying: true,
      ));
      _startStreamingTTS(emit);
    } else {
      // For subsequent chunks, just update the streaming response
      emit(state.copyWith(
        streamingResponse: state.streamingResponse + event.chunk,
      ));
    }

    // Only process TTS if streaming was started
    if (_streamingTTSStarted) {
      _processChunkForTTS(event.chunk);
    }
  }

  /// Start streaming TTS session with the current language
  void _startStreamingTTS(Emitter<VoiceConversationState> emit) {
    if (_streamingTTSStarted) return;

    _streamingTTSStarted = true;
    _streamingSentenceBuffer = '';

    // Capture continuous mode state for the callback
    final shouldContinueListening = state.isContinuousMode;

    print('🎙️ [VOICE] Starting streaming TTS session');

    // Note: isPlaying is already set to true in _onReceiveStreamChunk
    // to ensure both streamingResponse and isPlaying are emitted together

    _ttsService.startStreamingSession(
      languageCode: state.languageCode,
      onComplete: () {
        print(
            '🎙️ [VOICE] Streaming TTS complete, shouldContinueListening: $shouldContinueListening');
        add(PlaybackCompleted(
            shouldContinueListening: shouldContinueListening));
      },
    );
  }

  /// Process incoming text chunk for TTS - detect and queue complete sentences
  void _processChunkForTTS(String chunk) {
    // Add chunk to buffer
    _streamingSentenceBuffer += chunk;

    // Define sentence-ending punctuation patterns
    // Match: sentence-ending punctuation followed by space or end of text
    final sentencePattern = RegExp(r'([.!?।॥]+)\s+');

    // Find all sentence boundaries
    while (true) {
      final match = sentencePattern.firstMatch(_streamingSentenceBuffer);
      if (match == null) break;

      // Extract the complete sentence (up to and including punctuation)
      final sentenceEnd = match.end;
      final completeSentence = _streamingSentenceBuffer.substring(
          0, match.start + match.group(1)!.length);

      // Remove the sentence from buffer
      _streamingSentenceBuffer =
          _streamingSentenceBuffer.substring(sentenceEnd);

      // Add to TTS queue if it has meaningful content
      if (completeSentence.trim().length > 3) {
        print(
            '🎙️ [VOICE] Queueing sentence: "${completeSentence.length > 50 ? '${completeSentence.substring(0, 50)}...' : completeSentence}"');
        _ttsService.addSentenceToQueue(completeSentence.trim());
      }
    }
  }

  void _onStreamCompleted(
    StreamCompleted event,
    Emitter<VoiceConversationState> emit,
  ) {
    // Add assistant message to local state
    final assistantMessage = ConversationMessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: state.conversation!.id,
      userId: _supabaseClient.auth.currentUser?.id ?? '',
      messageOrder: state.messages.length,
      role: MessageRole.assistant,
      contentText: state.streamingResponse,
      contentLanguage: state.languageCode,
      scriptureReferences: event.scriptureReferences,
      createdAt: DateTime.now(),
    );

    // If streaming TTS was used, finish it and queue any remaining text
    if (_streamingTTSStarted) {
      // Queue any remaining buffered text (last sentence without trailing space)
      if (_streamingSentenceBuffer.trim().isNotEmpty) {
        print(
            '🎙️ [VOICE] Queueing final sentence: "${_streamingSentenceBuffer.length > 50 ? '${_streamingSentenceBuffer.substring(0, 50)}...' : _streamingSentenceBuffer}"');
        _ttsService.addSentenceToQueue(_streamingSentenceBuffer.trim());
      }

      // Mark streaming as finished - TTS will continue playing queued sentences
      _ttsService.finishStreaming();

      // Reset streaming state
      _streamingTTSStarted = false;
      _streamingSentenceBuffer = '';

      emit(state.copyWith(
        messages: [...state.messages, assistantMessage],
        streamingResponse: '',
        // Keep isPlaying true - TTS is still playing
      ));
    } else {
      // No streaming TTS - use traditional flow
      emit(state.copyWith(
        status: VoiceConversationStatus.ready,
        messages: [...state.messages, assistantMessage],
        streamingResponse: '',
      ));

      // Auto-play response only if preference is enabled and streaming TTS wasn't used
      if (state.autoPlayResponse) {
        add(const PlayResponse());
      }
    }
  }

  void _onStreamError(
    StreamError event,
    Emitter<VoiceConversationState> emit,
  ) {
    // Cancel any streaming TTS
    if (_streamingTTSStarted) {
      _ttsService.cancelStreaming();
      _streamingTTSStarted = false;
      _streamingSentenceBuffer = '';
    }

    emit(state.copyWith(
      status: VoiceConversationStatus.error,
      errorMessage: event.message,
      streamingResponse: '',
      isPlaying: false,
    ));
  }

  /// Detect the language of text based on character scripts.
  /// Returns language code for TTS (en-US, hi-IN, ml-IN).
  String _detectTextLanguage(String text) {
    if (text.isEmpty) return 'en-US';

    int latinCount = 0;
    int devanagariCount = 0;
    int malayalamCount = 0;
    int totalLetters = 0;

    for (final char in text.runes) {
      // Devanagari script (Hindi): U+0900 to U+097F
      if (char >= 0x0900 && char <= 0x097F) {
        devanagariCount++;
        totalLetters++;
      }
      // Malayalam script: U+0D00 to U+0D7F
      else if (char >= 0x0D00 && char <= 0x0D7F) {
        malayalamCount++;
        totalLetters++;
      }
      // Basic Latin letters: A-Z, a-z
      else if ((char >= 0x0041 && char <= 0x005A) ||
          (char >= 0x0061 && char <= 0x007A)) {
        latinCount++;
        totalLetters++;
      }
    }

    if (totalLetters == 0) return 'en-US';

    // Determine dominant script (whichever has highest percentage)
    final latinPercent = latinCount / totalLetters;
    final devanagariPercent = devanagariCount / totalLetters;
    final malayalamPercent = malayalamCount / totalLetters;

    if (malayalamPercent > devanagariPercent &&
        malayalamPercent > latinPercent) {
      return 'ml-IN';
    } else if (devanagariPercent > latinPercent) {
      return 'hi-IN';
    } else {
      return 'en-US';
    }
  }

  Future<void> _onPlayResponse(
    PlayResponse event,
    Emitter<VoiceConversationState> emit,
  ) async {
    if (state.messages.isEmpty) return;

    final lastMessage = state.messages.last;
    if (lastMessage.role != MessageRole.assistant) return;

    // Capture continuous mode state BEFORE starting playback
    final shouldContinueListening = state.isContinuousMode;

    // Detect language from response text for TTS (only if auto-detect is enabled)
    final detectedLanguage = state.autoDetectLanguage
        ? _detectTextLanguage(lastMessage.contentText)
        : state.languageCode;

    // Check if detected language is available for TTS
    final isDetectedLangAvailable =
        await _isLanguageAvailableForTTS(detectedLanguage);

    print('🎙️ [VOICE] Playing response:');
    print('  - User language: ${state.languageCode}');
    print('  - Detected language: $detectedLanguage');
    print('  - Detected lang available: $isDetectedLangAvailable');
    print('  - Continuous mode: $shouldContinueListening');

    // If detected language TTS is not available, skip TTS entirely
    // Just show text response on screen
    if (!isDetectedLangAvailable) {
      print(
          '🎙️ [VOICE] ⚠️ TTS not available for $detectedLanguage - skipping voice playback');
      print('🎙️ [VOICE] Text response will be shown on screen only');

      // Update language state if needed (for speech recognition)
      final shouldUpdateLanguage = detectedLanguage != state.languageCode;
      if (shouldUpdateLanguage) {
        emit(state.copyWith(languageCode: detectedLanguage));
      }

      // In continuous mode, restart listening after a short delay
      if (shouldContinueListening && state.hasActiveConversation) {
        print('🎙️ [VOICE] Continuous mode - starting listening (no TTS)');
        await Future.delayed(const Duration(milliseconds: 500));
        add(const StartListening());
      }
      return;
    }

    // TTS is available - proceed with voice playback
    final shouldUpdateLanguage = detectedLanguage != state.languageCode;
    if (shouldUpdateLanguage) {
      print(
          '🎙️ [VOICE] Switching language from ${state.languageCode} to $detectedLanguage');
    }

    emit(state.copyWith(
      status: VoiceConversationStatus.playing,
      isPlaying: true,
      languageCode:
          shouldUpdateLanguage ? detectedLanguage : state.languageCode,
    ));

    // Use speakWithSettings with detected language
    await _ttsService.speakWithSettings(
      text: lastMessage.contentText,
      languageCode: detectedLanguage,
      onComplete: () {
        print(
            '🎙️ [VOICE] TTS completed, shouldContinueListening: $shouldContinueListening');
        add(PlaybackCompleted(
            shouldContinueListening: shouldContinueListening));
      },
    );

    // For web platform, TTS completion might not fire reliably
    // Add a fallback timer based on text length
    _startPlaybackFallbackTimer(
        lastMessage.contentText, shouldContinueListening);
  }

  /// Check if a language is available for TTS on this platform.
  Future<bool> _isLanguageAvailableForTTS(String languageCode) async {
    try {
      // Get available voices
      final voices = await _ttsService.getAvailableVoices();
      final shortLang = languageCode.split('-').first;

      // Check if any voice matches the language
      for (final voice in voices) {
        if (voice is Map) {
          final locale = voice['locale']?.toString() ?? '';
          if (locale == languageCode || locale.startsWith(shortLang)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('🎙️ [VOICE] Error checking language availability: $e');
      return false;
    }
  }

  Timer? _playbackFallbackTimer;

  void _startPlaybackFallbackTimer(String text, bool shouldContinueListening) {
    _playbackFallbackTimer?.cancel();

    // Estimate playback duration: ~150 words per minute, average 5 chars per word
    // So roughly 750 chars per minute, or 12.5 chars per second
    final estimatedDuration =
        Duration(milliseconds: (text.length / 10 * 1000).toInt() + 2000);

    print(
        '🎙️ [VOICE] Setting fallback timer for ${estimatedDuration.inSeconds}s');

    _playbackFallbackTimer = Timer(estimatedDuration, () {
      if (state.isPlaying) {
        print(
            '🎙️ [VOICE] Fallback timer fired - TTS completion may have failed');
        add(PlaybackCompleted(
            shouldContinueListening: shouldContinueListening));
      }
    });
  }

  Future<void> _onPlaybackCompleted(
    PlaybackCompleted event,
    Emitter<VoiceConversationState> emit,
  ) async {
    // Cancel fallback timer
    _playbackFallbackTimer?.cancel();
    _playbackFallbackTimer = null;

    // Don't process if not playing (already handled)
    if (!state.isPlaying) {
      print('🎙️ [VOICE] PlaybackCompleted ignored - not playing');
      return;
    }

    print(
        '🎙️ [VOICE] Playback completed, shouldContinueListening: ${event.shouldContinueListening}');

    // Stop playback state
    await _ttsService.stop();

    emit(state.copyWith(
      isPlaying: false,
      status: state.hasActiveConversation
          ? VoiceConversationStatus.ready
          : state.status,
    ));

    // Start listening again if continuous mode was enabled
    if (event.shouldContinueListening && state.hasActiveConversation) {
      print('🎙️ [VOICE] Continuous mode - starting listening again');
      // Small delay before starting to listen again
      await Future.delayed(const Duration(milliseconds: 500));
      add(const StartListening());
    }
  }

  Future<void> _onStopPlayback(
    StopPlayback event,
    Emitter<VoiceConversationState> emit,
  ) async {
    // Cancel fallback timer
    _playbackFallbackTimer?.cancel();
    _playbackFallbackTimer = null;

    // Cancel streaming TTS if active
    if (_streamingTTSStarted) {
      await _ttsService.cancelStreaming();
      _streamingTTSStarted = false;
      _streamingSentenceBuffer = '';
    } else {
      await _ttsService.stop();
    }

    emit(state.copyWith(
      isPlaying: false,
      status: state.hasActiveConversation
          ? VoiceConversationStatus.ready
          : state.status,
    ));
  }

  Future<void> _onCheckQuota(
    CheckQuota event,
    Emitter<VoiceConversationState> emit,
  ) async {
    final result = await _repository.checkQuota();

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (quota) => emit(state.copyWith(quota: quota)),
    );
  }

  Future<void> _onLoadHistory(
    LoadConversationHistory event,
    Emitter<VoiceConversationState> emit,
  ) async {
    final result = await _repository.getConversationHistory(
      limit: event.limit,
      offset: event.offset,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (history) => emit(state.copyWith(conversationHistory: history)),
    );
  }

  Future<void> _onLoadConversation(
    LoadConversation event,
    Emitter<VoiceConversationState> emit,
  ) async {
    emit(state.copyWith(status: VoiceConversationStatus.loading));

    final result = await _repository.getConversation(event.conversationId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: VoiceConversationStatus.error,
        errorMessage: failure.message,
      )),
      (conversation) => emit(state.copyWith(
        status: VoiceConversationStatus.ready,
        conversation: conversation,
        messages: conversation.messages ?? [],
        languageCode: conversation.languageCode,
      )),
    );
  }

  void _onToggleContinuousMode(
    ToggleContinuousMode event,
    Emitter<VoiceConversationState> emit,
  ) {
    emit(state.copyWith(isContinuousMode: event.enabled));
  }

  void _onChangeLanguage(
    ChangeLanguage event,
    Emitter<VoiceConversationState> emit,
  ) {
    emit(state.copyWith(languageCode: event.languageCode));
  }

  /// Handle speech recognition status changes.
  /// Updates UI when speech recognition stops due to timeout or completion.
  void _onSpeechStatusChanged(
    SpeechStatusChanged event,
    Emitter<VoiceConversationState> emit,
  ) {
    print('🎙️ [VOICE] Speech status changed: ${event.status}');

    // When status changes to 'notListening' or 'done', update UI accordingly
    if ((event.status == 'notListening' || event.status == 'done') &&
        state.isListening) {
      print('🎙️ [VOICE] Speech recognition stopped - updating UI');

      // Before stopping, check if we have unsent transcription
      // Send it if we're not already processing a message
      if (_currentTranscription.isNotEmpty &&
          state.status != VoiceConversationStatus.processing &&
          state.status != VoiceConversationStatus.streaming) {
        print(
            '🎙️ [VOICE] Speech stopped with pending text - sending: $_currentTranscription');
        add(SendTextMessage(_currentTranscription));
      }

      // Stop VAD service
      _vadService.stop();

      // Update state to reflect that we're no longer listening
      emit(state.copyWith(
        isListening: false,
        status: state.hasActiveConversation
            ? VoiceConversationStatus.ready
            : state.status,
      ));
    }
  }

  @override
  Future<void> close() {
    _playbackFallbackTimer?.cancel();
    _silenceAfterSpeechTimer?.cancel();
    _vadService.dispose();
    _speechSubscription?.cancel();
    _cleanupStream();
    _speechService.dispose();
    _ttsService.dispose();
    return super.close();
  }
}
