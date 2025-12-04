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

      // Sanitize text
      final sanitizedText = _sanitizeText(text);

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

  /// Sanitize text for TTS.
  String _sanitizeText(String text) {
    return text
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

  /// Stop current playback.
  Future<void> stop() async {
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
    _isSpeaking = false;
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
