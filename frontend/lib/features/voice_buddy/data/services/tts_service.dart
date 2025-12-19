import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'cloud_tts_service.dart';

/// Service for handling text-to-speech functionality.
///
/// Supports multi-language synthesis for English, Hindi, and Malayalam.
/// Uses Google Cloud TTS for high-quality voices when available,
/// with fallback to device TTS.
/// Also supports streaming TTS for playing sentences as they arrive.
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  final CloudTTSService _cloudTts = CloudTTSService();

  bool _isInitialized = false;
  bool _cloudTtsAvailable = false;
  bool _useCloudTts = true; // Prefer cloud TTS when available

  TtsState _currentState = TtsState.stopped;
  bool _isIntentionallyStopping = false;

  /// Queue of sentences to speak for streaming TTS
  final List<String> _sentenceQueue = [];

  /// Whether we're currently in streaming mode
  bool _isStreamingMode = false;

  /// Language code for current streaming session
  String _streamingLanguageCode = 'en-US';

  /// Voice settings for current streaming session
  double _streamingSpeakingRate = 1.0;
  double _streamingPitch = 0.0;
  String _streamingVoiceGender = 'female';

  /// Callback when all queued sentences are done
  void Function()? _onStreamingComplete;

  /// Current state of TTS playback.
  TtsState get currentState => _currentState;

  /// Whether TTS is currently speaking.
  bool get isSpeaking =>
      _currentState == TtsState.playing || _cloudTts.isPlaying;

  /// Whether cloud TTS is being used.
  bool get isUsingCloudTts => _cloudTtsAvailable && _useCloudTts;

  /// Enable or disable cloud TTS.
  void setUseCloudTts(bool enabled) {
    _useCloudTts = enabled;
    print('🔊 [TTS] Cloud TTS ${enabled ? "enabled" : "disabled"}');
  }

  /// Initialize the TTS service with default settings.
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔊 [TTS] Already initialized');
      return;
    }

    print('🔊 [TTS] Initializing TTS service...');

    // Try to initialize Cloud TTS first (for high-quality voices)
    if (_cloudTts.isAvailable) {
      print('🔊 [TTS] Cloud TTS API key found, initializing...');
      _cloudTtsAvailable = await _cloudTts.initialize();
      if (_cloudTtsAvailable) {
        print('🔊 [TTS] ✅ Cloud TTS initialized - using high-quality voices');
      } else {
        print(
            '🔊 [TTS] ⚠️ Cloud TTS initialization failed, will use device TTS');
      }
    } else {
      print('🔊 [TTS] Cloud TTS API key not configured, using device TTS');
    }

    // Platform-specific configuration
    if (kIsWeb) {
      print('🔊 [TTS] Platform: Web - using browser Speech Synthesis API');
    } else {
      // Safe to use Platform on non-web
      final isAndroid = Platform.isAndroid;
      final isIOS = Platform.isIOS;
      print(
          '🔊 [TTS] Platform: ${isAndroid ? "Android" : (isIOS ? "iOS" : "Unknown")}');

      if (isIOS) {
        print('🔊 [TTS] Applying iOS-specific configuration...');
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } else if (isAndroid) {
        print('🔊 [TTS] Android platform - using native TTS engine');
        // Android uses native TTS engine (typically Google TTS)
        // Try to use Google TTS if available, otherwise use default engine
        try {
          final engines = await _flutterTts.getEngines;
          print('🔊 [TTS] Available engines: $engines');
          if (engines.contains('com.google.android.tts')) {
            await _flutterTts.setEngine('com.google.android.tts');
            print('🔊 [TTS] Using Google TTS engine');
          }
        } catch (e) {
          print('🔊 [TTS] Could not set engine, using default: $e');
        }
      }
    }

    // Set up callbacks
    _flutterTts.setStartHandler(() {
      _currentState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _currentState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      _currentState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      _currentState = TtsState.playing;
    });

    _flutterTts.setErrorHandler((message) {
      // Ignore "interrupted" errors when we intentionally stopped
      if (_isIntentionallyStopping &&
          message.toString().contains('interrupted')) {
        print('🔊 [TTS] Ignoring interrupted error (intentional stop)');
        _isIntentionallyStopping = false;
        return;
      }
      print('🔊 [TTS ERROR] $message');
      _currentState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      _currentState = TtsState.stopped;
    });

    _isInitialized = true;
    print('🔊 [TTS] Initialization completed successfully');

    // Wait for voices to load on web
    if (kIsWeb) {
      await _waitForVoicesToLoad();
    }
  }

  /// Wait for browser voices to load (web-specific).
  Future<void> _waitForVoicesToLoad() async {
    print('🔊 [TTS] Waiting for browser voices to load...');

    // Try up to 5 times with delays
    for (var i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 200 * (i + 1)));

      try {
        final voices = await getAvailableVoices();
        print('🔊 [TTS] Attempt ${i + 1}: Found ${voices.length} voices');

        if (voices.isNotEmpty) {
          print('🔊 [TTS] ✅ Voices loaded successfully!');
          _logAvailableVoices(voices);
          return;
        }
      } catch (e) {
        print('🔊 [TTS] Attempt ${i + 1} error: $e');
      }
    }

    print('🔊 [TTS] ⚠️ Failed to load voices after multiple attempts');
    print('🔊 [TTS] This may indicate browser TTS is disabled or unavailable');
  }

  /// Log available voices for debugging.
  void _logAvailableVoices(List<dynamic> voices) {
    print('🔊 [TTS] Total voices available: ${voices.length}');

    // Group voices by language
    final voicesByLang = <String, int>{};
    for (final voice in voices) {
      if (voice is Map) {
        final lang = voice['locale']?.toString() ?? 'unknown';
        final shortLang = lang.split('-').first;
        voicesByLang[shortLang] = (voicesByLang[shortLang] ?? 0) + 1;
      }
    }

    print('🔊 [TTS] Voices by language: $voicesByLang');

    // Find Hindi voices
    final hindiVoices = voices.where((v) {
      if (v is Map) {
        final lang = v['locale']?.toString() ?? '';
        return lang.startsWith('hi');
      }
      return false;
    }).toList();

    if (hindiVoices.isNotEmpty) {
      print('🔊 [TTS] ✅ Hindi voices found: ${hindiVoices.length}');
      for (final voice in hindiVoices) {
        if (voice is Map) {
          print('🔊 [TTS]   - ${voice['name']} (${voice['locale']})');
        }
      }
    } else {
      print('🔊 [TTS] ⚠️ No Hindi voices available');
      print('🔊 [TTS] Available languages: ${voicesByLang.keys.join(", ")}');
    }
  }

  /// Get list of available languages for TTS.
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _flutterTts.getLanguages;
  }

  /// Get list of available voices.
  Future<List<dynamic>> getAvailableVoices() async {
    return await _flutterTts.getVoices;
  }

  /// Check if a specific language is available.
  Future<bool> isLanguageAvailable(String languageCode) async {
    final result = await _flutterTts.isLanguageAvailable(languageCode);
    return result == 1;
  }

  /// Set the language for TTS.
  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    // On web, isLanguageAvailable is unreliable - check voices directly
    if (kIsWeb) {
      final voice = await _findVoiceForLanguage(languageCode);
      if (voice != null) {
        print('🔊 [TTS] ✅ Found voice for $languageCode: ${voice['name']}');
        await _flutterTts
            .setVoice({'name': voice['name'], 'locale': voice['locale']});
        return;
      } else {
        print(
            '🔊 [TTS] ⚠️ No voice found for $languageCode, trying fallback to en-US');
        final enVoice = await _findVoiceForLanguage('en-US');
        if (enVoice != null) {
          await _flutterTts
              .setVoice({'name': enVoice['name'], 'locale': enVoice['locale']});
        }
        return;
      }
    }

    // On native platforms, use the standard method
    final isAvailable = await isLanguageAvailable(languageCode);
    print('🔊 [TTS] Language $languageCode available: $isAvailable');

    if (!isAvailable) {
      print(
          '🔊 [TTS] ⚠️ Language $languageCode not available, falling back to en-US');
      await _flutterTts.setLanguage('en-US');
      return;
    }

    await _flutterTts.setLanguage(languageCode);
  }

  /// Find a voice for the specified language code.
  Future<Map<String, dynamic>?> _findVoiceForLanguage(
      String languageCode) async {
    final voices = await getAvailableVoices();
    final shortLang = languageCode.split('-').first;

    // Try exact match first
    for (final voice in voices) {
      if (voice is Map) {
        final locale = voice['locale']?.toString() ?? '';
        if (locale == languageCode) {
          return Map<String, dynamic>.from(voice);
        }
      }
    }

    // Try short language match (e.g., 'hi' for 'hi-IN')
    for (final voice in voices) {
      if (voice is Map) {
        final locale = voice['locale']?.toString() ?? '';
        if (locale.startsWith(shortLang)) {
          return Map<String, dynamic>.from(voice);
        }
      }
    }

    return null;
  }

  /// Set the speech rate (0.0 to 1.0, default 0.5).
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) {
      await initialize();
    }
    // Flutter TTS uses 0.0-1.0 range, but we accept 0.5-2.0
    // Convert: 0.5->0.25, 1.0->0.5, 2.0->1.0
    final normalizedRate = (rate - 0.5) / 1.5 * 0.75 + 0.25;
    await _flutterTts.setSpeechRate(normalizedRate.clamp(0.0, 1.0));
  }

  /// Set the pitch (0.5 to 2.0, default 1.0).
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }

  /// Set the volume (0.0 to 1.0, default 1.0).
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Set a specific voice by name.
  Future<void> setVoice(Map<String, String> voice) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.setVoice(voice);
  }

  /// Convert Bible references to spoken format for natural TTS pronunciation.
  ///
  /// Transforms references like "John 3:16" to "John Chapter 3 verse 16"
  /// and "1 Corinthians 1:1-2" to "First Corinthians Chapter 1 verses 1 to 2".
  /// Supports English, Hindi, and Malayalam localization.
  /// Limits book name to max 3 words to avoid false positives.
  String _convertBibleReferencesForTTS(String text, String languageCode) {
    // Pattern matches: "Book Chapter:Verse" or "Book Chapter:Verse-Verse"
    // Group 1: Optional number prefix (1, 2, 3 for numbered books)
    // Group 2: Book name (1-3 words, supports English, Hindi, Malayalam)
    // Group 3: Chapter number
    // Group 4: Start verse
    // Group 5: End verse (optional, for ranges)
    // Limits to 3 words max to avoid matching "आप शायद भजन संहिता 23:1"
    final bibleRefPattern = RegExp(
      r'(\d)?\s*([A-Za-z\u0900-\u097F\u0D00-\u0D7F]+(?:\s+[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+){0,2})\s+(\d+):(\d+)(?:-(\d+))?',
      caseSensitive: false,
    );

    return text.replaceAllMapped(bibleRefPattern, (match) {
      final bookNumber = match.group(1); // "1", "2", "3" or null
      final bookName = match.group(2)!;
      final chapter = match.group(3)!;
      final verseStart = match.group(4)!;
      final verseEnd = match.group(5); // null if single verse

      // Get localized terms based on language
      final (chapterWord, verseWord, versesWord, toWord) =
          _getLocalizedBibleTerms(languageCode);

      // Convert numbered books for English (1 → First, etc.)
      String fullBookName;
      if (bookNumber != null && languageCode.startsWith('en')) {
        final ordinal = _numberToOrdinal(bookNumber);
        fullBookName = '$ordinal $bookName';
      } else if (bookNumber != null) {
        fullBookName = '$bookNumber $bookName';
      } else {
        fullBookName = bookName;
      }

      if (verseEnd != null) {
        return '$fullBookName $chapterWord $chapter $versesWord $verseStart $toWord $verseEnd';
      } else {
        return '$fullBookName $chapterWord $chapter $verseWord $verseStart';
      }
    });
  }

  /// Convert number to ordinal word for numbered Bible books (English only).
  String _numberToOrdinal(String number) {
    switch (number) {
      case '1':
        return 'First';
      case '2':
        return 'Second';
      case '3':
        return 'Third';
      default:
        return number;
    }
  }

  /// Get localized terms for Bible references.
  /// Returns (chapter, verse, verses, to) in the specified language.
  (String, String, String, String) _getLocalizedBibleTerms(
      String languageCode) {
    switch (languageCode) {
      case 'hi-IN':
        return ('अध्याय', 'पद', 'पद', 'से');
      case 'ml-IN':
        return ('അദ്ധ്യായം', 'വാക്യം', 'വാക്യങ്ങൾ', 'മുതൽ');
      default: // en-US, en-IN and others
        return ('Chapter', 'verse', 'verses', 'to');
    }
  }

  /// Sanitize text for TTS to prevent reading punctuation as words.
  String _sanitizeTextForTTS(String text, {String languageCode = 'en-US'}) {
    // First convert Bible references to spoken format
    final withBibleRefs = _convertBibleReferencesForTTS(text, languageCode);

    // Remove or replace punctuation that TTS might read literally
    final sanitized = withBibleRefs
        // Keep sentence-ending punctuation for natural pauses
        .replaceAll('!', '.')
        .replaceAll('?', '.')
        // Remove special characters that TTS reads as words
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('-', ' ')
        .replaceAll('—', ' ')
        .replaceAll('–', ' ')
        // Remove quotes that might be read literally
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        // Remove brackets and parentheses
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        // Remove extra spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return sanitized;
  }

  /// Speak the given text.
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      print('🔊 [TTS] speak() called but not initialized, initializing...');
      await initialize();
    }

    if (_currentState == TtsState.playing) {
      print('🔊 [TTS] Already playing, stopping previous playback');
      _isIntentionallyStopping = true;
      await stop();
      // Small delay to let the browser process the stop
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Sanitize text before speaking
    final sanitizedText = _sanitizeTextForTTS(text);
    print('🔊 [TTS] Original text: "$text"');
    print('🔊 [TTS] Sanitized text: "$sanitizedText"');

    print('🔊 [TTS] Calling FlutterTts.speak()...');
    try {
      final result = await _flutterTts.speak(sanitizedText);
      print('🔊 [TTS] FlutterTts.speak() returned: $result');

      if (result == null && kIsWeb) {
        print(
            '🔊 [TTS] ⚠️ speak() returned null on web - TTS might have failed');
        print('🔊 [TTS] This usually means:');
        print('🔊 [TTS]   1. The language is not supported by the browser');
        print(
            '🔊 [TTS]   2. User interaction is required before first TTS call');
        print('🔊 [TTS]   3. Browser TTS is disabled or not available');
      }
    } catch (e) {
      print('🔊 [TTS ERROR] Exception during speak: $e');
      rethrow;
    }
  }

  /// Speak text with specific language and voice settings.
  ///
  /// Uses Google Cloud TTS for high-quality voices when available,
  /// with automatic fallback to device TTS.
  Future<void> speakWithSettings({
    required String text,
    required String languageCode,
    double? speakingRate,
    double? pitch,
    String? voiceGender,
    void Function()? onComplete,
  }) async {
    print('🔊 [TTS] Speaking with settings:');
    print('  Language: $languageCode');
    print('  Text length: ${text.length} chars');
    print('  Speaking rate: $speakingRate');
    print('  Pitch: $pitch');
    print('  Voice gender: $voiceGender');
    print('  Cloud TTS available: $_cloudTtsAvailable');
    print('  Use Cloud TTS: $_useCloudTts');

    if (!_isInitialized) {
      print('🔊 [TTS] Initializing TTS service...');
      await initialize();
    }

    // Try Cloud TTS first for high-quality voices (with streaming for faster start)
    if (_cloudTtsAvailable && _useCloudTts) {
      print('🔊 [TTS] Using Google Cloud TTS (high-quality, streaming)');

      final success = await _cloudTts.speakStreaming(
        text: text,
        languageCode: languageCode,
        speakingRate: speakingRate ?? 1.0,
        pitch: pitch ?? 0.0,
        onComplete: () {
          _currentState = TtsState.stopped;
          onComplete?.call();
        },
      );

      if (success) {
        _currentState = TtsState.playing;
        print('🔊 [TTS] Cloud TTS streaming playback started');
        return;
      }

      print('🔊 [TTS] Cloud TTS failed, falling back to device TTS');
    }

    // Fallback to device TTS
    print('🔊 [TTS] Using device TTS (fallback)');
    print('🔊 [TTS] Setting language to $languageCode');
    await setLanguage(languageCode);

    if (speakingRate != null) {
      await setSpeechRate(speakingRate);
    }

    if (pitch != null) {
      await setPitch(pitch);
    }

    // Try to select appropriate voice based on gender and language
    if (voiceGender != null) {
      await _selectVoiceByGender(languageCode, voiceGender);
    }

    // Set completion callback if provided
    if (onComplete != null) {
      _flutterTts.setCompletionHandler(() {
        _currentState = TtsState.stopped;
        onComplete();
      });
    }

    print(
        '🔊 [TTS] Calling speak() with text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
    await speak(text);
    print('🔊 [TTS] speak() call completed');
  }

  /// Select a voice based on language and gender preference.
  Future<void> _selectVoiceByGender(String languageCode, String gender) async {
    final voices = await getAvailableVoices();

    // Find voices matching language and gender
    final matchingVoices = voices.where((voice) {
      if (voice is Map) {
        final locale = voice['locale']?.toString() ?? '';
        final voiceGender = voice['gender']?.toString().toLowerCase() ?? '';
        return locale.startsWith(languageCode.split('-')[0]) &&
            voiceGender.contains(gender.toLowerCase());
      }
      return false;
    }).toList();

    if (matchingVoices.isNotEmpty) {
      final voice = matchingVoices.first as Map;
      await setVoice({
        'name': voice['name']?.toString() ?? '',
        'locale': voice['locale']?.toString() ?? languageCode,
      });
    }
  }

  /// Stop speaking.
  Future<void> stop() async {
    if (_currentState == TtsState.playing) {
      _isIntentionallyStopping = true;
    }

    // Stop both cloud and device TTS
    await _cloudTts.stop();
    await _flutterTts.stop();
    _currentState = TtsState.stopped;

    // Also clear streaming queue
    _sentenceQueue.clear();
    _isStreamingMode = false;
  }

  /// Pause speaking (iOS only).
  Future<void> pause() async {
    await _flutterTts.pause();
    _currentState = TtsState.paused;
  }

  // ============================================================
  // STREAMING TTS METHODS
  // ============================================================

  /// Whether we're in the middle of initializing a streaming session
  bool _isInitializingStreamingSession = false;

  /// Start a streaming TTS session.
  ///
  /// Call this before adding sentences with [addSentenceToQueue].
  /// When streaming is complete, call [finishStreaming] to play any remaining text.
  /// Uses Cloud TTS when available for high-quality voices.
  Future<void> startStreamingSession({
    required String languageCode,
    double speakingRate = 1.0,
    double pitch = 0.0,
    String voiceGender = 'female',
    void Function()? onComplete,
  }) async {
    print('🔊 [TTS STREAM] Starting streaming session for $languageCode');
    print(
        '🔊 [TTS STREAM] Cloud TTS available: $_cloudTtsAvailable, enabled: $_useCloudTts');
    print(
        '🔊 [TTS STREAM] Voice settings: rate=$speakingRate, pitch=$pitch, gender=$voiceGender');

    // Set streaming mode IMMEDIATELY so sentences can be queued during init
    _isStreamingMode = true;
    _isInitializingStreamingSession = true;
    _streamingLanguageCode = languageCode;
    _streamingSpeakingRate = speakingRate;
    _streamingPitch = pitch;
    _streamingVoiceGender = voiceGender;
    _onStreamingComplete = onComplete;

    // Clear any previous queue
    _sentenceQueue.clear();

    if (!_isInitialized) {
      await initialize();
    }

    // Stop any current playback (both cloud and device TTS)
    if (_currentState == TtsState.playing || _cloudTts.isPlaying) {
      _isIntentionallyStopping = true;
      await _cloudTts.stop();
      await _flutterTts.stop();
      _currentState = TtsState.stopped;
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Set up completion handler for queued playback (used only for device TTS fallback)
    _flutterTts.setCompletionHandler(() {
      _currentState = TtsState.stopped;
      _playNextInQueue();
    });

    // Set language for device TTS fallback
    await setLanguage(languageCode);

    _isInitializingStreamingSession = false;
    print(
        '🔊 [TTS STREAM] Session ready, queue has ${_sentenceQueue.length} sentences');

    // If sentences were added during initialization, start playing now
    if (_sentenceQueue.isNotEmpty && _currentState != TtsState.playing) {
      _playNextInQueue();
    }
  }

  /// Add a complete sentence to the TTS queue.
  ///
  /// The sentence will be spoken immediately if nothing is playing,
  /// otherwise it will be queued.
  Future<void> addSentenceToQueue(String sentence) async {
    if (!_isStreamingMode) {
      print('🔊 [TTS STREAM] ⚠️ Not in streaming mode, ignoring sentence');
      return;
    }

    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return;

    final sanitized =
        _sanitizeTextForTTS(trimmed, languageCode: _streamingLanguageCode);
    if (sanitized.isEmpty) return;

    print(
        '🔊 [TTS STREAM] Adding to queue: "${sanitized.length > 40 ? '${sanitized.substring(0, 40)}...' : sanitized}"');

    _sentenceQueue.add(sanitized);

    // Only start playing if not initializing and not currently playing
    // During initialization, startStreamingSession will trigger playback when ready
    if (!_isInitializingStreamingSession && _currentState != TtsState.playing) {
      _playNextInQueue();
    }
  }

  /// Play the next sentence in the queue.
  /// Uses Cloud TTS when available for high-quality voices.
  Future<void> _playNextInQueue() async {
    if (_sentenceQueue.isEmpty) {
      print('🔊 [TTS STREAM] Queue empty');
      // Check if streaming is finished
      if (!_isStreamingMode) {
        print('🔊 [TTS STREAM] Streaming complete, calling onComplete');
        _currentState = TtsState.stopped;
        final callback = _onStreamingComplete;
        _onStreamingComplete = null;
        callback?.call();
      }
      return;
    }

    final sentence = _sentenceQueue.removeAt(0);
    print(
        '🔊 [TTS STREAM] Playing: "${sentence.length > 40 ? '${sentence.substring(0, 40)}...' : sentence}"');
    print('🔊 [TTS STREAM] Remaining in queue: ${_sentenceQueue.length}');

    // Try Cloud TTS first for high-quality voices
    if (_cloudTtsAvailable && _useCloudTts) {
      print('🔊 [TTS STREAM] Using Cloud TTS');
      _currentState = TtsState.playing;

      _speakWithCloudTTS(sentence);
      return;
    }

    // Fallback to device TTS with voice settings
    // Await settings to ensure they are applied before speaking
    print('🔊 [TTS STREAM] Using device TTS with settings');
    await _applyDeviceTTSSettings();
    await _flutterTts.speak(sentence);
    _currentState = TtsState.playing;
  }

  /// Apply stored streaming voice settings to device TTS
  Future<void> _applyDeviceTTSSettings() async {
    await setSpeechRate(_streamingSpeakingRate);
    await setPitch(_streamingPitch);
    await _selectVoiceByGender(_streamingLanguageCode, _streamingVoiceGender);
  }

  /// Speak using Cloud TTS with proper error handling.
  Future<void> _speakWithCloudTTS(String sentence) async {
    try {
      final success = await _cloudTts.speak(
        text: sentence,
        languageCode: _streamingLanguageCode,
        speakingRate: _streamingSpeakingRate,
        pitch: _streamingPitch,
        onComplete: () {
          _currentState = TtsState.stopped;
          // Always call _playNextInQueue - it handles empty queue and completion callback
          _playNextInQueue();
        },
      );

      if (!success) {
        print('🔊 [TTS STREAM] Cloud TTS failed, falling back to device TTS');
        // Fallback to device TTS
        await _flutterTts.speak(sentence);
      }
    } catch (e) {
      print('🔊 [TTS STREAM] Cloud TTS error: $e');
      _currentState = TtsState.stopped;
      // Always call _playNextInQueue - it handles empty queue and completion callback
      _playNextInQueue();
    }
  }

  /// Finish the streaming session.
  ///
  /// Call this when the stream is complete. Any remaining queued sentences
  /// will continue playing, and onComplete will be called when done.
  void finishStreaming() {
    print('🔊 [TTS STREAM] Finishing streaming session');
    _isStreamingMode = false;

    // If nothing is playing and queue is empty, call complete now
    if (_currentState != TtsState.playing && _sentenceQueue.isEmpty) {
      print('🔊 [TTS STREAM] No more audio, calling onComplete immediately');
      _onStreamingComplete?.call();
      _onStreamingComplete = null;
    }
    // Otherwise, the completion handler will call onComplete when done
  }

  /// Cancel streaming and stop all playback.
  Future<void> cancelStreaming() async {
    print('🔊 [TTS STREAM] Cancelling streaming session');
    _sentenceQueue.clear();
    _isStreamingMode = false;
    _onStreamingComplete = null;
    await stop();
  }

  /// Whether streaming TTS is currently active.
  bool get isStreaming => _isStreamingMode;

  /// Number of sentences waiting in the queue.
  int get queueLength => _sentenceQueue.length;

  /// Dispose of the service resources.
  void dispose() {
    stop();
    _cloudTts.dispose();
  }
}

/// State of TTS playback.
enum TtsState {
  playing,
  stopped,
  paused,
}

/// Voice configuration for different languages.
class VoiceConfig {
  final String languageCode;
  final String voiceName;
  final String gender;
  final double speakingRate;
  final double pitch;

  const VoiceConfig({
    required this.languageCode,
    required this.voiceName,
    required this.gender,
    this.speakingRate = 0.95,
    this.pitch = 1.0,
  });

  /// Default voice configurations for supported languages.
  static const Map<String, VoiceConfig> defaults = {
    'en-US': VoiceConfig(
      languageCode: 'en-US',
      voiceName: 'en-us-x-sfg#female_1-local',
      gender: 'female',
    ),
    'hi-IN': VoiceConfig(
      languageCode: 'hi-IN',
      voiceName: 'hi-in-x-hid#female_1-local',
      gender: 'female',
      speakingRate: 0.9,
    ),
    'ml-IN': VoiceConfig(
      languageCode: 'ml-IN',
      voiceName: 'ml-in-x-mlm#female_1-local',
      gender: 'female',
      speakingRate: 0.9,
    ),
  };

  /// Get default config for a language.
  static VoiceConfig getDefault(String languageCode) {
    return defaults[languageCode] ?? defaults['en-US']!;
  }
}
