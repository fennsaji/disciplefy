import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';

/// Service for high-quality text-to-speech using Google Cloud TTS REST API.
///
/// Provides natural-sounding WaveNet and Neural2 voices for
/// English, Hindi, and Malayalam.
class CloudTTSService {
  CloudTTSService();

  bool _isInitialized = false;

  /// AudioPlayer instance - created fresh for each playback to avoid web issues
  AudioPlayer? _audioPlayer;
  late final Dio _dio;

  /// Cancel token for in-flight requests
  CancelToken? _currentCancelToken;

  /// Stream subscription for audio player completion
  StreamSubscription? _playerCompleteSubscription;

  /// Flag to track if we're in the middle of speaking
  bool _isSpeaking = false;

  /// Cached voices for each language
  final Map<String, _CloudVoice> _voiceCache = {};

  /// Queue of pre-fetched audio chunks for streaming playback
  final List<Uint8List> _audioQueue = [];

  /// Current chunk index for streaming playback
  int _currentChunkIndex = 0;

  /// Total chunks for current streaming session
  int _totalChunks = 0;

  /// Flag to track if streaming is active
  bool _isStreaming = false;

  /// Completer for coordinating chunk fetching
  Completer<Uint8List?>? _nextChunkCompleter;

  /// Flag to signal stop during streaming
  bool _streamingStopRequested = false;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether Google Cloud TTS is available (API key configured)
  bool get isAvailable => AppConfig.googleCloudTtsApiKey.isNotEmpty;

  /// Current playback state
  bool get isPlaying =>
      _audioPlayer?.state == PlayerState.playing || _isSpeaking;

  /// Google Cloud TTS API endpoint
  static const String _apiEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';

  /// Initialize the Google Cloud TTS service.
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    const apiKey = AppConfig.googleCloudTtsApiKey;
    if (apiKey.isEmpty) {
      print('🔊 [CLOUD TTS] API key not configured, service unavailable');
      return false;
    }

