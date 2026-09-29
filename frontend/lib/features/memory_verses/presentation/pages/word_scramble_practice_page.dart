import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
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

/// Phrase scramble practice mode for memory verses.
///
/// Users drag and drop scrambled PHRASES (not individual words) to reconstruct
/// the verse in the correct order. Tests understanding of verse structure
/// at a higher level than Word Bank mode. A phrase can also be tapped to drop
/// it into the next empty slot.
class WordScramblePracticePage extends StatefulWidget {
  final String verseId;

  const WordScramblePracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<WordScramblePracticePage> createState() =>
      _WordScramblePracticePageState();
}

class _WordScramblePracticePageState extends State<WordScramblePracticePage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;
  int hintsUsed = 0;

  List<String> correctPhrases = [];
  List<String> availablePhrases = [];
  List<String?> placedPhrases = [];

  bool isCompleted = false;
  bool showCorrectAnswer = false;

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
      if (await repo.hasSeen(WalkthroughScreen.practiceWordScramble)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        ShowcaseKeys.practiceWordScramble,
        ShowcaseKeys.practiceWordScrambleShowAnswer,
        ShowcaseKeys.practiceWordScrambleReset,
        ShowcaseKeys.practiceWordScrambleSubmit,
      ]);
    });
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
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
          _initializeScramble(fullText);
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

  /// Handle back navigation - go to practice mode selection when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to practice mode selection
      context.go('/memory-verses/practice/${widget.verseId}');
    }
  }

  void _initializeScramble(String verseText) {
    // Split verse into phrases (by punctuation or every 4-5 words)
    correctPhrases = _splitIntoPhrases(verseText);

    // Create scrambled copy
    availablePhrases = List.from(correctPhrases);
    availablePhrases.shuffle(Random());

    // Initialize placed phrases as empty slots
    placedPhrases = List.filled(correctPhrases.length, null);
  }

  /// Split verse text into meaningful phrases based on punctuation
  /// or every 4-5 words for natural chunking.
  List<String> _splitIntoPhrases(String text) {
    final phrases = <String>[];
    // Split on any whitespace (verse text can contain line breaks or double
    // spaces) so phrases never carry stray newlines into the chips or results.
    final words =
        text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final buffer = StringBuffer();
    int wordCount = 0;

    for (int i = 0; i < words.length; i++) {
      buffer.write(words[i]);
      wordCount++;

      // Split on punctuation or every 4-5 words
      final hasPunctuation = words[i].contains(RegExp(r'[.!?,;:]'));
      final isLastWord = i == words.length - 1;

      if (hasPunctuation || wordCount >= 4 || isLastWord) {
        final phrase = buffer.toString().trim();
        if (phrase.isNotEmpty) {
          phrases.add(phrase);
        }
        buffer.clear();
        wordCount = 0;
      } else {
        buffer.write(' ');
      }
    }

    // Ensure we have at least 2 phrases for meaningful scrambling
    if (phrases.length < 2) {
      // Fall back to splitting in half
      final midpoint = words.length ~/ 2;
      return [
        words.take(midpoint).join(' '),
        words.skip(midpoint).join(' '),
      ];
    }

    return phrases;
  }

  void _placePhrase(int targetIndex, String phrase) {
    setState(() {
      // Remove phrase from available pool
      availablePhrases.remove(phrase);

      // If target slot already has a phrase, move it back to available
      if (placedPhrases[targetIndex] != null) {
        availablePhrases.add(placedPhrases[targetIndex]!);
      }

      // Place new phrase in slot
      placedPhrases[targetIndex] = phrase;

      // Check if completed
      _checkCompletion();
    });
  }

  /// Tap-to-place: drops [phrase] into the first empty slot.
  void _placeInNextSlot(String phrase) {
    if (showCorrectAnswer) return;
    final emptyIndex = placedPhrases.indexWhere((p) => p == null);
    if (emptyIndex == -1) return;
    _placePhrase(emptyIndex, phrase);
  }

  void _removePhrase(int index) {
    setState(() {
      if (placedPhrases[index] != null) {
        // Move phrase back to available pool
        availablePhrases.add(placedPhrases[index]!);
        placedPhrases[index] = null;
      }
    });
    // Re-check completion status (will set isCompleted to false if incomplete)
    _checkCompletion();
  }

  void _checkCompletion() {
    // Check if all slots are filled (order correctness shown only in results)
    final allFilled = placedPhrases.every((phrase) => phrase != null);

    setState(() {
      isCompleted = allFilled;
    });
  }

  void _useHint() {
    if (availablePhrases.isEmpty) return;

    setState(() {
      hintsUsed++;

      // Find first empty or incorrect slot
      for (int i = 0; i < correctPhrases.length; i++) {
        if (placedPhrases[i] == null || placedPhrases[i] != correctPhrases[i]) {
          final correctPhrase = correctPhrases[i];

          // If phrase is available, place it
          if (availablePhrases.contains(correctPhrase)) {
            _placePhrase(i, correctPhrase);
            break;
          }
        }
      }
    });
  }

  void _showAnswer() {
    setState(() {
      showCorrectAnswer = true;

      // Place all phrases in correct order
      for (int i = 0; i < correctPhrases.length; i++) {
        placedPhrases[i] = correctPhrases[i];
      }
      availablePhrases.clear();
      isCompleted = true;
    });
  }

  void _reset() {
    if (currentVerse != null) {
      setState(() {
        // Include reference at the end of verse text for memorization
        final fullText =
            '${currentVerse!.verseText} ${currentVerse!.verseReference}';
        _initializeScramble(fullText);
        hintsUsed = 0;
        isCompleted = false;
        showCorrectAnswer = false;
        elapsedSeconds = 0;
      });
    }
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Calculate accuracy with improved algorithm that gives partial credit
    // for misplaced phrases (more fair than all-or-nothing scoring)
    double totalScore = 0.0;

    for (int i = 0; i < correctPhrases.length; i++) {
      final placedPhrase = placedPhrases[i];
      final correctPhrase = correctPhrases[i];

      if (placedPhrase == correctPhrase) {
        // Correct position: full credit (100%)
        totalScore += 1.0;
      } else if (placedPhrase != null &&
          correctPhrases.contains(placedPhrase)) {
        // Wrong position but phrase exists in verse: partial credit (50%)
        totalScore += 0.5;
      }
      // Missing or completely wrong phrase: no credit (0%)
    }

    double accuracy = (totalScore / correctPhrases.length) * 100;

    // If user showed the answer, accuracy is 0
    if (showCorrectAnswer) {
      accuracy = 0.0;
    }

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showCorrectAnswer,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showCorrectAnswer,
    );

    // Collect phrase comparisons for results page
    final phraseComparisons = <BlankComparison>[];
    for (int i = 0; i < correctPhrases.length; i++) {
      final expected = correctPhrases[i];
      final userInput = placedPhrases[i] ?? '(empty)';
      final isCorrect = placedPhrases[i] == expected;

      phraseComparisons.add(BlankComparison(
        expected: expected,
        userInput: userInput,
        isCorrect: isCorrect,
      ));
    }

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'word_scramble',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showCorrectAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
      blankComparisons: phraseComparisons,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  String _hintLabel(BuildContext context) => hintsUsed > 0
      ? context
          .tr(TranslationKeys.memoryPracticeHintCount, {'count': hintsUsed})
      : context.tr(TranslationKeys.memoryPracticeHint);

  @override
  Widget build(BuildContext context) {
    final title = context.tr(TranslationKeys.practiceModeWordScramble);

    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceWordScramble),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;

        if (currentVerse == null) {
          return BlocListener<MemoryVerseBloc, MemoryVerseState>(
            listener: (context, state) {
              if (state is DueVersesLoaded && currentVerse == null) {
                _loadVerse();
              }
            },
            child: MemoryPracticeScaffold(
              title: title,
              onClose: _handleBackNavigation,
              scrollable: false,
              body: const Center(child: CircularProgressIndicator()),
            ).withAuthProtection(),
          );
        }

        final l10n = AppLocalizations.of(context)!;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: MemoryPracticeScaffold(
            title: title,
            subtitle: '${currentVerse!.verseReference} · '
                '${context.tr(TranslationKeys.difficultyMedium)}',
            elapsedSeconds: elapsedSeconds,
            onClose: _handleBackNavigation,
            actions: [
              WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.practiceWordScrambleShowAnswer,
                title: l10n.walkthroughPracticeWordScrambleShowAnswerTitle,
                description: l10n.walkthroughPracticeWordScrambleShowAnswerDesc,
                screen: WalkthroughScreen.practiceWordScramble,
                stepNumber: 2,
                totalSteps: 4,
                onNext: _onNext,
                tooltipPosition: TooltipPosition.bottom,
                highlightBorderRadius: 24,
                child: MemoryBarAction(
                  icon: Icons.visibility_outlined,
                  tooltip: context.tr(TranslationKeys.practiceShowAnswer),
                  onPressed: !isCompleted ? _showAnswer : null,
                ),
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(TranslationKeys.wordScrambleInstruction),
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    height: 1.45,
                    color: ReaderPalette.of(context).muted,
                  ),
                ),
                const SizedBox(height: 12),
                MemoryAnswerCard(
                  radius: 22,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildAnswerSlots(context),
                  ),
                ),
                if (availablePhrases.isNotEmpty)
                  WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.practiceWordScramble,
                    title: l10n.walkthroughPracticeWordScrambleTitle,
                    description: l10n.walkthroughPracticeWordScrambleDesc,
                    screen: WalkthroughScreen.practiceWordScramble,
                    stepNumber: 1,
                    totalSteps: 4,
                    onNext: _onNext,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MemorySectionLabel.muted(
                          context,
                          '${context.tr(TranslationKeys.wordScrambleAvailablePhrases)}'
                          ' (${availablePhrases.length})',
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                        ),
                        for (var i = 0; i < availablePhrases.length; i++)
                          Padding(
                            key: ValueKey(
                                'available_${i}_${availablePhrases[i]}'),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildDraggablePhrase(availablePhrases[i]),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            bottomBar: _ScrambleActionBar(
              hint: MemoryActionPill(
                label: _hintLabel(context),
                icon: Icons.lightbulb_outline_rounded,
                badge: hintsUsed > 0 ? '$hintsUsed' : null,
                onPressed: availablePhrases.isNotEmpty && !showCorrectAnswer
                    ? _useHint
                    : null,
              ),
              reset: _WrappedPill(
                build: (pill) => WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.practiceWordScrambleReset,
                  title: l10n.walkthroughPracticeWordScrambleResetTitle,
                  description: l10n.walkthroughPracticeWordScrambleResetDesc,
                  screen: WalkthroughScreen.practiceWordScramble,
                  stepNumber: 3,
                  totalSteps: 4,
                  onNext: _onNext,
                  highlightBorderRadius: 26,
                  child: pill,
                ),
                pill: MemoryActionPill(
                  label: context.tr(TranslationKeys.practiceReset),
                  icon: Icons.refresh_rounded,
                  onPressed: !isCompleted ? _reset : null,
                ),
              ),
              submit: WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.practiceWordScrambleSubmit,
                title: l10n.walkthroughPracticeWordScrambleSubmitTitle,
                description: l10n.walkthroughPracticeWordScrambleSubmitDesc,
                screen: WalkthroughScreen.practiceWordScramble,
                stepNumber: 4,
                totalSteps: 4,
                onNext: _onNext,
                highlightBorderRadius: 26,
                child: MemoryPrimaryPill(
                  label: context.tr(TranslationKeys.practiceSubmit),
                  onPressed:
                      isCompleted || showCorrectAnswer ? _submitPractice : null,
                ),
              ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

  /// Placed phrases in slot order. Empty slots in the middle (left by
  /// removing a phrase) each get their own drop zone; the trailing run of
  /// empty slots collapses into a single "Drop here" zone for the first one.
  List<Widget> _buildAnswerSlots(BuildContext context) {
    final lastFilled = placedPhrases.lastIndexWhere((p) => p != null);
    final children = <Widget>[];
    for (var i = 0; i < placedPhrases.length; i++) {
      final phrase = placedPhrases[i];
      if (phrase == null && i > lastFilled + 1) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(KeyedSubtree(
        key: ValueKey('drop_target_$i'),
        child: phrase != null
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: MemoryTokenChip(
                  label: phrase,
                  state: showCorrectAnswer
                      ? MemoryTokenState.correct
                      : MemoryTokenState.selected,
                  fontSize: 16,
                  onTap: showCorrectAnswer ? null : () => _removePhrase(i),
                ),
              )
            : _buildDropTarget(i),
      ));
    }
    return children;
  }

  Widget _buildDropTarget(int index) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => placedPhrases[index] == null,
      onAcceptWithDetails: (details) => _placePhrase(index, details.data),
      builder: (context, candidateData, rejectedData) => MemoryDropZone(
        label: context.tr(TranslationKeys.wordScrambleDropHere),
        active: candidateData.isNotEmpty,
        minHeight: 44,
      ),
    );
  }

  Widget _buildDraggablePhrase(String phrase) {
    final palette = ReaderPalette.of(context);
    final handle = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Icon(Icons.drag_indicator_rounded, size: 20, color: palette.dim),
    );

    // Only the handle is draggable, so the list itself stays scrollable;
    // tapping the row places the phrase in the next empty slot.
    return MemoryTokenChip(
      label: phrase,
      expand: true,
      fontSize: 16,
      onTap: () => _placeInNextSlot(phrase),
      leading: Draggable<String>(
        key: ValueKey('draggable_$phrase'),
        data: phrase,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: MemoryTokenChip(
              label: phrase,
              state: MemoryTokenState.selected,
              fontSize: 16,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: handle),
        child: handle,
      ),
    );
  }
}

/// Wraps an action pill in a walkthrough target while still exposing the
/// pill so the bar can collapse it to an icon on narrow screens.
class _WrappedPill {
  final MemoryActionPill pill;
  final Widget Function(Widget pill) build;

  const _WrappedPill({required this.pill, required this.build});
}

/// Bottom bar of the phrase scramble: Hint + Reset (secondary) and Submit.
///
/// Mirrors the shared practice action bar layout but lets the Reset pill
/// and Submit carry their walkthrough targets.
class _ScrambleActionBar extends StatelessWidget {
  final MemoryActionPill hint;
  final _WrappedPill reset;
  final Widget submit;

  const _ScrambleActionBar({
    required this.hint,
    required this.reset,
    required this.submit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.page,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(kMemoryGutter, 8, kMemoryGutter, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Same rule as the shared action bar: whole labels or icons.
              final compact = !MemoryActionBar.labelsFit(
                context,
                constraints.maxWidth,
                [hint, reset.pill],
                submit,
              );
              return Row(
                children: [
                  hint.withIconOnly(compact),
                  const SizedBox(width: 10),
                  reset.build(reset.pill.withIconOnly(compact)),
                  const SizedBox(width: 10),
                  Expanded(child: submit),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
