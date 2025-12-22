import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../voice_buddy/data/services/tts_service.dart';
import '../../domain/entities/study_guide.dart';

/// Represents a section of the study guide for TTS reading.
class TtsSection {
  final String title;
  final String content;
  final StudyGuideSection section;

  const TtsSection({
    required this.title,
    required this.content,
    required this.section,
  });

  /// Get the full text to be read (title + content).
  String get fullText => '$title.\n$content';
}

/// Enum representing study guide sections.
enum StudyGuideSection {
  summary,
  interpretation,
  context,
  relatedVerses,
  discussionQuestions,
  prayerPoints,
}

/// Status of TTS playback.
enum TtsStatus {
  idle,
  loading,
  playing,
  paused,
  error,
}

/// State class for TTS playback.
class StudyGuideTtsState {
  final TtsStatus status;
  final int currentSectionIndex;
  final String currentSectionName;
  final double speechRate;
  final String? error;

  /// Progress within current section (0.0 to 1.0)
  final double sectionProgress;

  /// Estimated duration of current section in seconds
  final int estimatedDurationSeconds;

  /// Elapsed time in current section in seconds
  final int elapsedSeconds;

  const StudyGuideTtsState({
    this.status = TtsStatus.idle,
    this.currentSectionIndex = 0,
    this.currentSectionName = '',
    this.speechRate = 1.0,
    this.error,
    this.sectionProgress = 0.0,
    this.estimatedDurationSeconds = 0,
    this.elapsedSeconds = 0,
  });

  StudyGuideTtsState copyWith({
    TtsStatus? status,
    int? currentSectionIndex,
    String? currentSectionName,
    double? speechRate,
    String? error,
    double? sectionProgress,
    int? estimatedDurationSeconds,
    int? elapsedSeconds,
  }) {
    return StudyGuideTtsState(
      status: status ?? this.status,
      currentSectionIndex: currentSectionIndex ?? this.currentSectionIndex,
      currentSectionName: currentSectionName ?? this.currentSectionName,
      speechRate: speechRate ?? this.speechRate,
      error: error,
      sectionProgress: sectionProgress ?? this.sectionProgress,
      estimatedDurationSeconds:
          estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  @override
  String toString() =>
      'StudyGuideTtsState(status: $status, section: $currentSectionIndex, progress: ${(sectionProgress * 100).toInt()}%, rate: $speechRate)';
}

/// Service for reading study guides aloud using TTS.
///
/// Wraps the existing [TTSService] to provide study guide-specific
/// functionality including section-by-section reading, speed control,
/// and progress tracking.
class StudyGuideTTSService {
  final TTSService _ttsService;
  final SharedPreferences _prefs;

  static const String _speechRateKey = 'study_guide_tts_speed';
  static const double _defaultSpeechRate = 1.0;

  /// State notifier for reactive UI updates.
  final ValueNotifier<StudyGuideTtsState> state;

  /// Current study guide being read.
  StudyGuide? _currentGuide;

  /// Prepared sections for TTS.
  List<TtsSection> _sections = [];

  /// Current section index.
  int _currentSectionIndex = 0;

  /// Whether we're intentionally stopping (to avoid error callbacks).
  bool _isIntentionallyStopping = false;

  /// Timer for updating progress within a section.
  Timer? _progressTimer;

  /// Timestamp when current section started playing.
  DateTime? _sectionStartTime;

  /// Estimated duration of current section in seconds.
  // ignore: prefer_final_fields
  int _currentSectionDuration = 0;

  /// Average words per minute for TTS (at 1.0x speed).
  /// This is an approximation - actual speed varies by language and voice.
  static const int _baseWordsPerMinute = 150;

  StudyGuideTTSService({
    required TTSService ttsService,
    required SharedPreferences prefs,
  })  : _ttsService = ttsService,
        _prefs = prefs,
        state = ValueNotifier(StudyGuideTtsState(
          speechRate: prefs.getDouble(_speechRateKey) ?? _defaultSpeechRate,
        ));

  /// Get the current speech rate.
  double get speechRate => state.value.speechRate;

  /// Get the total number of sections.
  int get totalSections => _sections.length;

  /// Get all section names for the current guide.
  List<String> get sectionNames => _sections.map((s) => s.title).toList();

  /// Estimate duration in seconds for given text at current speech rate.
  int _estimateDuration(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final wordsPerMinute =
        (_baseWordsPerMinute * state.value.speechRate).round();
    final seconds = (wordCount / wordsPerMinute * 60).round();
    return seconds.clamp(1, 600); // At least 1 second, max 10 minutes
  }

  /// Start the progress timer for tracking playback position.
  void _startProgressTimer() {
    _stopProgressTimer();
    _sectionStartTime = DateTime.now();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (state.value.status != TtsStatus.playing) return;

      final elapsed = DateTime.now().difference(_sectionStartTime!).inSeconds;
      final progress = _currentSectionDuration > 0
          ? (elapsed / _currentSectionDuration).clamp(0.0, 1.0)
          : 0.0;

      state.value = state.value.copyWith(
        sectionProgress: progress,
        elapsedSeconds: elapsed,
      );
    });
  }

