import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/speech_service.dart';
import '../../data/services/tts_service.dart';
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

  StreamSubscription? _speechSubscription;
  StreamSubscription? _streamSubscription;
  Timer? _silenceTimer;

  VoiceConversationBloc({
    required VoiceBuddyRepository repository,
    required SpeechService speechService,
    required TTSService ttsService,
    required SupabaseClient supabaseClient,
  })  : _repository = repository,
        _speechService = speechService,
        _ttsService = ttsService,
        _supabaseClient = supabaseClient,
        super(const VoiceConversationState()) {
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
    if (state.isPlaying) {
      print('🎙️ [VOICE] User started speaking - stopping TTS playback');
      _playbackFallbackTimer?.cancel();
      _playbackFallbackTimer = null;
      await _ttsService.stop();
    }

    emit(state.copyWith(
      status: VoiceConversationStatus.listening,
      isListening: true,
      isPlaying: false,
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

    // Start listening
    _speechSubscription?.cancel();

    // Capture continuous mode state for the callback
    final isContinuousMode = state.isContinuousMode;

    try {
      await _speechService.startListening(
        languageCode: state.languageCode,
        onResult: (result) {
          final text = result.recognizedWords;
          final confidence = result.confidence;

          add(ProcessSpeechText(text: text, confidence: confidence));

          // In continuous mode, the silence timer handles sending
          // In normal mode, send on finalResult
          if (result.finalResult && !isContinuousMode) {
            add(const StopListening());
            add(SendTextMessage(text));
          }
        },
        onSoundLevelChange: (level) {
          // Could emit sound level for waveform visualization
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
    _silenceTimer?.cancel();
    _silenceTimer = null;

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

    // In continuous mode, start/reset silence timer to auto-send when user stops speaking
    if (state.isContinuousMode && event.text.isNotEmpty) {
      _startSilenceTimer(event.text);
    }
  }

  void _startSilenceTimer(String currentText) {
    _silenceTimer?.cancel();

    // Wait 1.5 seconds of silence before auto-sending
    _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (state.isListening && currentText.isNotEmpty) {
        print('🎙️ [VOICE] Silence detected - auto-sending message');
        add(const StopListening());
        add(SendTextMessage(currentText));
      }
    });
  }

  Future<void> _onSendTextMessage(
    SendTextMessage event,
    Emitter<VoiceConversationState> emit,
  ) async {
    if (!state.hasActiveConversation || event.message.isEmpty) return;

    emit(state.copyWith(
      status: VoiceConversationStatus.processing,
      streamingResponse: '',
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
        // It might be a ByteStream or other type, try to convert
        try {
          final bytes = await response.data.toBytes();
          responseText = utf8.decode(bytes);
        } catch (e) {
          // Fallback: try toString
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

  void _onReceiveStreamChunk(
    ReceiveStreamChunk event,
    Emitter<VoiceConversationState> emit,
  ) {
    emit(state.copyWith(
      streamingResponse: state.streamingResponse + event.chunk,
    ));
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

    emit(state.copyWith(
      status: VoiceConversationStatus.ready,
      messages: [...state.messages, assistantMessage],
      streamingResponse: '',
    ));

    // Auto-play response if enabled
    add(const PlayResponse());
  }

  void _onStreamError(
    StreamError event,
    Emitter<VoiceConversationState> emit,
  ) {
    emit(state.copyWith(
      status: VoiceConversationStatus.error,
      errorMessage: event.message,
      streamingResponse: '',
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

    // Detect language from response text for TTS
    final detectedLanguage = _detectTextLanguage(lastMessage.contentText);

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

    await _ttsService.stop();

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

  @override
  Future<void> close() {
    _playbackFallbackTimer?.cancel();
    _silenceTimer?.cancel();
    _speechSubscription?.cancel();
    _streamSubscription?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
    return super.close();
  }
}
