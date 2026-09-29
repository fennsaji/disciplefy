import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/quality_calculator.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Audio Practice Page for Memory Verses.
///
/// Two-phase practice mode:
/// 1. **Reading Phase**: User reads the verse text on screen to memorize it
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
  final SpeechService _speechService = SpeechService();

  // Phase management
  AudioPhase _currentPhase = AudioPhase.reading;

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
  // No hints in reading mode; the verse is shown for memorization.
  final int _hintsUsed = 0;

  // Walkthrough
  BuildContext? _showcaseContext;
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    // Dispatch LoadDueVerses to ensure verses are available
    context.read<MemoryVerseBloc>().add(const LoadDueVerses());
    _startPracticeTimer();
    _triggerWalkthroughIfNeeded();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.practiceAudio)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceAudio],
      );
    });
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
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

  /// Prepares speech input on demand.
  ///
  /// Deliberately not called from initState: the plugin's initialize() raises
  /// the OS microphone prompt, and asking for the mic the moment this page
  /// opens — before the user has tapped record — is what it used to do.
  /// Returns false when the user declined or the recognizer is unavailable.
  Future<bool> _prepareSpeech() async {
    final permission = await _speechService.requestMicrophonePermission();
    if (permission != MicPermission.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(
                permission == MicPermission.permanentlyDenied
                    ? TranslationKeys.micPermissionBlockedMessage
                    : TranslationKeys.micPermissionMessage)),
            // persist:false — since Flutter 3.44 a SnackBar with an action
            // defaults to persist:true, so it never times out AND blocks every
            // later snackbar behind it in the app-wide queue.
            persist: false,
            action: permission == MicPermission.permanentlyDenied
                ? SnackBarAction(
                    label:
                        context.tr(TranslationKeys.micPermissionOpenSettings),
                    onPressed: _speechService.openPermissionSettings,
                  )
                : null,
          ),
        );
      }
      return false;
    }
    return _speechService.initialize();
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

  void _proceedToSpeaking() {
    setState(() {
      _currentPhase = AudioPhase.speaking;
    });
  }

  Future<void> _startRecording() async {
    if (currentVerse == null || _isRecording) return;

    // Ask for the microphone now — the moment it is actually needed.
    if (!await _prepareSpeech()) return;
    if (!mounted) return;

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
        // Allow 15 seconds of silence before stopping (natural pauses during recitation)
        pauseFor: const Duration(seconds: 15),
        // Allow up to 2 minutes for very long verses or slow recitation
        listenFor: const Duration(seconds: 120),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition error: $e'),
            backgroundColor: AppColors.error,
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
    double matchScore = 0.0;

    for (final pair in alignedPairs) {
      switch (pair.matchType) {
        case MatchType.correct:
          matchScore += 1.0;
        case MatchType.close:
          matchScore += 0.7;
        case MatchType.wrong:
          break;
      }

      comparisons.add(WordComparison(
        originalWord: pair.originalWord,
        recognizedWord: pair.recognizedWord,
        isMatch: pair.matchType != MatchType.wrong,
        matchType: pair.matchType,
      ));
    }

    final accuracy = originalWords.isEmpty
        ? 0.0
        : (matchScore / originalWords.length * 100).clamp(0.0, 100.0);

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
        final mt = _evaluateWordMatch(original[i - 1], recognized[j - 1]);
        final matchCost = mt == MatchType.wrong ? 1 : 0;

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
        final mt = _evaluateWordMatch(original[i - 1], recognized[j - 1]);
        final matchCost = mt == MatchType.wrong ? 1 : 0;
        final fromMatch = dp[i - 1][j - 1] + matchCost;
        final fromDelete = i > 0 ? dp[i - 1][j] + 1 : double.infinity;
        final fromInsert = j > 0 ? dp[i][j - 1] + 1 : double.infinity;

        if (dp[i][j] == fromMatch) {
          aligned.insert(
            0,
            _AlignedWordPair(
              originalWord: original[i - 1],
              recognizedWord: recognized[j - 1],
              isMatch: mt != MatchType.wrong,
              matchType: mt,
            ),
          );
          i--;
          j--;
        } else if (dp[i][j] == fromDelete) {
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

  /// Evaluates how closely [recognized] matches [original] with graduated scoring.
  ///
  ///   ≥ 80% similarity → correct  — covers 1-letter speech recognition errors
  ///   60–79% similarity → close   — covers 2-letter differences
  ///   < 60%             → wrong
  MatchType _evaluateWordMatch(String original, String recognized) {
    if (original == recognized) return MatchType.correct;
    if (original.isEmpty || recognized.isEmpty) return MatchType.wrong;

    final maxLen = original.length > recognized.length
        ? original.length
        : recognized.length;
    final distance = _levenshteinDistance(original, recognized);
    final similarity = (1.0 - distance / maxLen) * 100;

    if (similarity >= 80.0) return MatchType.correct;
    if (similarity >= 60.0) return MatchType.close;
    return MatchType.wrong;
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
    final title = context.tr(TranslationKeys.practiceModeAudio);

    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.practiceAudio),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
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
            child: currentVerse == null
                ? MemoryPracticeScaffold(
                    title: title,
                    elapsedSeconds: _elapsedSeconds,
                    onClose: _handleBackNavigation,
                    scrollable: false,
                    body: const Center(child: CircularProgressIndicator()),
                  )
                : MemoryPracticeScaffold(
                    title: title,
                    subtitle: '${currentVerse!.verseReference} · '
                        '${context.tr(TranslationKeys.difficultyHard)}',
                    elapsedSeconds: _elapsedSeconds,
                    onClose: _handleBackNavigation,
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MemoryStepIndicator(
                          steps: [
                            context.tr(TranslationKeys.practiceStepRead),
                            context.tr(TranslationKeys.practiceStepSpeak),
                            context.tr(TranslationKeys.practiceStepResults),
                          ],
                          currentIndex: _currentPhase.index,
                        ),
                        const SizedBox(height: 24),
                        switch (_currentPhase) {
                          AudioPhase.reading => _buildReadingPhase(),
                          AudioPhase.speaking => _buildSpeakingPhase(),
                          AudioPhase.results => _buildResultsPhase(),
                        },
                      ],
                    ),
                    bottomBar: _buildBottomBar(),
                  ),
          ),
        ).withAuthProtection();
      },
    );
  }

  Widget? _buildBottomBar() {
    switch (_currentPhase) {
      case AudioPhase.reading:
        return MemoryActionBar(
          primary: MemoryPrimaryPill(
            label: context.tr(TranslationKeys.audioReadyToSpeak),
            icon: Icons.arrow_forward_rounded,
            onPressed: _proceedToSpeaking,
          ),
        );
      case AudioPhase.speaking:
        if (!_hasRecorded || _isRecording) return null;
        return MemoryActionBar(
          primary: MemoryPrimaryPill(
            label: context.tr(TranslationKeys.audioCheckResult),
            icon: Icons.check_rounded,
            onPressed: _calculateAccuracy,
          ),
        );
      case AudioPhase.results:
        return MemoryActionBar(
          secondary: [
            MemoryActionPill(
              label: context.tr(TranslationKeys.practiceRetry),
              icon: Icons.refresh_rounded,
              onPressed: _retryRecording,
            ),
          ],
          primary: MemoryPrimaryPill(
            label: context.tr(TranslationKeys.practiceSubmit),
            onPressed: _submitPractice,
          ),
        );
    }
  }

  Widget _buildReadingPhase() {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(TranslationKeys.audioReadCarefully),
          textAlign: TextAlign.center,
          style: AppFonts.inter(fontSize: 14.5, color: palette.muted),
        ),
        const SizedBox(height: 16),
        // Verse text to read and memorize
        WalkthroughTooltip(
          showcaseKey: ShowcaseKeys.practiceAudio,
          title: l10n.walkthroughPracticeAudioTitle,
          description: l10n.walkthroughPracticeAudioDesc,
          screen: WalkthroughScreen.practiceAudio,
          stepNumber: 1,
          totalSteps: 1,
          onNext: _onNext,
          highlightBorderRadius: 22,
          child: MemoryAnswerCard(
            radius: 22,
            padding: const EdgeInsets.all(22),
            child: Text(
              currentVerse!.verseText,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 19,
                height: 1.55,
                color: palette.text,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakingPhase() {
    final palette = ReaderPalette.of(context);
    final micColor =
        _isRecording ? AppColors.error : ReaderPalette.selectedFill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SoundLevelBars(level: _soundLevel, active: _isRecording),
        const SizedBox(height: 18),
        Text(
          _isRecording
              ? context.tr(TranslationKeys.audioSpeakNow)
              : context.tr(TranslationKeys.audioTapMicrophone),
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isRecording ? palette.gold : palette.muted,
          ),
        ),
        const SizedBox(height: 18),
        // Record button: a flat disc inside a soft static halo (no blur).
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: micColor.withValues(alpha: palette.isDark ? 0.14 : 0.10),
            ),
            child: Semantics(
              button: true,
              label: _isRecording
                  ? context.tr(TranslationKeys.audioSpeakNow)
                  : context.tr(TranslationKeys.audioTapMicrophone),
              excludeSemantics: true,
              child: Material(
                color: micColor,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('audio_record_button'),
                  customBorder: const CircleBorder(),
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Recognized Text Preview
        if (_recognizedText.isNotEmpty) ...[
          MemorySectionLabel.muted(
            context,
            context.tr(TranslationKeys.audioYouSaid),
            padding: const EdgeInsets.only(top: 28, bottom: 8),
          ),
          Text(
            _recognizedText,
            style: AppFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 14),
          const MemoryHairline(),
        ],
      ],
    );
  }

  Widget _buildResultsPhase() {
    final palette = ReaderPalette.of(context);
    final accuracyColor = _getAccuracyColor();
    final fullVerse = currentVerse != null
        ? '${currentVerse!.verseText} ${currentVerse!.verseReference}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Accuracy Score
        Center(
          child: Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accuracyColor, width: 5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_accuracyPercentage.toStringAsFixed(0)}%',
                  style: AppFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    fontFeatures: kMemoryTabular,
                  ),
                ),
                Text(
                  context.tr(TranslationKeys.practiceResultsAccuracy),
                  style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
                ),
              ],
            ),
          ),
        ),
        MemorySectionLabel.muted(
            context, context.tr(TranslationKeys.audioExpected)),
        Text(
          fullVerse,
          style:
              AppFonts.inter(fontSize: 15.5, height: 1.5, color: palette.text),
        ),
        const SizedBox(height: 14),
        const MemoryHairline(),
        MemorySectionLabel.muted(
            context, context.tr(TranslationKeys.audioYouSaid)),
        Text(
          _recognizedText.isEmpty
              ? context.tr(TranslationKeys.audioNothingRecognized)
              : _recognizedText,
          style: AppFonts.inter(
            fontSize: 15.5,
            height: 1.5,
            color: _recognizedText.isEmpty ? palette.dim : palette.text,
            fontStyle:
                _recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        const SizedBox(height: 14),
        const MemoryHairline(),
        MemorySectionLabel.muted(
            context, context.tr(TranslationKeys.audioWordComparison)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _wordComparisons.map(_buildComparisonChip).toList(),
        ),
      ],
    );
  }

  Widget _buildComparisonChip(WordComparison comparison) {
    final palette = ReaderPalette.of(context);
    final isExtraWord = comparison.originalWord.isEmpty;
    final isMissed = comparison.recognizedWord.isEmpty;
    final isClose = comparison.matchType == MatchType.close;
    final tone = isClose
        ? MemoryTone.warning
        : comparison.isMatch
            ? MemoryTone.success
            : MemoryTone.error;
    final colors = MemoryToneColors.of(context, tone);

    final String message;
    if (isExtraWord) {
      message = context.tr(TranslationKeys.audioPracticeExtraWord);
    } else if (isMissed) {
      message = context.tr(TranslationKeys.audioPracticeWordMissed);
    } else if (comparison.isMatch) {
      message = isClose
          ? context.tr(TranslationKeys.memoryPracticeCloseExpected,
              {'word': comparison.originalWord})
          : context.tr(TranslationKeys.audioPracticeCorrect);
    } else {
      message = context.tr(TranslationKeys.memoryPracticeExpectedSaid, {
        'expected': comparison.originalWord,
        'said': comparison.recognizedWord,
      });
    }

    final struck = AppFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: palette.muted,
      decoration: TextDecoration.lineThrough,
    );
    final main = AppFonts.inter(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );

    return Tooltip(
      message: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // What the user said, crossed out, above the expected word.
            if ((!comparison.isMatch || isClose) &&
                !isExtraWord &&
                comparison.recognizedWord.isNotEmpty)
              Text(comparison.recognizedWord, style: struck),
            Text(
              isExtraWord
                  ? '+${comparison.recognizedWord}'
                  : comparison.originalWord,
              style: main,
            ),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor() {
    if (_accuracyPercentage >= 80) return context.appSuccess;
    if (_accuracyPercentage >= 50) return context.appWarning;
    return context.appError;
  }
}