  /// Stop the progress timer.
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Reset progress state.
  void _resetProgress() {
    _stopProgressTimer();
    _sectionStartTime = null;
    _currentSectionDuration = 0;
  }

  /// Get the language code for TTS based on study guide language.
  String _getLanguageCode(String guideLanguage) {
    switch (guideLanguage.toLowerCase()) {
      case 'en':
      case 'english':
        return 'en-US';
      case 'hi':
      case 'hindi':
        return 'hi-IN';
      case 'ml':
      case 'malayalam':
        return 'ml-IN';
      default:
        return 'en-US';
    }
  }

  /// Get localized section titles based on language.
  Map<StudyGuideSection, String> _getLocalizedSectionTitles(String language) {
    switch (language.toLowerCase()) {
      case 'hi':
      case 'hindi':
        return {
          StudyGuideSection.summary: 'सारांश',
          StudyGuideSection.interpretation: 'व्याख्या',
          StudyGuideSection.context: 'पृष्ठभूमि',
          StudyGuideSection.relatedVerses: 'संबंधित आयतें',
          StudyGuideSection.discussionQuestions: 'सवाल',
          StudyGuideSection.prayerPoints: 'प्रार्थना विषय',
        };
      case 'ml':
      case 'malayalam':
        return {
          StudyGuideSection.summary: 'സംഗ്രഹം',
          StudyGuideSection.interpretation: 'വ്യാഖ്യാനം',
          StudyGuideSection.context: 'പശ്ചാത്തലം',
          StudyGuideSection.relatedVerses: 'മറ്റ് വചനങ്ങൾ',
          StudyGuideSection.discussionQuestions: 'ചോദ്യങ്ങൾ',
          StudyGuideSection.prayerPoints: 'പ്രാർത്ഥന',
        };
      case 'en':
      case 'english':
      default:
        return {
          StudyGuideSection.summary: 'Summary',
          StudyGuideSection.interpretation: 'Interpretation',
          StudyGuideSection.context: 'Context',
          StudyGuideSection.relatedVerses: 'Related Verses',
          StudyGuideSection.discussionQuestions: 'Discussion Questions',
          StudyGuideSection.prayerPoints: 'Prayer Points',
        };
    }
  }

  /// Get localized "Question" label for numbering.
  String _getLocalizedQuestionLabel(String language, int number) {
    switch (language.toLowerCase()) {
      case 'hi':
      case 'hindi':
        return 'सवाल $number';
      case 'ml':
      case 'malayalam':
        return 'ചോദ്യം $number';
      case 'en':
      case 'english':
      default:
        return 'Question $number';
    }
  }