    try {
      print('🔊 [CLOUD TTS] Initializing with API key...');

      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

      _isInitialized = true;
      print('🔊 [CLOUD TTS] Initialized successfully');

      // Pre-configure voices for supported languages
      _configureVoices();

      return true;
    } catch (e) {
      print('🔊 [CLOUD TTS] Initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Configure the best voices for each supported language.
  void _configureVoices() {
    // Best voices for each language (Neural2 > WaveNet > Standard)
    // Using female voices as they typically sound better for assistant use cases

    // English (US) - Neural2
    _voiceCache['en-US'] = _CloudVoice(
      languageCode: 'en-US',
      name: 'en-US-Neural2-F', // Female Neural2 voice
      ssmlGender: 'FEMALE',
    );

    // English (India) - Neural2
    _voiceCache['en-IN'] = _CloudVoice(
      languageCode: 'en-IN',
      name: 'en-IN-Neural2-A', // Female Neural2 voice
      ssmlGender: 'FEMALE',
    );

    // Hindi - Neural2
    _voiceCache['hi-IN'] = _CloudVoice(
      languageCode: 'hi-IN',
      name: 'hi-IN-Neural2-A', // Female Neural2 voice
      ssmlGender: 'FEMALE',
    );

    // Malayalam - Standard (Neural2/WaveNet not available)
    _voiceCache['ml-IN'] = _CloudVoice(
      languageCode: 'ml-IN',
      name: 'ml-IN-Standard-A', // Female Standard voice
      ssmlGender: 'FEMALE',
    );

    print('🔊 [CLOUD TTS] Configured voices:');
    for (final entry in _voiceCache.entries) {
      print('🔊 [CLOUD TTS]   ${entry.key}: ${entry.value.name}');
    }
  }

  /// Check if a language is supported.
  bool isLanguageSupported(String languageCode) {
    return _voiceCache.containsKey(languageCode);
  }

  /// Get available languages.
  List<String> getAvailableLanguages() {
    return _voiceCache.keys.toList();
  }

  /// Convert text to speech and play it.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> speak({
    required String text,
    required String languageCode,
    double speakingRate = 1.0,
    double pitch = 0.0,
    void Function()? onComplete,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    // Get voice for language
    var voice = _voiceCache[languageCode];
    if (voice == null) {
      // Try fallback to en-US
      voice = _voiceCache['en-US'];
      if (voice == null) {
        print('🔊 [CLOUD TTS] No voice available for $languageCode');
        return false;
      }
      print('🔊 [CLOUD TTS] Falling back to en-US voice');
    }

    try {
      print('🔊 [CLOUD TTS] Converting text to speech:');
      print('  - Language: $languageCode');
      print('  - Voice: ${voice.name}');
      print('  - Text length: ${text.length} chars');

      // Sanitize text with Bible reference conversion
      final sanitizedText = _sanitizeText(text, languageCode: languageCode);

      // Build request body
      final requestBody = {
        'input': {'text': sanitizedText},
        'voice': {
          'languageCode': voice.languageCode,
          'name': voice.name,
          'ssmlGender': voice.ssmlGender,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': speakingRate.clamp(0.25, 4.0),
          'pitch': pitch.clamp(-20.0, 20.0),
          'effectsProfileId': ['small-bluetooth-speaker-class-device'],
        },
      };

      // Cancel any previous request
      _currentCancelToken?.cancel('New speak request');
      _currentCancelToken = CancelToken();

      _isSpeaking = true;

      // Make API request
      const apiKey = AppConfig.googleCloudTtsApiKey;
      final response = await _dio.post(
        '$_apiEndpoint?key=$apiKey',
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        cancelToken: _currentCancelToken,
      );

      if (response.statusCode != 200) {
        print('🔊 [CLOUD TTS] API error: ${response.statusCode}');
        _isSpeaking = false;
        return false;
      }

      // Decode audio content (base64) with null-safety
      final dynamic rawAudioContent = response.data['audioContent'];
      if (rawAudioContent == null || rawAudioContent is! String) {
        print(
            '🔊 [CLOUD TTS] API response missing audioContent or invalid type');
        _isSpeaking = false;
        return false;
      }
      final audioBytes = base64Decode(rawAudioContent);

      print('🔊 [CLOUD TTS] Received ${audioBytes.length} bytes of audio');

      // Play the audio
      await _playAudio(audioBytes, onComplete);

      return true;
    } on DioException catch (e) {
      _isSpeaking = false;
      // Don't log cancellation as an error
      if (e.type == DioExceptionType.cancel) {
        print('🔊 [CLOUD TTS] Request cancelled');
        return false;
      }
      print('🔊 [CLOUD TTS] API error: ${e.message}');
      if (e.response != null) {
        print('🔊 [CLOUD TTS] Response: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      _isSpeaking = false;
      print('🔊 [CLOUD TTS] Error converting text to speech: $e');
      return false;
    }
  }

  /// Play audio bytes.
  /// Creates a fresh AudioPlayer for each playback to avoid web platform issues.
  Future<void> _playAudio(
      Uint8List audioBytes, void Function()? onComplete) async {
    try {
      // Cancel any existing completion listener and dispose old player
      await _playerCompleteSubscription?.cancel();
      _playerCompleteSubscription = null;

      // Dispose old player safely
      try {
        await _audioPlayer?.stop();
        await _audioPlayer?.dispose();
      } catch (e) {
        // Player may already be disposed, ignore
        print('🔊 [CLOUD TTS] Old player cleanup: $e');
      }

      // Create fresh player for this playback (fixes web issues)
      _audioPlayer = AudioPlayer();
      final player = _audioPlayer!;

      // Set up completion listener BEFORE playing
      _playerCompleteSubscription = player.onPlayerComplete.listen((_) {
        print('🔊 [CLOUD TTS] Playback complete');
        _isSpeaking = false;
        _playerCompleteSubscription?.cancel();
        _playerCompleteSubscription = null;
        // Dispose player after completion
        try {
          player.dispose();
        } catch (e) {
          // Ignore disposal errors
        }
        onComplete?.call();
      }, onError: (error) {
        print('🔊 [CLOUD TTS] Audio player error: $error');
        _isSpeaking = false;
        _playerCompleteSubscription?.cancel();
        _playerCompleteSubscription = null;
        // Dispose player on error
        try {
          player.dispose();
        } catch (e) {
          // Ignore disposal errors
        }
        onComplete?.call();
      });

      // Play from bytes
      await player.play(BytesSource(audioBytes));
      print('🔊 [CLOUD TTS] Playback started');
    } catch (e) {
      print('🔊 [CLOUD TTS] Error playing audio: $e');
      _isSpeaking = false;
      _playerCompleteSubscription?.cancel();
      _playerCompleteSubscription = null;
      onComplete?.call();
    }
  }

  /// Convert Bible references to spoken format for natural TTS pronunciation.
  ///
  /// Transforms references like "John 3:16" to "John Chapter 3 verse 16"
  /// and "1 Corinthians 1:1-2" to "First Corinthians Chapter 1 verses 1 to 2".
  /// Supports English, Hindi, and Malayalam localization.
  String _convertBibleReferencesForTTS(String text, String languageCode) {
    // Pattern matches: "Book Chapter:Verse" or "Book Chapter:Verse-Verse"
    // Group 1: Optional number prefix (1, 2, 3 for numbered books)
    // Group 2: Book name (supports English, Hindi, Malayalam characters)
    // Group 3: Chapter number
    // Group 4: Start verse
    // Group 5: End verse (optional, for ranges)
    final bibleRefPattern = RegExp(
      r'(\d)?\s*([A-Za-z\u0900-\u097F\u0D00-\u0D7F]+(?:\s+[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+)*)\s+(\d+):(\d+)(?:-(\d+))?',
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

  /// Sanitize text for TTS.
  String _sanitizeText(String text, {String languageCode = 'en-US'}) {
    // First convert Bible references to spoken format
    final withBibleRefs = _convertBibleReferencesForTTS(text, languageCode);

    return withBibleRefs
        // Keep sentence-ending punctuation for natural pauses
        .replaceAll('!', '.')
        .replaceAll('?', '.')
        // Remove special characters
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        // Remove brackets
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        // Clean up whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Split text into chunks at sentence boundaries.
  /// Target chunk size is ~100-150 words for fast initial response.
  List<String> _splitIntoChunks(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    var currentChunk = StringBuffer();
    var wordCount = 0;
    const targetWords = 100; // Target ~100 words per chunk for fast response

    for (final sentence in sentences) {
      final sentenceWords = sentence.split(RegExp(r'\s+')).length;

      // If adding this sentence exceeds target and we have content, start new chunk
      if (wordCount > 0 && wordCount + sentenceWords > targetWords) {
        chunks.add(currentChunk.toString().trim());
        currentChunk = StringBuffer();
        wordCount = 0;
      }

      if (currentChunk.isNotEmpty) {
        currentChunk.write(' ');
      }
      currentChunk.write(sentence);
      wordCount += sentenceWords;
    }

    // Add remaining content
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }

    return chunks;
  }

  /// Fetch audio for a single chunk from Cloud TTS API.
  Future<Uint8List?> _fetchChunkAudio({
    required String text,
    required _CloudVoice voice,
    required double speakingRate,
    required double pitch,
    CancelToken? cancelToken,
  }) async {
    try {
      final sanitizedText =
          _sanitizeText(text, languageCode: voice.languageCode);
      if (sanitizedText.isEmpty) return null;

      final requestBody = {
        'input': {'text': sanitizedText},
        'voice': {
          'languageCode': voice.languageCode,
          'name': voice.name,
          'ssmlGender': voice.ssmlGender,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': speakingRate.clamp(0.25, 4.0),
          'pitch': pitch.clamp(-20.0, 20.0),
          'effectsProfileId': ['small-bluetooth-speaker-class-device'],
        },
      };

      const apiKey = AppConfig.googleCloudTtsApiKey;
      final response = await _dio.post(
        '$_apiEndpoint?key=$apiKey',
        data: requestBody,
        options: Options(headers: {'Content-Type': 'application/json'}),
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200) return null;

      final dynamic rawAudioContent = response.data['audioContent'];
      if (rawAudioContent == null || rawAudioContent is! String) return null;

      return base64Decode(rawAudioContent);
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        print('🔊 [CLOUD TTS] Chunk fetch error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('🔊 [CLOUD TTS] Chunk fetch error: $e');
      return null;
    }
  }

  /// Speak text using streaming chunked playback for faster start.
  ///
  /// Splits text into chunks, starts playing first chunk immediately,
  /// and pre-fetches subsequent chunks while playing.
  Future<bool> speakStreaming({
    required String text,
    required String languageCode,
    double speakingRate = 1.0,
    double pitch = 0.0,
    void Function()? onComplete,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    // Get voice for language
    var voice = _voiceCache[languageCode];
    if (voice == null) {
      voice = _voiceCache['en-US'];
      if (voice == null) {
        print('🔊 [CLOUD TTS] No voice available for $languageCode');
        return false;
      }
    }

    // Split text into chunks
    final chunks = _splitIntoChunks(text);
    if (chunks.isEmpty) {
      onComplete?.call();
      return true;
    }

    // For very short text (1 chunk), use regular speak
    if (chunks.length == 1) {
      print('🔊 [CLOUD TTS] Short text, using single request');
      return speak(
        text: text,
        languageCode: languageCode,
        speakingRate: speakingRate,
        pitch: pitch,
        onComplete: onComplete,
      );
    }

    print('🔊 [CLOUD TTS] Streaming ${chunks.length} chunks');

    // Reset streaming state
    _audioQueue.clear();
    _currentChunkIndex = 0;
    _totalChunks = chunks.length;
    _isStreaming = true;
    _streamingStopRequested = false;
    _isSpeaking = true;

    // Cancel any previous request
    _currentCancelToken?.cancel('New streaming request');
    _currentCancelToken = CancelToken();

    try {
      // Fetch first chunk and start playing immediately
      print('🔊 [CLOUD TTS] Fetching first chunk...');
      final firstChunkAudio = await _fetchChunkAudio(
        text: chunks[0],
        voice: voice,
        speakingRate: speakingRate,
        pitch: pitch,
        cancelToken: _currentCancelToken,
      );

      if (firstChunkAudio == null || _streamingStopRequested) {
        _resetStreamingState();
        return false;
      }

      // Start pre-fetching remaining chunks in background
      _prefetchChunks(
        chunks: chunks.sublist(1),
        voice: voice,
        speakingRate: speakingRate,
        pitch: pitch,
      );

      // Play chunks sequentially
      await _playChunksSequentially(
        firstChunk: firstChunkAudio,
        onComplete: onComplete,
      );

      return true;
    } catch (e) {
      print('🔊 [CLOUD TTS] Streaming error: $e');
      _resetStreamingState();
      return false;
    }
  }

  /// Pre-fetch remaining chunks in background.
  Future<void> _prefetchChunks({
    required List<String> chunks,
    required _CloudVoice voice,
    required double speakingRate,
    required double pitch,
  }) async {
    for (var i = 0; i < chunks.length; i++) {
      if (_streamingStopRequested) break;

      final audio = await _fetchChunkAudio(
        text: chunks[i],
        voice: voice,
        speakingRate: speakingRate,
        pitch: pitch,
        cancelToken: _currentCancelToken,
      );

      if (audio != null && !_streamingStopRequested) {
        _audioQueue.add(audio);
        print('🔊 [CLOUD TTS] Pre-fetched chunk ${i + 2}/$_totalChunks');

        // Signal if someone is waiting for this chunk
        _nextChunkCompleter?.complete(audio);
        _nextChunkCompleter = null;
      }
    }
  }

  /// Play audio chunks sequentially.
  Future<void> _playChunksSequentially({
    required Uint8List firstChunk,
    void Function()? onComplete,
  }) async {
    var currentAudio = firstChunk;
    _currentChunkIndex = 0;

    while (_currentChunkIndex < _totalChunks && !_streamingStopRequested) {
      print(
          '🔊 [CLOUD TTS] Playing chunk ${_currentChunkIndex + 1}/$_totalChunks');

      // Create completer to wait for playback completion
      final playbackCompleter = Completer<void>();

      // Play current chunk
      await _playAudioChunk(currentAudio, () {
        if (!playbackCompleter.isCompleted) {
          playbackCompleter.complete();
        }
      });

      // Wait for playback to complete
      await playbackCompleter.future;

      if (_streamingStopRequested) break;

      _currentChunkIndex++;

      // Get next chunk if available
      if (_currentChunkIndex < _totalChunks) {
        final queueIndex =
            _currentChunkIndex - 1; // -1 because first chunk wasn't queued

        if (queueIndex < _audioQueue.length) {
          // Chunk already pre-fetched
          currentAudio = _audioQueue[queueIndex];
        } else {
          // Wait for chunk to be fetched
          print(
              '🔊 [CLOUD TTS] Waiting for chunk ${_currentChunkIndex + 1}...');
          _nextChunkCompleter = Completer<Uint8List?>();
          final nextAudio = await _nextChunkCompleter!.future;

          if (nextAudio == null || _streamingStopRequested) break;
          currentAudio = nextAudio;
        }
      }
    }

    _resetStreamingState();
    print('🔊 [CLOUD TTS] Streaming playback complete');
    onComplete?.call();
  }

  /// Play a single audio chunk and wait for completion.
  Future<void> _playAudioChunk(
      Uint8List audioBytes, void Function() onChunkComplete) async {
    try {
      // Cancel any existing completion listener
      await _playerCompleteSubscription?.cancel();
      _playerCompleteSubscription = null;

      // Dispose old player safely
      try {
        await _audioPlayer?.stop();
        await _audioPlayer?.dispose();
      } catch (e) {
        // Ignore
      }

      // Create fresh player
      _audioPlayer = AudioPlayer();
      final player = _audioPlayer!;

      // Set up completion listener
      _playerCompleteSubscription = player.onPlayerComplete.listen((_) {
        _playerCompleteSubscription?.cancel();
        _playerCompleteSubscription = null;
        onChunkComplete();
      }, onError: (error) {
        print('🔊 [CLOUD TTS] Chunk playback error: $error');
        _playerCompleteSubscription?.cancel();
        _playerCompleteSubscription = null;
        onChunkComplete();
      });

      // Play
      await player.play(BytesSource(audioBytes));
    } catch (e) {
      print('🔊 [CLOUD TTS] Error playing chunk: $e');
      onChunkComplete();
    }
  }

  /// Reset streaming state.
  void _resetStreamingState() {
    _isStreaming = false;
    _streamingStopRequested = false;
    _audioQueue.clear();
    _currentChunkIndex = 0;
    _totalChunks = 0;
    _isSpeaking = false;
    _nextChunkCompleter?.complete(null);
    _nextChunkCompleter = null;
  }

  /// Stop current playback.
  Future<void> stop() async {
    // Signal streaming to stop
    if (_isStreaming) {
      _streamingStopRequested = true;
    }

    // Cancel any in-flight API request
    _currentCancelToken?.cancel('Stop requested');
    _currentCancelToken = null;

    // Cancel completion listener
    await _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;

    // Stop and dispose audio player safely
    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (e) {
      // Player may already be disposed
      print('🔊 [CLOUD TTS] Stop cleanup: $e');
    }

    // Reset streaming state
    _resetStreamingState();

    print('🔊 [CLOUD TTS] Playback stopped');
  }

  /// Pause current playback.
  Future<void> pause() async {
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      print('🔊 [CLOUD TTS] Pause error: $e');
    }
  }

  /// Resume paused playback.
  Future<void> resume() async {
    try {
      await _audioPlayer?.resume();
    } catch (e) {
      print('🔊 [CLOUD TTS] Resume error: $e');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _currentCancelToken?.cancel('Dispose');
    _playerCompleteSubscription?.cancel();
    try {
      _audioPlayer?.dispose();
    } catch (e) {
      // Ignore disposal errors
    }
    _audioPlayer = null;
  }
}

/// Internal voice configuration.
class _CloudVoice {
  final String languageCode;
  final String name;
  final String ssmlGender;

  _CloudVoice({
    required this.languageCode,
    required this.name,
    required this.ssmlGender,
  });
}
