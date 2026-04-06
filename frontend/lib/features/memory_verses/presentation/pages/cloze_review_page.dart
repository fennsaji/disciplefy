import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../data/services/transliteration_service.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_result_params.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../utils/quality_calculator.dart';
import '../widgets/timer_badge.dart';
import 'cloze_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';

/// Cloze deletion practice mode with progressive difficulty.
///
/// Users fill in missing words (blanks) in the verse.
/// Difficulty levels:
/// - Easy: Every 5th word blank
/// - Medium: Every 3rd word blank
/// - Hard: Every 2nd word blank
class ClozeReviewPage extends StatefulWidget {
  final String verseId;
  final ClozeDifficulty difficulty;

  const ClozeReviewPage({
    super.key,
    required this.verseId,
    this.difficulty = ClozeDifficulty.medium,
  });

  @override
  State<ClozeReviewPage> createState() => _ClozeReviewPageState();
}

class _ClozeReviewPageState extends State<ClozeReviewPage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;
  List<WordEntry> wordEntries = [];
  Map<int, TextEditingController> blankControllers = {};
  double accuracyPercentage = 0.0;
  bool isCompleted = false;
  String detectedLanguage = 'en'; // For transliteration support

  BuildContext? _showcaseContext;
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
    _triggerWalkthroughIfNeeded();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.practiceCloze)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceCloze],
      );
    });
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
    for (final controller in blankControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    practiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => elapsedSeconds++);
    });
  }

  void _loadVerse() {
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      final verse =
          state.verses.firstWhereOrNull((v) => v.id == widget.verseId);
      if (verse != null) {
        setState(() {
          currentVerse = verse;
          detectedLanguage =
              TransliterationService.detectLanguage(verse.verseText);
          _initializeWordEntries();
        });
      } else {
        context
            .read<MemoryVerseBloc>()
            .add(const LoadDueVerses(forceRefresh: true));
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
    }
  }

  void _initializeWordEntries() {
    if (currentVerse == null) return;

    // Only tokenize verseText for cloze blanks (exclude reference)
    // The reference is displayed separately in the UI
    final verseText = currentVerse!.verseText;
    final words = verseText.split(' ');
    wordEntries = [];

    // Target ~1 blank per N words depending on difficulty, minimum 2.
    // We divide the verse into that many equal segments and pick the
    // most meaningful (highest-scored) non-skip word from each segment.
    // Tie-break: prefer the later position in the segment, since key
    // words tend to appear at the end of phrases.
    final divisor = _getBlankDivisor();
    final targetBlanks =
        (words.length / divisor).round().clamp(2, words.length ~/ 2);
    final blankIndices = _selectBlankIndices(words, targetBlanks);

    for (int i = 0; i < words.length; i++) {
      final isBlank = blankIndices.contains(i);
      wordEntries.add(WordEntry(
        index: i,
        word: words[i],
        isBlank: isBlank,
        userInput: '',
      ));
      if (isBlank) {
        blankControllers[i] = TextEditingController();
        blankControllers[i]!.addListener(() => _onInputChanged(i));
      }
    }
  }

  /// Divides the verse into [targetCount] equal segments and picks the
  /// highest-scoring non-skip word from each segment.
  Set<int> _selectBlankIndices(List<String> words, int targetCount) {
    final segmentSize = words.length / targetCount;
    final blankIndices = <int>{};

    for (int seg = 0; seg < targetCount; seg++) {
      final start = (seg * segmentSize).round();
      final end =
          ((seg + 1) * segmentSize).round().clamp(start + 1, words.length);

      int bestIndex = -1;
      int bestScore = -1;

      for (int i = start; i < end; i++) {
        if (_isSkipWord(words[i])) continue;
        final score = _wordScore(words[i]);
        // Prefer higher score; on tie prefer later position (key words
        // tend to appear at the end of phrases).
        if (score > bestScore || (score == bestScore && i > bestIndex)) {
          bestScore = score;
          bestIndex = i;
        }
      }

      if (bestIndex >= 0) blankIndices.add(bestIndex);
    }

    return blankIndices;
  }

  /// Score a word by length as a proxy for semantic importance.
  /// Longer words are almost always more meaningful than short ones.
  int _wordScore(String word) {
    // [^\w] only strips ASCII punctuation; use Unicode-aware pattern so that
    // Devanagari/Malayalam characters are not incorrectly removed.
    final len =
        word.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').length;
    if (len >= 7) return 4;
    if (len >= 5) return 3;
    if (len == 4) return 2;
    return 1;
  }

  /// Returns true for words that should never be blanked:
  /// articles, common prepositions, auxiliary verbs, conjunctions, pronouns.
  /// For non-English verses, skips very short words (particles/conjunctions).
  bool _isSkipWord(String word) {
    // [^\w] only matches ASCII word chars — all Unicode letters (Devanagari,
    // Malayalam, etc.) would be stripped, making every non-English word appear
    // empty and therefore always skipped. Use a Unicode-aware pattern instead.
    final clean = word
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    if (clean.isEmpty) return true;

    if (detectedLanguage != 'en') {
      // For Hindi/Malayalam, skip short particles (≤ 2 chars)
      return clean.length <= 2;
    }

    const skipWords = {
      // Articles
      'a', 'an', 'the',
      // Prepositions
      'of', 'in', 'on', 'to', 'for', 'with', 'by', 'at', 'from', 'into',
      'onto', 'upon', 'over', 'through', 'between', 'among',
      'about', 'against', 'along', 'around', 'before', 'behind', 'below',
      'beneath', 'beside', 'beyond', 'during', 'except', 'inside', 'near',
      'off', 'outside', 'past', 'since', 'toward', 'towards', 'under',
      'until', 'up', 'within', 'without', 'as', 'than',
      // Auxiliary verbs
      'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'has', 'have', 'had', 'do', 'does', 'did',
      'will', 'would', 'shall', 'should', 'may', 'might', 'can', 'could',
      'must',
      // Conjunctions & particles
      'and', 'or', 'but', 'nor', 'so', 'yet', 'not',
      'although', 'because', 'unless', 'while',
      'if', 'then', 'that', 'which', 'who', 'whom', 'whose',
      'when', 'where', 'how',
      // Pronouns
      'i', 'me', 'my', 'myself',
      'you', 'your', 'yourself',
      'he', 'him', 'his', 'himself',
      'she', 'her', 'herself',
      'it', 'its', 'itself',
      'we', 'us', 'our', 'ourselves',
      'they', 'them', 'their', 'themselves',
    };

    return skipWords.contains(clean);
  }

  /// Returns the 1-in-N ratio for blank density based on difficulty.
  /// e.g. easy=5 → 1 blank per 5 words, medium=4 → 1 per 4, hard=3 → 1 per 3.
  int _getBlankDivisor() {
    switch (widget.difficulty) {
      case ClozeDifficulty.easy:
        return 5;
      case ClozeDifficulty.medium:
        return 4;
      case ClozeDifficulty.hard:
        return 3;
    }
  }

  void _onInputChanged(int index) {
    final entry = wordEntries.firstWhere((e) => e.index == index);
    entry.userInput = blankControllers[index]!.text;

    _calculateAccuracy();
  }

  void _calculateAccuracy() {
    final blanks = wordEntries.where((e) => e.isBlank).toList();
    final totalScore = blanks.fold(
      0.0,
      (sum, e) => sum + _evaluateWord(e.word, e.userInput).score,
    );
    final accuracy =
        blanks.isEmpty ? 0.0 : (totalScore / (blanks.length * 100.0)) * 100.0;
    final allFilled = blanks.every((e) => e.userInput.isNotEmpty);

    setState(() {
      accuracyPercentage = accuracy;
      isCompleted = allFilled;
    });
  }

  /// Evaluates how closely [input] matches [target] and returns a graduated result.
  ///
  /// Thresholds (applied after normalization):
  ///   ≥ 80% similarity → correct (100 pts) — covers 1-letter typos
  ///   60–79% similarity → close  (70 pts)  — covers 2-letter typos
  ///   < 60%             → wrong  (0 pts)
  ///
  /// All languages use fuzzy matching so casual typos are tolerated.
  ({MatchType matchType, double score}) _evaluateWord(
      String target, String input) {
    if (input.isEmpty) return (matchType: MatchType.wrong, score: 0.0);

    // Transliterate non-English target to romanized form for comparison
    String normalizedTarget;
    if (detectedLanguage != 'en') {
      final transliterated =
          TransliterationService.transliterate(target, detectedLanguage);
      normalizedTarget = (transliterated ?? target).toLowerCase().trim();
    } else {
      normalizedTarget = target.toLowerCase().trim();
    }

    final normalizedInput = input.toLowerCase().trim();

    final targetClean = normalizedTarget.replaceAll(RegExp(r'[^\w\s]'), '');
    final inputClean = normalizedInput.replaceAll(RegExp(r'[^\w\s]'), '');

    // Exact match
    if (targetClean == inputClean) {
      return (matchType: MatchType.correct, score: 100.0);
    }

    // For Malayalam, normalize phonetic equivalences first so that
    // spellings like karthavu/karththavu are treated as identical.
    String compareTarget = targetClean;
    String compareInput = inputClean;
    if (detectedLanguage == 'ml') {
      compareTarget =
          TransliterationService.normalizeMalayalamManglish(compareTarget);
      compareInput =
          TransliterationService.normalizeMalayalamManglish(compareInput);
      if (compareTarget == compareInput) {
        return (matchType: MatchType.correct, score: 100.0);
      }
    }

    // Fuzzy match for all languages — tolerates typos in English too
    final similarity =
        TransliterationService.calculateAccuracy(compareInput, compareTarget);
    if (similarity >= 80.0) return (matchType: MatchType.correct, score: 100.0);
    if (similarity >= 60.0) return (matchType: MatchType.close, score: 70.0);

    return (matchType: MatchType.wrong, score: 0.0);
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Fill-in-the-Blanks mode has no hint button, so hintsUsed is always 0
    final blanks = wordEntries.where((e) => e.isBlank).toList();
    const int hintsUsed = 0;

    // Collect blank comparisons for results page
    final blankComparisons = blanks.map((entry) {
      final result = _evaluateWord(entry.word, entry.userInput);
      return BlankComparison(
        expected: entry.word,
        userInput: entry.userInput.isEmpty ? '(empty)' : entry.userInput,
        isCorrect: result.matchType != MatchType.wrong,
        matchType: result.matchType,
        score: result.score,
      );
    }).toList();

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracyPercentage,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracyPercentage,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'cloze',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracyPercentage,
      hintsUsed: hintsUsed,
      showedAnswer: false,
      qualityRating: quality,
      confidenceRating: confidence,
      blankComparisons: blankComparisons,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  /// Get translated difficulty label
  String _getDifficultyLabel(BuildContext context) {
    switch (widget.difficulty) {
      case ClozeDifficulty.easy:
        return context.tr(TranslationKeys.difficultyEasy).toUpperCase();
      case ClozeDifficulty.medium:
        return context.tr(TranslationKeys.difficultyMedium).toUpperCase();
      case ClozeDifficulty.hard:
        return context.tr(TranslationKeys.difficultyHard).toUpperCase();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.practiceCloze),
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
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackNavigation,
                ),
                title: Text(
                    '${context.tr(TranslationKeys.practiceModeCloze)} - ${_getDifficultyLabel(context)}'),
                actions: [
                  TimerBadge(elapsedSeconds: elapsedSeconds, compact: true),
                  const SizedBox(width: 8),
                ],
              ),
              body: currentVerse == null
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Verse Reference
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              currentVerse!.verseReference,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: WalkthroughTooltip(
                                showcaseKey: ShowcaseKeys.practiceCloze,
                                title: l10n.walkthroughPracticeClozeTitle,
                                description: l10n.walkthroughPracticeClozeDesc,
                                screen: WalkthroughScreen.practiceCloze,
                                stepNumber: 1,
                                totalSteps: 1,
                                onNext: _onNext,
                                tooltipPosition: TooltipPosition.bottom,
                                child: _ClozeVerseView(
                                  wordEntries: wordEntries,
                                  blankControllers: blankControllers,
                                  showFeedback: false,
                                ),
                              ),
                            ),
                          ),
                          // Submit Button
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isCompleted ? _submitPractice : null,
                                icon: const Icon(Icons.check),
                                label: Text(
                                    context.tr(TranslationKeys.practiceSubmit)),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: context.appInteractive,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }
}

/// Cloze verse view with blanks
class _ClozeVerseView extends StatelessWidget {
  final List<WordEntry> wordEntries;
  final Map<int, TextEditingController> blankControllers;
  final bool showFeedback;

  const _ClozeVerseView({
    required this.wordEntries,
    required this.blankControllers,
    required this.showFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 8,
        children: wordEntries.map((entry) {
          if (entry.isBlank) {
            return _BlankWidget(
              entry: entry,
              controller: blankControllers[entry.index]!,
              showFeedback: showFeedback,
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                entry.word,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.8,
                  fontSize: 16,
                ),
              ),
            );
          }
        }).toList(),
      ),
    );
  }
}

/// Blank input widget
class _BlankWidget extends StatelessWidget {
  final WordEntry entry;
  final TextEditingController controller;
  final bool showFeedback;

  const _BlankWidget({
    required this.entry,
    required this.controller,
    required this.showFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(
        minWidth: 80,
        maxWidth: 150,
      ),
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: '____',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