  /// Prepare sections from a study guide.
  List<TtsSection> _prepareSections(StudyGuide guide) {
    final titles = _getLocalizedSectionTitles(guide.language);
    final language = guide.language;

    return [
      TtsSection(
        title: titles[StudyGuideSection.summary]!,
        content: guide.summary,
        section: StudyGuideSection.summary,
      ),
      TtsSection(
        title: titles[StudyGuideSection.interpretation]!,
        content: guide.interpretation,
        section: StudyGuideSection.interpretation,
      ),
      TtsSection(
        title: titles[StudyGuideSection.context]!,
        content: guide.context,
        section: StudyGuideSection.context,
      ),
      TtsSection(
        title: titles[StudyGuideSection.relatedVerses]!,
        content: guide.relatedVerses.join('. '),
        section: StudyGuideSection.relatedVerses,
      ),
      TtsSection(
        title: titles[StudyGuideSection.discussionQuestions]!,
        content: guide.reflectionQuestions
            .asMap()
            .entries
            .map((e) =>
                '${_getLocalizedQuestionLabel(language, e.key + 1)}. ${e.value}')
            .join('. '),
        section: StudyGuideSection.discussionQuestions,
      ),
      TtsSection(
        title: titles[StudyGuideSection.prayerPoints]!,
        content: guide.prayerPoints.join('. '),
        section: StudyGuideSection.prayerPoints,
      ),
    ];
  }

  /// Start reading a study guide from the beginning.
  Future<void> startReading(StudyGuide guide) async {
    print('🔊 [StudyGuideTTS] Starting to read guide: ${guide.input}');

    // Stop any current playback
    if (state.value.status == TtsStatus.playing ||
        state.value.status == TtsStatus.paused) {
      await stop();
    }

    _currentGuide = guide;
    _sections = _prepareSections(guide);
    _currentSectionIndex = 0;

    state.value = state.value.copyWith(
      status: TtsStatus.loading,
      currentSectionIndex: 0,
      currentSectionName: _sections.isNotEmpty ? _sections[0].title : '',
    );

    // Initialize TTS if needed
    await _ttsService.initialize();

    // Start reading first section
    await _readCurrentSection();
  }

  /// Read the current section.
  Future<void> _readCurrentSection() async {
    if (_currentSectionIndex >= _sections.length) {
      // All sections read
      print('🔊 [StudyGuideTTS] All sections completed');
      _resetProgress();
      state.value = state.value.copyWith(
        status: TtsStatus.idle,
        currentSectionIndex: 0,
        currentSectionName: '',
        sectionProgress: 0.0,
        estimatedDurationSeconds: 0,
        elapsedSeconds: 0,
      );
      _currentGuide = null;
      return;
    }

    final section = _sections[_currentSectionIndex];
    final languageCode = _getLanguageCode(_currentGuide?.language ?? 'en');

    // Estimate duration for progress tracking
    _currentSectionDuration = _estimateDuration(section.fullText);

    print(
        '🔊 [StudyGuideTTS] Reading section ${_currentSectionIndex + 1}/${_sections.length}: ${section.title} (est. ${_currentSectionDuration}s)');

    state.value = state.value.copyWith(
      status: TtsStatus.playing,
      currentSectionIndex: _currentSectionIndex,
      currentSectionName: section.title,
      sectionProgress: 0.0,
      estimatedDurationSeconds: _currentSectionDuration,
      elapsedSeconds: 0,
    );

    // Start progress tracking
    _startProgressTimer();

    try {
      // Define the completion callback
      void onSectionComplete() {
        print(
            '🔊 [StudyGuideTTS] ========== COMPLETION CALLBACK FIRED ==========');
        print(
            '🔊 [StudyGuideTTS] Section ${_currentSectionIndex + 1} completed');
        print(
            '🔊 [StudyGuideTTS] State: ${state.value.status}, intentionalStop: $_isIntentionallyStopping');

        // Stop progress timer since section is done
        _stopProgressTimer();

        // Check current state FIRST - if paused or idle, don't auto-advance
        // This prevents race conditions where the flag might be reset
        final currentStatus = state.value.status;
        if (currentStatus == TtsStatus.paused ||
            currentStatus == TtsStatus.idle) {
          print('🔊 [StudyGuideTTS] Status is $currentStatus - not advancing');
          return;
        }

        // Check if we're intentionally stopping (backup check)
        if (_isIntentionallyStopping) {
          print('🔊 [StudyGuideTTS] Intentional stop flag set - not advancing');
          return;
        }

        // Only advance if we're still in playing state
        if (currentStatus == TtsStatus.playing) {
          // Move to next section
          _currentSectionIndex++;
          print(
              '🔊 [StudyGuideTTS] Advancing to section $_currentSectionIndex');
          _readCurrentSection();
        }
      }

      print(
          '🔊 [StudyGuideTTS] Calling speakWithSettings for section: ${section.title}');
      await _ttsService.speakWithSettings(
        text: section.fullText,
        languageCode: languageCode,
        speakingRate: state.value.speechRate,
        onComplete: onSectionComplete,
      );
      print('🔊 [StudyGuideTTS] speakWithSettings returned');
    } catch (e) {
      print('🔊 [StudyGuideTTS] Error reading section: $e');
      state.value = state.value.copyWith(
        status: TtsStatus.error,
        error: 'Failed to read study guide. Please try again.',
      );
    }
  }

