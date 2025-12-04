import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service for handling speech-to-text functionality.
///
/// Supports multi-language recognition for English, Hindi, and Malayalam.
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  /// Whether the service is currently listening.
  bool get isListening => _speechToText.isListening;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether speech recognition is available on the device.
  bool get isAvailable => _speechToText.isAvailable;

  /// Initialize the speech recognition service.
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          // Log error but don't throw - let caller handle via result
          print('🎙️ [SPEECH] Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          // Status updates: listening, notListening, done
          print('🎙️ [SPEECH] Status changed: $status');
          _onStatusChange?.call(status);
        },
      );

      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Get list of available locales for speech recognition.
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }

  /// Check if a specific language is supported.
  Future<bool> isLanguageSupported(String languageCode) async {
    final locales = await getAvailableLocales();
    return locales.any((locale) => locale.localeId == languageCode);
  }

  /// Callback for status changes (listening, notListening, done)
  void Function(String status)? _onStatusChange;

  /// Start listening for speech input.
  ///
  /// [languageCode] - The language to recognize (e.g., 'en-US', 'hi-IN', 'ml-IN')
  /// [onResult] - Callback for recognition results
  /// [onSoundLevelChange] - Optional callback for sound level (for waveform visualization)
  /// [onStatusChange] - Optional callback for status changes (listening, notListening, done)
  /// [pauseFor] - Duration of silence before automatically stopping (default 10 seconds)
  /// [listenFor] - Maximum duration to listen (default 60 seconds)
  Future<void> startListening({
    required String languageCode,
    required void Function(SpeechRecognitionResult result) onResult,
    void Function(double level)? onSoundLevelChange,
    void Function(String status)? onStatusChange,
    Duration pauseFor = const Duration(seconds: 60),
    Duration listenFor = const Duration(seconds: 60),
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        throw SpeechServiceException('Failed to initialize speech recognition');
      }
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    // Store the status callback for use in initialize's onStatus
    _onStatusChange = onStatusChange;

    await _speechToText.listen(
      onResult: onResult,
      localeId: languageCode,
      pauseFor: pauseFor,
      listenFor: listenFor,
      partialResults: partialResults,
      onSoundLevelChange: onSoundLevelChange,
    );
  }

  /// Stop listening for speech input.
  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  /// Cancel the current listening session without processing.
  Future<void> cancelListening() async {
    await _speechToText.cancel();
  }

  /// Dispose of the service resources.
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.cancel();
    }
  }
}

/// Exception thrown by SpeechService.
class SpeechServiceException implements Exception {
  final String message;

  SpeechServiceException(this.message);

  @override
  String toString() => 'SpeechServiceException: $message';
}

/// Result of a speech recognition operation.
class SpeechResult {
  final String text;
  final double confidence;
  final String languageCode;
  final bool isFinal;

  SpeechResult({
    required this.text,
    required this.confidence,
    required this.languageCode,
    required this.isFinal,
  });

  factory SpeechResult.fromRecognitionResult(
    SpeechRecognitionResult result,
    String languageCode,
  ) {
    return SpeechResult(
      text: result.recognizedWords,
      confidence: result.confidence,
      languageCode: languageCode,
      isFinal: result.finalResult,
    );
  }
}

/// Language codes supported by the voice buddy feature.
class SupportedLanguages {
  static const String english = 'en-US';
  static const String hindi = 'hi-IN';
  static const String malayalam = 'ml-IN';

  static const List<String> all = [english, hindi, malayalam];

  /// Get display name for a language code.
  static String getDisplayName(String code) {
    switch (code) {
      case english:
        return 'English';
      case hindi:
        return '\u0939\u093F\u0928\u094D\u0926\u0940'; // हिन्दी
      case malayalam:
        return '\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02'; // മലയാളം
      default:
        return code;
    }
  }

  /// Get flag emoji for a language code.
  static String getFlag(String code) {
    switch (code) {
      case english:
        return '\u{1F1FA}\u{1F1F8}'; // 🇺🇸
      case hindi:
      case malayalam:
        return '\u{1F1EE}\u{1F1F3}'; // 🇮🇳
      default:
        return '\u{1F30D}'; // 🌍
    }
  }
}
