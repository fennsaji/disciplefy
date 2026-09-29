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
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/transliteration_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/quality_calculator.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Helper class to store word alignment results
class _WordMatch {
  final String expected;
  final String userWord;
  final bool isCorrect;
  final MatchType matchType;
  final double score;

  _WordMatch({
    required this.expected,
    required this.userWord,
    required this.isCorrect,
    this.matchType = MatchType.wrong,
    this.score = 0.0,
  });
}

/// Type It Out practice mode for memory verses.
///
/// Users type the entire verse from memory. For Hindi/Malayalam,
/// users type in romanized form (Hinglish/Manglish) and accuracy
/// is calculated using Levenshtein distance.
///
/// This is a Hard difficulty mode - no hints provided,
/// only the verse reference is shown.
class TypeItOutPracticePage extends StatefulWidget {
  final String verseId;

  const TypeItOutPracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<TypeItOutPracticePage> createState() => _TypeItOutPracticePageState();
}

class _TypeItOutPracticePageState extends State<TypeItOutPracticePage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;

  BuildContext? _showcaseContext;
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  /// The text the user should type - romanized for Hindi/Malayalam
  String expectedText = '';
  String detectedLanguage = 'en';

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool isCompleted = false;
  bool showedAnswer = false;
  double? accuracy;

  @override
  void initState() {
    super.initState();
    // Repaint the answer card border when focus moves in or out.
    _focusNode.addListener(_onFocusChanged);
    _startTimer();
    _loadVerse();
    _triggerWalkthroughIfNeeded();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.practiceTypeItOut)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceTypeItOut],
      );
    });
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
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
          // Include reference at the end of verse text for memorization
          final fullText = '${verse.verseText} ${verse.verseReference}';
          _initializeExpectedText(fullText);
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

  void _initializeExpectedText(String verseText) {
    // Detect language
    detectedLanguage = TransliterationService.detectLanguage(verseText);

    // For Hindi/Malayalam, use romanized version; for English, use as-is
    if (detectedLanguage == 'en') {
      expectedText = verseText;
    } else {
      expectedText = TransliterationService.transliterate(
            verseText,
            detectedLanguage,
          ) ??
          verseText;
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

  int get currentWordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get expectedWordCount {
    if (expectedText.isEmpty) return 0;
    return expectedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  void _checkAnswer() {
    if (isCompleted) return;

    final userInput = _textController.text;
    accuracy =
        TransliterationService.calculateAccuracy(userInput, expectedText);

    practiceTimer?.cancel();

    _submitPractice();
  }

  void _showAnswer() {
    setState(() {
      showedAnswer = true;
    });
    practiceTimer?.cancel();

    // Calculate accuracy based on what was typed
    accuracy = TransliterationService.calculateAccuracy(
      _textController.text,
      expectedText,
    );

    _submitPractice();
  }

  void _clearInput() {
    if (isCompleted) return;
    _textController.clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Generate word-by-word comparison for results page
    final wordComparisons = _generateWordComparisons();

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy ?? 0.0,
      hintsUsed: 0, // No hints in Type It Out mode
      showedAnswer: showedAnswer,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy ?? 0.0,
      hintsUsed: 0,
      showedAnswer: showedAnswer,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'type_it_out',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy ?? 0.0,
      hintsUsed: 0,
      showedAnswer: showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
      blankComparisons: wordComparisons,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  /// Generate word-by-word comparison for the results page
  /// Uses sequence alignment to properly detect missing, extra, and wrong words
  List<BlankComparison> _generateWordComparisons() {
    final userInput = _textController.text.trim();
    final expectedWords =
        expectedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final userWords =
        userInput.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final alignment = _alignWordSequences(expectedWords, userWords);

    return alignment
        .map((match) => BlankComparison(
              expected: match.expected,
              userInput: match.userWord,
              isCorrect: match.isCorrect,
              matchType: match.matchType,
              score: match.score,
            ))
        .toList();
  }

  /// Align two word sequences to find missing, extra, and matching words
  List<_WordMatch> _alignWordSequences(
      List<String> expected, List<String> user) {
    final matches = <_WordMatch>[];
    int userIndex = 0;

    for (int expectedIndex = 0;
        expectedIndex < expected.length;
        expectedIndex++) {
      final expectedWord = expected[expectedIndex];

      if (userIndex >= user.length) {
        matches.add(_WordMatch(
          expected: expectedWord,
          userWord: '(missing)',
          isCorrect: false,
        ));
        continue;
      }

      final userWord = user[userIndex];
      final result = _evaluateWord(expectedWord, userWord);

      if (result.matchType != MatchType.wrong) {
        matches.add(_WordMatch(
          expected: expectedWord,
          userWord: userWord,
          isCorrect: true,
          matchType: result.matchType,
          score: result.score,
        ));
        userIndex++;
      } else {
        // Check if user skipped this word — does the user word match the NEXT expected word?
        final nextEval = expectedIndex + 1 < expected.length
            ? _evaluateWord(expected[expectedIndex + 1], userWord)
            : (matchType: MatchType.wrong, score: 0.0);

        if (nextEval.matchType != MatchType.wrong) {
          // User likely skipped the current expected word
          matches.add(_WordMatch(
            expected: expectedWord,
            userWord: '(missing)',
            isCorrect: false,
          ));
        } else {
          // Substitution — user typed a different word
          matches.add(_WordMatch(
            expected: expectedWord,
            userWord: userWord,
            isCorrect: false,
          ));
          userIndex++;
        }
      }
    }

    // Extra words typed beyond expected length
    while (userIndex < user.length) {
      matches.add(_WordMatch(
        expected: '(extra)',
        userWord: user[userIndex],
        isCorrect: false,
      ));
      userIndex++;
    }

    return matches;
  }

  /// Evaluates how closely [user] matches [expected] with graduated scoring.
  ///
  ///   ≥ 80% similarity → correct (100 pts) — covers 1-letter typos
  ///   60–79% similarity → close  (70 pts)  — covers 2-letter typos
  ///   < 60%             → wrong  (0 pts)
  ///
  /// Applied to all languages so English typos are also tolerated.
  ({MatchType matchType, double score}) _evaluateWord(
      String expected, String user) {
    if (user == '(missing)' || expected.isEmpty) {
      return (matchType: MatchType.wrong, score: 0.0);
    }

    final expectedClean =
        expected.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
    final userClean =
        user.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');

    if (expectedClean == userClean) {
      return (matchType: MatchType.correct, score: 100.0);
    }

    String compareExpected = expectedClean;
    String compareUser = userClean;
    if (detectedLanguage == 'ml') {
      compareExpected =
          TransliterationService.normalizeMalayalamManglish(compareExpected);
      compareUser =
          TransliterationService.normalizeMalayalamManglish(compareUser);
      if (compareExpected == compareUser) {
        return (matchType: MatchType.correct, score: 100.0);
      }
    }

    final similarity =
        TransliterationService.calculateAccuracy(compareUser, compareExpected);
    if (similarity >= 80.0) return (matchType: MatchType.correct, score: 100.0);
    if (similarity >= 60.0) return (matchType: MatchType.close, score: 70.0);
    return (matchType: MatchType.wrong, score: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceTypeItOut),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        final verse = currentVerse;
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
            child: MemoryPracticeScaffold(
              title: context.tr(TranslationKeys.practiceModeTypeItOut),
              subtitle: verse == null
                  ? null
                  : '${verse.verseReference} · '
                      '${context.tr(TranslationKeys.difficultyHard)}',
              elapsedSeconds: elapsedSeconds,
              onClose: _handleBackNavigation,
              scrollable: verse != null,
              body: verse == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(TranslationKeys.typeItOutInstruction),
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            height: 1.45,
                            color: ReaderPalette.of(context).muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (detectedLanguage != 'en') ...[
                          _buildLanguageHint(),
                          const SizedBox(height: 10),
                        ],
                        WalkthroughTooltip(
                          showcaseKey: ShowcaseKeys.practiceTypeItOut,
                          title: l10n.walkthroughPracticeTypeItOutTitle,
                          description: l10n.walkthroughPracticeTypeItOutDesc,
                          screen: WalkthroughScreen.practiceTypeItOut,
                          stepNumber: 1,
                          totalSteps: 1,
                          onNext: _onNext,
                          tooltipPosition: TooltipPosition.bottom,
                          highlightBorderRadius: 20,
                          child: _buildAnswerCard(),
                        ),
                      ],
                    ),
              bottomBar: verse == null ? null : _buildActionBar(),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

  Widget _buildAnswerCard() {
    final palette = ReaderPalette.of(context);
    return MemoryAnswerCard(
      state: _focusNode.hasFocus
          ? MemoryCardState.focused
          : MemoryCardState.normal,
      minHeight: 210,
      onTap: _focusNode.requestFocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            minLines: 6,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: palette.accentIcon,
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: palette.text,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              // The app theme sets a 16/12 content padding that isCollapsed
              // does not override; the card already pads the field.
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: context.tr(TranslationKeys.typeItOutPlaceholder),
              hintStyle: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.55,
                color: palette.dim,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(TranslationKeys.memoryRecallTypeWordCount, {
              'current': currentWordCount,
              'total': expectedWordCount,
            }),
            style: AppFonts.inter(
              fontSize: 13.5,
              color: palette.muted,
              fontFeatures: kMemoryTabular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageHint() {
    final palette = ReaderPalette.of(context);
    final langName = context.tr(detectedLanguage == 'hi'
        ? TranslationKeys.memoryRecallTypeHinglish
        : TranslationKeys.memoryRecallTypeManglish);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.keyboard_outlined, size: 18, color: palette.gold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(TranslationKeys.memoryRecallTypeRomanizedHint,
                {'lang': langName}),
            style: AppFonts.inter(fontSize: 13.5, color: palette.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return MemoryActionBar(
      secondary: [
        MemoryActionPill(
          label: context.tr(TranslationKeys.practiceClear),
          icon: Icons.backspace_outlined,
          onPressed: _clearInput,
        ),
        MemoryActionPill(
          label: context.tr(TranslationKeys.memoryRecallTypeAnswer),
          icon: Icons.visibility_outlined,
          onPressed: _showAnswer,
        ),
      ],
      primary: MemoryPrimaryPill(
        label: context.tr(TranslationKeys.practiceSubmit),
        onPressed: _textController.text.trim().isNotEmpty ? _checkAnswer : null,
      ),
    );
  }
}
