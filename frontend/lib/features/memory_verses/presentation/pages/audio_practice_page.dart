import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_result_params.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../utils/quality_calculator.dart';
import '../widgets/timer_badge.dart';
import '../../../voice_buddy/data/services/tts_service.dart';
import '../../../voice_buddy/data/services/speech_service.dart';

/// Audio Practice Page for Memory Verses.
///
/// Two-phase practice mode:
/// 1. **Listening Phase**: User listens to the verse via TTS
/// 2. **Speaking Phase**: User speaks the verse, speech-to-text compares to original
///
/// Scoring based on transcription accuracy compared to original verse text.
class AudioPracticePage extends StatefulWidget {
  final String verseId;

  const AudioPracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<AudioPracticePage> createState() => _AudioPracticePageState();
}

class _AudioPracticePageState extends State<AudioPracticePage> {
  // Verse data
  MemoryVerseEntity? currentVerse;

  // Services
  final TTSService _ttsService = TTSService();
  final SpeechService _speechService = SpeechService();

  // Phase management
  AudioPhase _currentPhase = AudioPhase.listening;

  // Listening phase state
  double _playbackSpeed = 1.0;
  int _timesPlayed = 0;
  bool _isPlaying = false;

  // Speaking phase state
  bool _isRecording = false;
  String _recognizedText = '';
  double _soundLevel = 0.0;
  bool _hasRecorded = false;

  // Results
  double _accuracyPercentage = 0.0;
  List<WordComparison> _wordComparisons = [];

  // Practice tracking
  Timer? _practiceTimer;
  int _elapsedSeconds = 0;
  int _hintsUsed = 0;

  @override
  void initState() {
    super.initState();
    // Dispatch LoadDueVerses to ensure verses are available
    context.read<MemoryVerseBloc>().add(const LoadDueVerses());
    _initializeServices();
    _startPracticeTimer();
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    _ttsService.stop();
    _ttsService.dispose();
    _speechService.stopListening();
    _speechService.dispose();
    super.dispose();
  }