  /// Toggle between play and pause.
  Future<void> togglePlayPause() async {
    final currentStatus = state.value.status;

    if (currentStatus == TtsStatus.playing) {
      await pause();
    } else if (currentStatus == TtsStatus.paused) {
      await resume();
    } else if (currentStatus == TtsStatus.idle && _currentGuide != null) {
      // Resume from where we left off or start fresh
      await _readCurrentSection();
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    print('🔊 [StudyGuideTTS] Pausing');
    // Stop progress timer
    _stopProgressTimer();
    // Set flag and state BEFORE stopping to prevent race conditions
    // The completion callback checks both the flag and state
    _isIntentionallyStopping = true;
    state.value = state.value.copyWith(status: TtsStatus.paused);
    await _ttsService.stop();
  }

  /// Resume playback.
  Future<void> resume() async {
    print('🔊 [StudyGuideTTS] Resuming from section $_currentSectionIndex');
    // Clear the intentional stop flag since we're intentionally resuming
    _isIntentionallyStopping = false;
    // Note: _readCurrentSection will restart progress from 0
    // This is acceptable since we can't seek within TTS audio
    await _readCurrentSection();
  }

  /// Stop playback completely.
  Future<void> stop() async {
    print('🔊 [StudyGuideTTS] Stopping');
    _resetProgress();
    _isIntentionallyStopping = true;
    await _ttsService.stop();
    _currentSectionIndex = 0;
    state.value = state.value.copyWith(
      status: TtsStatus.idle,
      currentSectionIndex: 0,
      currentSectionName: '',
      sectionProgress: 0.0,
      estimatedDurationSeconds: 0,
      elapsedSeconds: 0,
    );
  }

  /// Skip to a specific section.
  Future<void> skipToSection(int index) async {
    if (index < 0 || index >= _sections.length) return;

    print('🔊 [StudyGuideTTS] Skipping to section $index');

    // Stop current playback and progress
    _stopProgressTimer();
    _isIntentionallyStopping = true;
    await _ttsService.stop();

    _currentSectionIndex = index;
    await _readCurrentSection();
  }

  /// Skip to next section.
  Future<void> skipToNextSection() async {
    if (_currentSectionIndex < _sections.length - 1) {
      await skipToSection(_currentSectionIndex + 1);
    }
  }

  /// Skip to previous section.
  Future<void> skipToPreviousSection() async {
    if (_currentSectionIndex > 0) {
      await skipToSection(_currentSectionIndex - 1);
    }
  }

  /// Set the speech rate (0.5 to 2.0).
  Future<void> setSpeechRate(double rate) async {
    final double clampedRate = rate.clamp(0.5, 2.0).toDouble();
    print('🔊 [StudyGuideTTS] Setting speech rate to $clampedRate');

    // Persist to SharedPreferences
    await _prefs.setDouble(_speechRateKey, clampedRate);

    state.value = state.value.copyWith(speechRate: clampedRate);

    // If currently playing, restart current section with new rate
    if (state.value.status == TtsStatus.playing) {
      _isIntentionallyStopping = true;
      await _ttsService.stop();
      _isIntentionallyStopping = false; // Clear flag before restarting
      await _readCurrentSection();
    }
  }

  /// Check if a guide is currently loaded.
  bool get hasGuide => _currentGuide != null;

  /// Clean up resources.
  Future<void> dispose() async {
    await stop();
    state.dispose();
  }
}
