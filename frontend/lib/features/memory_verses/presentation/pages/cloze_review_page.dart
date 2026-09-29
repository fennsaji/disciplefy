import 'dart:async';

import 'package:collection/collection.dart';
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
import 'package:disciplefy_bible_study/features/memory_verses/data/services/transliteration_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/cloze_models.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/quality_calculator.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

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

  /// Current blank density; starts at the route's difficulty.
  late ClozeDifficulty _difficulty = widget.difficulty;

  /// The user revealed the correct words ("Show answer").
  bool _showedAnswer = false;

  /// What the user had typed in each blank before revealing the answer.
  Map<int, String> _inputsBeforeReveal = {};

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
    switch (_difficulty) {
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

    // Collect blank comparisons for results page. When the answer was
    // shown, compare what the user had typed before revealing it.
    final blankComparisons = blanks.map((entry) {
      final input = _showedAnswer
          ? (_inputsBeforeReveal[entry.index] ?? '')
          : entry.userInput;
      final result = _evaluateWord(entry.word, input);
      return BlankComparison(
        expected: entry.word,
        userInput: input.isEmpty ? '(empty)' : input,
        isCorrect: result.matchType != MatchType.wrong,
        matchType: result.matchType,
        score: result.score,
      );
    }).toList();

    // Showing the answer scores 0, as in the other practice modes.
    final accuracy = _showedAnswer ? 0.0 : accuracyPercentage;

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: _showedAnswer,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: _showedAnswer,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'cloze',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: _showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
      blankComparisons: blankComparisons,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  /// Fills every blank with the correct word and locks the inputs. The
  /// user still taps Check to finish; the attempt is scored as "answer shown".
  void _showAnswer() {
    if (_showedAnswer) return;
    _inputsBeforeReveal = {
      for (final entry in wordEntries.where((e) => e.isBlank))
        entry.index: entry.userInput,
    };
    FocusScope.of(context).unfocus();
    setState(() => _showedAnswer = true);
    for (final entry in wordEntries.where((e) => e.isBlank)) {
      blankControllers[entry.index]!.text = entry.word;
    }
  }

  /// Switches blank density; rebuilds the blanks and clears typed answers.
  void _setDifficulty(ClozeDifficulty difficulty) {
    if (difficulty == _difficulty) return;
    FocusScope.of(context).unfocus();
    final oldControllers = blankControllers.values.toList();
    setState(() {
      _difficulty = difficulty;
      blankControllers = {};
      _showedAnswer = false;
      _inputsBeforeReveal = {};
      accuracyPercentage = 0.0;
      isCompleted = false;
      _initializeWordEntries();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
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
    final l10n = AppLocalizations.of(context)!;
    final title = context.tr(TranslationKeys.practiceModeCloze);

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
            child: currentVerse == null
                ? MemoryPracticeScaffold(
                    title: title,
                    onClose: _handleBackNavigation,
                    elapsedSeconds: elapsedSeconds,
                    scrollable: false,
                    body: const Center(child: CircularProgressIndicator()),
                  )
                : MemoryPracticeScaffold(
                    title: title,
                    subtitle: '${currentVerse!.verseReference} · '
                        '${context.tr(switch (_difficulty) {
                      ClozeDifficulty.easy => TranslationKeys.difficultyEasy,
                      ClozeDifficulty.medium =>
                        TranslationKeys.difficultyMedium,
                      ClozeDifficulty.hard => TranslationKeys.difficultyHard,
                    })}',
                    elapsedSeconds: elapsedSeconds,
                    onClose: _handleBackNavigation,
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MemorySegmentedControl<ClozeDifficulty>(
                          segments: [
                            MemorySegment(
                              value: ClozeDifficulty.easy,
                              label: context.tr(TranslationKeys.difficultyEasy),
                            ),
                            MemorySegment(
                              value: ClozeDifficulty.medium,
                              label:
                                  context.tr(TranslationKeys.difficultyMedium),
                            ),
                            MemorySegment(
                              value: ClozeDifficulty.hard,
                              label: context.tr(TranslationKeys.difficultyHard),
                            ),
                          ],
                          selected: _difficulty,
                          onChanged: _setDifficulty,
                        ),
                        const SizedBox(height: 14),
                        WalkthroughTooltip(
                          showcaseKey: ShowcaseKeys.practiceCloze,
                          title: l10n.walkthroughPracticeClozeTitle,
                          description: l10n.walkthroughPracticeClozeDesc,
                          screen: WalkthroughScreen.practiceCloze,
                          stepNumber: 1,
                          totalSteps: 1,
                          onNext: _onNext,
                          tooltipPosition: TooltipPosition.bottom,
                          highlightBorderRadius: 22,
                          child: _ClozeVerseView(
                            key: ValueKey(_difficulty),
                            wordEntries: wordEntries,
                            blankControllers: blankControllers,
                            revealed: _showedAnswer,
                          ),
                        ),
                      ],
                    ),
                    bottomBar: MemoryActionBar(
                      secondary: [
                        MemoryActionPill(
                          label: context.tr(TranslationKeys.practiceShowAnswer),
                          icon: Icons.visibility_outlined,
                          onPressed: _showedAnswer ? null : _showAnswer,
                        ),
                      ],
                      primary: MemoryPrimaryPill(
                        label: context.tr(TranslationKeys.memoryPracticeCheck),
                        icon: Icons.check_rounded,
                        onPressed: isCompleted || _showedAnswer
                            ? _submitPractice
                            : null,
                      ),
                    ),
                  ),
          ),
        ).withAuthProtection();
      },
    );
  }
}

/// The verse as one card: plain words plus inline text fields for blanks.
class _ClozeVerseView extends StatelessWidget {
  final List<WordEntry> wordEntries;
  final Map<int, TextEditingController> blankControllers;

  /// Answer shown: blanks are filled with the correct word and locked.
  final bool revealed;

  const _ClozeVerseView({
    super.key,
    required this.wordEntries,
    required this.blankControllers,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return MemoryAnswerCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Wrap(
        spacing: 6,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: wordEntries.map((entry) {
          if (entry.isBlank) {
            return _BlankField(
              key: ValueKey('cloze_blank_${entry.index}'),
              controller: blankControllers[entry.index]!,
              revealed: revealed,
            );
          }
          return Text(
            entry.word,
            style: AppFonts.inter(
              fontSize: 18,
              height: 1.5,
              color: palette.text,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Inline blank: accent outline while empty/typing, green once revealed.
class _BlankField extends StatelessWidget {
  final TextEditingController controller;
  final bool revealed;

  const _BlankField({
    super.key,
    required this.controller,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final borderColor = revealed ? context.appSuccess : palette.accentIcon;
    OutlineInputBorder border(double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: width),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 150),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          readOnly: revealed,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.next,
          style: AppFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: revealed ? context.appSuccess : palette.text,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: revealed
                ? AppColors.success
                    .withValues(alpha: palette.isDark ? 0.14 : 0.10)
                : Colors.transparent,
            border: border(1.5),
            enabledBorder: border(1.5),
            focusedBorder: border(2),
            disabledBorder: border(1.5),
            constraints: const BoxConstraints(minWidth: 80),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}
