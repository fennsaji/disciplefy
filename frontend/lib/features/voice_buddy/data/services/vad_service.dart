import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

/// Voice Activity Detection (VAD) Service
///
/// Provides intelligent silence detection for continuous voice conversations.
/// Uses sound level monitoring, adaptive thresholds, and debouncing for
/// accurate speech endpoint detection.
class VADService {
  VADService({
    this.silenceThresholdMs = 3000,
    this.minSpeechDurationMs = 400,
    this.minConfidence = 0.5,
    this.calibrationDurationMs = 1000,
    this.soundLevelWindowSize = 10,
    this.silenceLevelThreshold = -40.0,
    this.minTextLengthForSend = 2,
  });

  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Duration of silence before triggering send (milliseconds)
  final int silenceThresholdMs;

  /// Minimum speech duration before considering it complete (milliseconds)
  final int minSpeechDurationMs;

  /// Minimum confidence score to accept transcription (0.0 - 1.0)
  final double minConfidence;

  /// Duration for ambient noise calibration (milliseconds)
  final int calibrationDurationMs;

  /// Number of sound level samples to average
  final int soundLevelWindowSize;

  /// Sound level (dB) below which is considered silence
  /// speech_to_text typically returns -160 to 10 dB range
  final double silenceLevelThreshold;

  /// Minimum text length required before sending
  final int minTextLengthForSend;

  // ============================================================
  // STATE
  // ============================================================

  /// Rolling window of recent sound levels
  final Queue<double> _soundLevelHistory = Queue<double>();

  /// Time when speech started
  DateTime? _speechStartTime;

  /// Last time we received active speech (sound above threshold)
  DateTime? _lastActiveTime;

  /// Current silence duration tracker
  Timer? _silenceTimer;

  /// Calibration timer (to cancel on stop)
  Timer? _calibrationTimer;

  /// Whether VAD is currently active
  bool _isActive = false;

  /// Calibrated ambient noise level
  double _ambientNoiseLevel = -50.0;

  /// Is currently in calibration mode
  bool _isCalibrating = false;

  /// Calibration samples
  final List<double> _calibrationSamples = [];

  /// Last transcription text (for debouncing)
  String _lastTranscription = '';

  /// Callback when silence is detected (ready to send)
  void Function(String text, double confidence)? onSilenceDetected;

  /// Callback for VAD state changes
  void Function(VADState state)? onStateChanged;

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// Start VAD monitoring with optional calibration
  void start({bool calibrate = true}) {
    _isActive = true;
    _soundLevelHistory.clear();
    _speechStartTime = null;
    _lastActiveTime = null;
    _lastTranscription = '';
    _silenceTimer?.cancel();
    _calibrationTimer?.cancel();

    if (calibrate) {
      // _startCalibration emits calibrating, then _endCalibration emits listening
      _startCalibration();
    } else {
      // No calibration - go directly to listening state
      _emitState(VADState.listening);
    }
  }

  /// Stop VAD monitoring
  void stop() {
    _isActive = false;
    _isCalibrating = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    _calibrationSamples.clear();
    _emitState(VADState.stopped);
  }

  /// Process incoming sound level from speech recognition
  ///
  /// [level] - Sound level in dB (typically -160 to 10)
  void processSoundLevel(double level) {
    if (!_isActive) return;

    // Add to history, maintain window size
    _soundLevelHistory.addLast(level);
    while (_soundLevelHistory.length > soundLevelWindowSize) {
      _soundLevelHistory.removeFirst();
    }

    // Calibration mode - collect ambient noise samples
    if (_isCalibrating) {
      _calibrationSamples.add(level);
      return;
    }

    // Calculate smoothed level (average of window)
    final smoothedLevel = _calculateSmoothedLevel();

    // Determine if this is speech or silence
    final dynamicThreshold = _calculateDynamicThreshold();
    final isSpeech = smoothedLevel > dynamicThreshold;

    if (isSpeech) {
      _onSpeechDetected();
    } else {
      _onSilenceDetected();
    }
  }

  /// Process transcription update from speech recognition
  ///
  /// [text] - Current transcription
  /// [confidence] - Recognition confidence (0.0 - 1.0)
  /// [isFinal] - Whether this is a final result
  void processTranscription(String text, double confidence, bool isFinal) {
    if (!_isActive) return;

    // Final results always reset state for next utterance
    if (isFinal) {
      _lastTranscription = '';
      _speechStartTime = null;
      return;
    }

    // Debounce: Only reset silence timer if text changed significantly
    final textChanged = _hasSignificantTextChange(text);

    if (textChanged && text.isNotEmpty) {
      // New speech detected via text change
      _speechStartTime ??= DateTime.now();
      _lastActiveTime = DateTime.now();
      _lastTranscription = text;

      // Reset silence timer since we have new speech
      _resetSilenceTimer(text, confidence);
    }
  }

  /// Force check if ready to send based on current state
  bool isReadyToSend(String text, double confidence) {
    // Check minimum text length
    if (text.trim().length < minTextLengthForSend) {
      return false;
    }

    // Check minimum confidence
    if (confidence < minConfidence && confidence > 0) {
      return false;
    }

    // Check minimum speech duration
    if (_speechStartTime != null) {
      final speechDuration = DateTime.now().difference(_speechStartTime!);
      if (speechDuration.inMilliseconds < minSpeechDurationMs) {
        return false;
      }
    }

    return true;
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }

  // ============================================================
  // PRIVATE METHODS
  // ============================================================

  void _startCalibration() {
    _isCalibrating = true;
    _calibrationSamples.clear();
    _emitState(VADState.calibrating);

    // End calibration after specified duration
    // Store timer handle so it can be cancelled on stop()
    _calibrationTimer =
        Timer(Duration(milliseconds: calibrationDurationMs), () {
      // Guard: only proceed if VAD is still active (not stopped during calibration)
      if (_isActive) {
        _endCalibration();
      }
    });
  }

  void _endCalibration() {
    _isCalibrating = false;

    if (_calibrationSamples.isNotEmpty) {
      // Calculate ambient noise level as median of samples
      final sorted = List<double>.from(_calibrationSamples)..sort();
      final medianIndex = sorted.length ~/ 2;
      _ambientNoiseLevel = sorted[medianIndex];

      // Add small buffer above ambient for dynamic threshold
      _ambientNoiseLevel =
          math.min(_ambientNoiseLevel + 5, silenceLevelThreshold);
    }

    _calibrationSamples.clear();
    _emitState(VADState.listening);
  }

  double _calculateSmoothedLevel() {
    if (_soundLevelHistory.isEmpty) return silenceLevelThreshold;

    final sum = _soundLevelHistory.reduce((a, b) => a + b);
    return sum / _soundLevelHistory.length;
  }

  double _calculateDynamicThreshold() {
    // Use calibrated ambient noise level + buffer, capped by configured threshold
    return math.max(_ambientNoiseLevel + 10, silenceLevelThreshold);
  }

  void _onSpeechDetected() {
    _speechStartTime ??= DateTime.now();
    _lastActiveTime = DateTime.now();
    _emitState(VADState.speaking);
  }

  void _onSilenceDetected() {
    // Only care about silence if we've had some speech
    if (_speechStartTime == null) return;

    // Check if we've been silent long enough
    if (_lastActiveTime != null) {
      final silenceDuration = DateTime.now().difference(_lastActiveTime!);
      if (silenceDuration.inMilliseconds > silenceThresholdMs) {
        _emitState(VADState.silenceDetected);
      }
    }
  }

  bool _hasSignificantTextChange(String newText) {
    // No previous text - any text is significant
    if (_lastTranscription.isEmpty) return newText.isNotEmpty;

    // Calculate difference
    final oldLen = _lastTranscription.length;
    final newLen = newText.length;

    // Significant if:
    // 1. Text grew by more than 2 characters (new words)
    // 2. Text content changed substantially (not just minor corrections)
    if (newLen > oldLen + 2) return true;

    // Check if the start differs (indicates correction)
    // Guard against negative/zero end index for short transcriptions
    final substringEnd = math.min(math.max(0, oldLen - 3), newLen);
    if (substringEnd > 0 &&
        !newText.startsWith(_lastTranscription.substring(0, substringEnd))) {
      // Allow minor end corrections without resetting
      return newLen > oldLen;
    }

    return false;
  }

  void _resetSilenceTimer(String text, double confidence) {
    _silenceTimer?.cancel();

    _silenceTimer = Timer(Duration(milliseconds: silenceThresholdMs), () {
      if (_isActive && isReadyToSend(text, confidence)) {
        _emitState(VADState.silenceDetected);
        onSilenceDetected?.call(text, confidence);
      }
    });
  }

  void _emitState(VADState state) {
    onStateChanged?.call(state);
  }
}

/// VAD state enumeration
enum VADState {
  /// VAD is stopped/inactive
  stopped,

  /// Calibrating ambient noise levels
  calibrating,

  /// Listening but no speech detected yet
  listening,

  /// Active speech detected
  speaking,

  /// Silence detected after speech (ready to send)
  silenceDetected,
}

/// Configuration for VAD behavior
class VADConfig {
  const VADConfig({
    this.silenceThresholdMs = 3000,
    this.minSpeechDurationMs = 400,
    this.minConfidence = 0.5,
    this.calibrationDurationMs = 1000,
    this.silenceLevelThreshold = -40.0,
    this.minTextLength = 2,
  });

  /// Default configuration for voice buddy
  static const defaultConfig = VADConfig();

  /// More aggressive (faster send) configuration
  static const fastConfig = VADConfig(
    silenceThresholdMs: 800,
    minSpeechDurationMs: 300,
    minConfidence: 0.4,
  );

  /// More conservative (wait longer) configuration
  static const slowConfig = VADConfig(
    silenceThresholdMs: 2000,
    minSpeechDurationMs: 600,
    minConfidence: 0.6,
  );

  final int silenceThresholdMs;
  final int minSpeechDurationMs;
  final double minConfidence;
  final int calibrationDurationMs;
  final double silenceLevelThreshold;
  final int minTextLength;

  VADService createService() {
    return VADService(
      silenceThresholdMs: silenceThresholdMs,
      minSpeechDurationMs: minSpeechDurationMs,
      minConfidence: minConfidence,
      calibrationDurationMs: calibrationDurationMs,
      silenceLevelThreshold: silenceLevelThreshold,
      minTextLengthForSend: minTextLength,
    );
  }
}