/// Live microphone level: bars grow with the reported sound level while
/// recording and rest at a quiet pattern otherwise. Driven only by
/// `onSoundLevelChange` (no decorative animation loop).
class _SoundLevelBars extends StatelessWidget {
  final double level;
  final bool active;

  const _SoundLevelBars({required this.level, required this.active});

  static const _pattern = [
    0.35,
    0.6,
    0.85,
    0.5,
    0.75,
    1.0,
    0.55,
    0.9,
    0.65,
    1.0,
    0.5,
    0.8,
    0.6,
    0.4,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final normalized = active ? (level / 10).clamp(0.0, 1.0) : 0.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final factor in _pattern)
              Container(
                width: 5,
                height: 12 + 44 * factor * (0.35 + 0.65 * normalized),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active
                      ? palette.accentIcon
                      : palette.accentIcon.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phases of audio practice
enum AudioPhase {
  reading,
  speaking,
  results,
}

/// Word comparison result
class WordComparison {
  final String originalWord;
  final String recognizedWord;
  final bool isMatch;
  final MatchType matchType;

  WordComparison({
    required this.originalWord,
    required this.recognizedWord,
    required this.isMatch,
    this.matchType = MatchType.wrong,
  });
}

/// Internal class for aligned word pairs during sequence alignment
class _AlignedWordPair {
  final String originalWord;
  final String recognizedWord;
  final bool isMatch;
  final MatchType matchType;

  _AlignedWordPair({
    required this.originalWord,
    required this.recognizedWord,
    required this.isMatch,
    this.matchType = MatchType.wrong,
  });
}