  void _loadVerse() {
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      try {
        final verse = state.verses.firstWhere((v) => v.id == widget.verseId);
        setState(() => currentVerse = verse);
      } catch (e) {
        // Verse not found
      }
    }
  }

  /// Handle back navigation - go to practice mode selection when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to practice mode selection
      context.go('/memory-verses/practice/${widget.verseId}');
    }
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();
  }

  void _startPracticeTimer() {
    _practiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String _getLanguageCode() {
    // Determine language from verse language field
    final language = currentVerse?.language.toLowerCase() ?? 'en';
    if (language == 'hi') {
      return 'hi-IN';
    } else if (language == 'ml') {
      return 'ml-IN';
    }
    return 'en-US';
  }

  Future<void> _playVerse() async {
    if (currentVerse == null || _isPlaying) return;

    setState(() => _isPlaying = true);

    // First play is free, subsequent plays count as hints
    if (_timesPlayed > 0) {
      _hintsUsed++;
    }
    _timesPlayed++;

    final languageCode = _getLanguageCode();
    final textToSpeak =
        '${currentVerse!.verseReference}. ${currentVerse!.verseText}';

    await _ttsService.speakWithSettings(
      text: textToSpeak,
      languageCode: languageCode,
      speakingRate: _playbackSpeed,
      onComplete: () {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      },
    );
  }

  Future<void> _stopPlayback() async {
    await _ttsService.stop();
    setState(() => _isPlaying = false);
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
  }

  void _proceedToSpeaking() {
    setState(() {
      _currentPhase = AudioPhase.speaking;
    });
  }

  Future<void> _startRecording() async {
    if (currentVerse == null || _isRecording) return;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
      _soundLevel = 0.0;
    });

    final languageCode = _getLanguageCode();

    try {
      await _speechService.startListening(
        languageCode: languageCode,
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });

            if (result.finalResult) {
              _stopRecording();
            }
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = level.clamp(0.0, 10.0));
          }
        },
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    await _speechService.stopListening();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });

    _calculateAccuracy();
  }

  void _calculateAccuracy() {
    if (currentVerse == null || _recognizedText.isEmpty) {
      setState(() {
        _accuracyPercentage = 0.0;
        _wordComparisons = [];
      });
      return;
    }

    // Include reference at the end of verse text for memorization
    final fullText =
        '${currentVerse!.verseText} ${currentVerse!.verseReference}';
    final originalWords = _normalizeText(fullText).split(' ');
    final recognizedWords = _normalizeText(_recognizedText).split(' ');

    // Use sequence alignment to handle word insertions/deletions/splits
    final alignedPairs = _alignWordSequences(originalWords, recognizedWords);

    final comparisons = <WordComparison>[];
    int matchedWords = 0;

    for (final pair in alignedPairs) {
      final isMatch = pair.isMatch;
      if (isMatch) matchedWords++;

      comparisons.add(WordComparison(
        originalWord: pair.originalWord,
        recognizedWord: pair.recognizedWord,
        isMatch: isMatch,
      ));
    }

    final accuracy = originalWords.isEmpty
        ? 0.0
        : (matchedWords / originalWords.length * 100).clamp(0.0, 100.0);

    setState(() {
      _accuracyPercentage = accuracy;
      _wordComparisons = comparisons;
      _currentPhase = AudioPhase.results;
    });
  }

  /// Align two word sequences using dynamic programming (similar to diff algorithms).
  /// Handles insertions, deletions, and word splits gracefully.
  List<_AlignedWordPair> _alignWordSequences(
    List<String> original,
    List<String> recognized,
  ) {
    final m = original.length;
    final n = recognized.length;

    // DP table: dp[i][j] = best score for aligning original[0..i-1] with recognized[0..j-1]
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    // Initialize: cost of deletions (missing words) and insertions (extra words)
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i; // Cost of deleting i words
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j; // Cost of inserting j words
    }

    // Fill DP table
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final matchCost =
            _wordsMatch(original[i - 1], recognized[j - 1]) ? 0 : 1;

        dp[i][j] = [
          dp[i - 1][j - 1] + matchCost, // Match or substitute
          dp[i - 1][j] + 1, // Delete from original (word missing)
          dp[i][j - 1] + 1, // Insert into original (extra word spoken)
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    // Backtrack to find alignment
    final aligned = <_AlignedWordPair>[];
    int i = m;
    int j = n;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final matchCost =
            _wordsMatch(original[i - 1], recognized[j - 1]) ? 0 : 1;
        final fromMatch = dp[i - 1][j - 1] + matchCost;
        final fromDelete = i > 0 ? dp[i - 1][j] + 1 : double.infinity;
        final fromInsert = j > 0 ? dp[i][j - 1] + 1 : double.infinity;

        if (dp[i][j] == fromMatch) {
          // Match or substitution
          aligned.insert(
            0,
            _AlignedWordPair(
              originalWord: original[i - 1],
              recognizedWord: recognized[j - 1],
              isMatch: _wordsMatch(original[i - 1], recognized[j - 1]),
            ),
          );
          i--;
          j--;
        } else if (dp[i][j] == fromDelete) {
          // Word was missed
          aligned.insert(
            0,
            _AlignedWordPair(
              originalWord: original[i - 1],
              recognizedWord: '',
              isMatch: false,
            ),
          );
          i--;
        } else {
          // Extra word was spoken
          aligned.insert(
            0,
            _AlignedWordPair(
              originalWord: '',
              recognizedWord: recognized[j - 1],
              isMatch: false,
            ),
          );
          j--;
        }
      } else if (i > 0) {
        // Remaining words were missed
        aligned.insert(
          0,
          _AlignedWordPair(
            originalWord: original[i - 1],
            recognizedWord: '',
            isMatch: false,
          ),
        );
        i--;
      } else {
        // Remaining extra words
        aligned.insert(
          0,
          _AlignedWordPair(
            originalWord: '',
            recognizedWord: recognized[j - 1],
            isMatch: false,
          ),
        );
        j--;
      }
    }

    return aligned;
  }

  String _normalizeText(String text) {
    // Remove punctuation while preserving all script characters (Hindi, Malayalam, etc.)
    // Using Unicode category for punctuation marks
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _wordsMatch(String original, String recognized) {
    if (original == recognized) return true;

    // Allow for minor differences (1-2 character Levenshtein distance)
    final distance = _levenshteinDistance(original, recognized);
    final maxAllowedDistance = (original.length * 0.3).ceil().clamp(1, 2);

    return distance <= maxAllowedDistance;
  }

  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[m][n];
  }

  void _retryRecording() {
    setState(() {
      _currentPhase = AudioPhase.speaking;
      _recognizedText = '';
      _hasRecorded = false;
      _wordComparisons = [];
      _accuracyPercentage = 0.0;
    });
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    _practiceTimer?.cancel();

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: _accuracyPercentage,
      hintsUsed: _hintsUsed,
      showedAnswer: false,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: _accuracyPercentage,
      hintsUsed: _hintsUsed,
      showedAnswer: false,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'audio',
      timeSpentSeconds: _elapsedSeconds,
      accuracyPercentage: _accuracyPercentage,
      hintsUsed: _hintsUsed,
      showedAnswer: false,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: BlocListener<MemoryVerseBloc, MemoryVerseState>(
        listener: (context, state) {
          if (state is DueVersesLoaded && currentVerse == null) {
            _loadVerse();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBackNavigation,
            ),
            title: Text(context.tr(TranslationKeys.practiceModeAudio)),
            actions: [
              TimerBadge(elapsedSeconds: _elapsedSeconds, compact: true),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: currentVerse == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(theme),
          ),
        ),
      ),
    ).withAuthProtection();
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      children: [
        // Verse Reference Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.primaryContainer,
          child: Text(
            currentVerse!.verseReference,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Phase Indicator
        _buildPhaseIndicator(theme),

        // Main Content
        Expanded(
          child: switch (_currentPhase) {
            AudioPhase.listening => _buildListeningPhase(theme),
            AudioPhase.speaking => _buildSpeakingPhase(theme),
            AudioPhase.results => _buildResultsPhase(theme),
          },
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPhaseChip(
            theme,
            'Listen',
            Icons.headphones,
            _currentPhase == AudioPhase.listening,
            _currentPhase.index >= 0,
          ),
          Container(
            width: 40,
            height: 2,
            color: _currentPhase.index >= 1
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
          ),
          _buildPhaseChip(
            theme,
            'Speak',
            Icons.mic,
            _currentPhase == AudioPhase.speaking,
            _currentPhase.index >= 1,
          ),
          Container(
            width: 40,
            height: 2,
            color: _currentPhase.index >= 2
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
          ),
          _buildPhaseChip(
            theme,
            'Results',
            Icons.check_circle,
            _currentPhase == AudioPhase.results,
            _currentPhase.index >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(
    ThemeData theme,
    String label,
    IconData icon,
    bool isActive,
    bool isCompleted,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : isCompleted
                    ? theme.colorScheme.primary.withAlpha(100)
                    : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive || isCompleted ? Colors.white : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isActive ? theme.colorScheme.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildListeningPhase(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instructions
          Text(
            context.tr(TranslationKeys.audioListenCarefully),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Play Button
          GestureDetector(
            onTap: _isPlaying ? _stopPlayback : _playVerse,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Play count
          Text(
            _timesPlayed > 0
                ? '${context.tr(TranslationKeys.audioPlayed)} $_timesPlayed ${_timesPlayed > 1 ? context.tr(TranslationKeys.audioTimes) : context.tr(TranslationKeys.audioTime)}'
                : context.tr(TranslationKeys.audioTapToPlay),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Speed Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpeedButton(theme, 0.75, '0.75x'),
              const SizedBox(width: 12),
              _buildSpeedButton(theme, 1.0, '1x'),
              const SizedBox(width: 12),
              _buildSpeedButton(theme, 1.25, '1.25x'),
            ],
          ),
          const SizedBox(height: 48),

          // Proceed Button
          if (_timesPlayed > 0)
            ElevatedButton.icon(
              onPressed: _proceedToSpeaking,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.tr(TranslationKeys.audioReadyToSpeak)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(ThemeData theme, double speed, String label) {
    final isSelected = _playbackSpeed == speed;
    return InkWell(
      onTap: () => _changeSpeed(speed),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? theme.colorScheme.primary : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakingPhase(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instructions
          Text(
            _isRecording
                ? context.tr(TranslationKeys.audioSpeakNow)
                : context.tr(TranslationKeys.audioTapMicrophone),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Sound Level Indicator
          if (_isRecording)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(20, (index) {
                  final barHeight = index < (_soundLevel * 2).toInt()
                      ? 40.0
                      : 8.0 + (index % 3) * 4;
                  return Container(
                    width: 4,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? theme.colorScheme.primary
                              .withAlpha((150 + (index / 20 * 105)).toInt())
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

          // Record Button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isRecording ? Colors.red : theme.colorScheme.primary)
                            .withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Recognized Text Preview
          if (_recognizedText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.tr(TranslationKeys.audioRecognized)}:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recognizedText,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Submit Button
          if (_hasRecorded && !_isRecording)
            ElevatedButton.icon(
              onPressed: _calculateAccuracy,
              icon: const Icon(Icons.check),
              label: Text(context.tr(TranslationKeys.audioCheckResult)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsPhase(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Accuracy Score
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getAccuracyColor().withAlpha(30),
              border: Border.all(
                color: _getAccuracyColor(),
                width: 4,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_accuracyPercentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: _getAccuracyColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr(TranslationKeys.practiceResultsAccuracy),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getAccuracyColor(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Original Verse
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr(TranslationKeys.audioExpected)}:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentVerse != null
                      ? '${currentVerse!.verseText} ${currentVerse!.verseReference}'
                      : '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // What was recognized
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(50),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr(TranslationKeys.audioYouSaid)}:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _recognizedText.isEmpty
                      ? context.tr(TranslationKeys.audioNothingRecognized)
                      : _recognizedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _recognizedText.isEmpty
                        ? Colors.grey
                        : theme.colorScheme.onSurface,
                    fontStyle: _recognizedText.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Word-by-word Comparison
          Text(
            context.tr(TranslationKeys.audioWordComparison),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _wordComparisons.map((comparison) {
              final isExtraWord = comparison.originalWord.isEmpty;
              final isMissed = comparison.recognizedWord.isEmpty;

              return Tooltip(
                message: isExtraWord
                    ? 'Extra word spoken'
                    : isMissed
                        ? 'Word missed'
                        : comparison.isMatch
                            ? 'Correct!'
                            : 'Expected: ${comparison.originalWord}\nYou said: ${comparison.recognizedWord}',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: comparison.isMatch
                        ? Colors.green.withAlpha(30)
                        : Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: comparison.isMatch ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!comparison.isMatch && !isExtraWord) ...[
                        // Show expected word with strikethrough
                        Text(
                          comparison.originalWord,
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (comparison.recognizedWord.isNotEmpty)
                          Text(
                            comparison.recognizedWord,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                      ] else
                        Text(
                          isExtraWord
                              ? '+${comparison.recognizedWord}'
                              : comparison.originalWord,
                          style: TextStyle(
                            color:
                                comparison.isMatch ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: _retryRecording,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr(TranslationKeys.practiceRetry)),
              ),
              ElevatedButton.icon(
                onPressed: _submitPractice,
                icon: const Icon(Icons.check),
                label: Text(context.tr(TranslationKeys.practiceSubmit)),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor() {
    if (_accuracyPercentage >= 80) return Colors.green;
    if (_accuracyPercentage >= 50) return Colors.orange;
    return Colors.red;
  }
}

/// Phases of audio practice
enum AudioPhase {
  listening,
  speaking,
  results,
}

/// Word comparison result
class WordComparison {
  final String originalWord;
  final String recognizedWord;
  final bool isMatch;

  WordComparison({
    required this.originalWord,
    required this.recognizedWord,
    required this.isMatch,
  });
}

/// Internal class for aligned word pairs during sequence alignment
class _AlignedWordPair {
  final String originalWord;
  final String recognizedWord;
  final bool isMatch;

  _AlignedWordPair({
    required this.originalWord,
    required this.recognizedWord,
    required this.isMatch,
  });
}
