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

  const StudyGuideTtsState({
    this.status = TtsStatus.idle,
    this.currentSectionIndex = 0,
    this.currentSectionName = '',
    this.speechRate = 1.0,
    this.error,
  });

  StudyGuideTtsState copyWith({
    TtsStatus? status,
    int? currentSectionIndex,
    String? currentSectionName,
    double? speechRate,
    String? error,
  }) {
    return StudyGuideTtsState(
      status: status ?? this.status,
      currentSectionIndex: currentSectionIndex ?? this.currentSectionIndex,
      currentSectionName: currentSectionName ?? this.currentSectionName,
      speechRate: speechRate ?? this.speechRate,
      error: error,
    );
  }

  @override
  String toString() =>
      'StudyGuideTtsState(status: $status, section: $currentSectionIndex, rate: $speechRate)';
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

  /// Prepare sections from a study guide.
  List<TtsSection> _prepareSections(StudyGuide guide) {
    return [
      TtsSection(
        title: 'Summary',
        content: guide.summary,
        section: StudyGuideSection.summary,
      ),
      TtsSection(
        title: 'Interpretation',
        content: guide.interpretation,
        section: StudyGuideSection.interpretation,
      ),
      TtsSection(
        title: 'Context',
        content: guide.context,
        section: StudyGuideSection.context,
      ),
      TtsSection(
        title: 'Related Verses',
        content: guide.relatedVerses.join('. '),
        section: StudyGuideSection.relatedVerses,
      ),
      TtsSection(
        title: 'Discussion Questions',
        content: guide.reflectionQuestions
            .asMap()
            .entries
            .map((e) => 'Question ${e.key + 1}. ${e.value}')
            .join('. '),
        section: StudyGuideSection.discussionQuestions,
      ),
      TtsSection(
        title: 'Prayer Points',
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
      state.value = state.value.copyWith(
        status: TtsStatus.idle,
        currentSectionIndex: 0,
        currentSectionName: '',
      );
      return;
    }

    final section = _sections[_currentSectionIndex];
    final languageCode = _getLanguageCode(_currentGuide?.language ?? 'en');

    print(
        '🔊 [StudyGuideTTS] Reading section ${_currentSectionIndex + 1}/${_sections.length}: ${section.title}');

    state.value = state.value.copyWith(
      status: TtsStatus.playing,
      currentSectionIndex: _currentSectionIndex,
      currentSectionName: section.title,
    );

    try {
      await _ttsService.speakWithSettings(
        text: section.fullText,
        languageCode: languageCode,
        speakingRate: state.value.speechRate,
        onComplete: () {
          if (_isIntentionallyStopping) {
            _isIntentionallyStopping = false;
            return;
          }
          // Move to next section
          _currentSectionIndex++;
          _readCurrentSection();
        },
      );
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
    _isIntentionallyStopping = true;
    await _ttsService.stop();
    state.value = state.value.copyWith(status: TtsStatus.paused);
  }

  /// Resume playback.
  Future<void> resume() async {
    print('🔊 [StudyGuideTTS] Resuming from section $_currentSectionIndex');
    await _readCurrentSection();
  }

  /// Stop playback completely.
  Future<void> stop() async {
    print('🔊 [StudyGuideTTS] Stopping');
    _isIntentionallyStopping = true;
    await _ttsService.stop();
    _currentSectionIndex = 0;
    state.value = state.value.copyWith(
      status: TtsStatus.idle,
      currentSectionIndex: 0,
      currentSectionName: '',
    );
  }

  /// Skip to a specific section.
  Future<void> skipToSection(int index) async {
    if (index < 0 || index >= _sections.length) return;

    print('🔊 [StudyGuideTTS] Skipping to section $index');

    // Stop current playback
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
    final clampedRate = rate.clamp(0.5, 2.0);
    print('🔊 [StudyGuideTTS] Setting speech rate to $clampedRate');

    // Persist to SharedPreferences
    await _prefs.setDouble(_speechRateKey, clampedRate);

    state.value = state.value.copyWith(speechRate: clampedRate);

    // If currently playing, restart current section with new rate
    if (state.value.status == TtsStatus.playing) {
      _isIntentionallyStopping = true;
      await _ttsService.stop();
      await _readCurrentSection();
    }
  }

  /// Check if a guide is currently loaded.
  bool get hasGuide => _currentGuide != null;

  /// Clean up resources.
  void dispose() {
    stop();
    state.dispose();
  }
}
