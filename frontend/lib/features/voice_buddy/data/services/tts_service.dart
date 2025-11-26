import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// Service for handling text-to-speech functionality.
///
/// Supports multi-language synthesis for English, Hindi, and Malayalam.
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  TtsState _currentState = TtsState.stopped;
  bool _isIntentionallyStopping = false;

  /// Current state of TTS playback.
  TtsState get currentState => _currentState;

  /// Whether TTS is currently speaking.
  bool get isSpeaking => _currentState == TtsState.playing;

  /// Initialize the TTS service with default settings.
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔊 [TTS] Already initialized');
      return;
    }

    print('🔊 [TTS] Initializing TTS service...');

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

  /// Sanitize text for TTS to prevent reading punctuation as words.
  String _sanitizeTextForTTS(String text) {
    // Remove or replace punctuation that TTS might read literally
    final sanitized = text
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

    if (!_isInitialized) {
      print('🔊 [TTS] Initializing TTS service...');
      await initialize();
    }

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
    await _flutterTts.stop();
    _currentState = TtsState.stopped;
  }

  /// Pause speaking (iOS only).
  Future<void> pause() async {
    await _flutterTts.pause();
    _currentState = TtsState.paused;
  }

  /// Dispose of the service resources.
  void dispose() {
    stop();
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
