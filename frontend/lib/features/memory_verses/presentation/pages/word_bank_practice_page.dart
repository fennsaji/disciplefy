import 'dart:async';
import 'dart:math';

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

/// Word item representing a word in the word bank.
class WordItem {
  final String original;
  final String? transliteration;
  bool isUsed;

  WordItem({
    required this.original,
    this.transliteration,
    this.isUsed = false,
  });
}

/// Word Bank practice mode for memory verses.
///
/// Users tap words from a shuffled word bank to build the verse
/// in the correct order. Simpler than drag-and-drop, works great
/// for all languages including Hindi and Malayalam.
class WordBankPracticePage extends StatefulWidget {
  final String verseId;

  const WordBankPracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<WordBankPracticePage> createState() => _WordBankPracticePageState();
}

class _WordBankPracticePageState extends State<WordBankPracticePage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;
  int hintsUsed = 0;

  List<String> correctWords = [];
  List<WordItem> availableWords = [];
  List<String?> placedWords = [];

  bool isCompleted = false;
  bool showedAnswer = false;
  String detectedLanguage = 'en';

  // Track which words are showing transliteration
  Set<int> showingTransliteration = {};

  // Track which slots were filled by hints (shouldn't count for accuracy)
  Set<int> hintFilledSlots = {};

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
      if (await repo.hasSeen(WalkthroughScreen.practiceWordBank)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceWordBank],
      );
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
          _initializeWordBank(fullText);
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

  void _initializeWordBank(String verseText) {
    // Detect language
    detectedLanguage = TransliterationService.detectLanguage(verseText);

    // Split verse into words (preserving punctuation)
    correctWords =
        verseText.split(' ').where((w) => w.trim().isNotEmpty).toList();

    // Create word items with transliteration
    availableWords = correctWords.map((word) {
      return WordItem(
        original: word,
        transliteration:
            TransliterationService.transliterate(word, detectedLanguage),
      );
    }).toList();

    // Shuffle the available words
    availableWords.shuffle(Random());

    // Initialize placed words as empty slots
    placedWords = List.filled(correctWords.length, null);
  }

  void _selectWord(int availableIndex) {
    if (isCompleted) return;

    final wordItem = availableWords[availableIndex];
    if (wordItem.isUsed) return;

    // Find first empty slot
    final emptySlotIndex = placedWords.indexWhere((w) => w == null);
    if (emptySlotIndex == -1) return;

    setState(() {
      // Place word in the slot
      placedWords[emptySlotIndex] = wordItem.original;
      wordItem.isUsed = true;
    });
  }

  void _removeWord(int slotIndex) {
    if (isCompleted) return;

    final word = placedWords[slotIndex];
    if (word == null) return;

    setState(() {
      // Find the word in available words and mark as not used
      final wordItem = availableWords.firstWhere(
        (w) => w.original == word && w.isUsed,
        orElse: () => availableWords.first,
      );
      wordItem.isUsed = false;

      // Clear the slot
      placedWords[slotIndex] = null;

      // Remove from hint-filled slots if it was placed by hint
      hintFilledSlots.remove(slotIndex);
    });
  }

  void _useHint() {
    if (isCompleted) return;

    setState(() {
      hintsUsed++;

      // Find first empty slot and place the correct word
      for (int i = 0; i < correctWords.length; i++) {
        if (placedWords[i] == null) {
          final correctWord = correctWords[i];

          // Find this word in available words
          final wordItemIndex = availableWords.indexWhere(
            (w) => w.original == correctWord && !w.isUsed,
          );

          if (wordItemIndex != -1) {
            placedWords[i] = correctWord;
            availableWords[wordItemIndex].isUsed = true;
            // Track that this slot was filled by hint
            hintFilledSlots.add(i);
            break;
          }
        }
      }
    });
  }

  void _showAnswer() {
    setState(() {
      showedAnswer = true;

      // Place all words in correct order
      for (int i = 0; i < correctWords.length; i++) {
        placedWords[i] = correctWords[i];
      }

      // Mark all available words as used
      for (final word in availableWords) {
        word.isUsed = true;
      }

      isCompleted = true;
    });

    _submitPractice();
  }

  void _clearAll() {
    if (isCompleted) return;

    setState(() {
      // Clear all placed words
      placedWords = List.filled(correctWords.length, null);

      // Mark all available words as not used
      for (final word in availableWords) {
        word.isUsed = false;
      }

      // Clear hint tracking
      hintFilledSlots.clear();
    });
  }

  void _toggleTransliteration(int index) {
    setState(() {
      if (showingTransliteration.contains(index)) {
        showingTransliteration.remove(index);
      } else {
        showingTransliteration.add(index);
      }
    });
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Calculate accuracy
    final accuracy = _calculateAccuracy();

    // Collect word comparisons for results page
    final wordComparisons = <BlankComparison>[];
    for (int i = 0; i < correctWords.length; i++) {
      final expected = correctWords[i];
      final userInput = placedWords[i] ?? '(empty)';
      final isCorrect = placedWords[i] == expected;

      wordComparisons.add(BlankComparison(
        expected: expected,
        userInput: userInput,
        isCorrect: isCorrect,
      ));
    }

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'word_bank',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
      blankComparisons: wordComparisons,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  double _calculateAccuracy() {
    if (showedAnswer) return 0.0;

    // Improved accuracy calculation with partial credit for misplaced words
    // This is more fair than all-or-nothing scoring
    double totalScore = 0.0;
    int manuallyPlaced = 0;

    for (int i = 0; i < correctWords.length; i++) {
      // Skip slots that were filled by hints
      if (hintFilledSlots.contains(i)) continue;

      manuallyPlaced++;
      final placedWord = placedWords[i];
      final correctWord = correctWords[i];

      if (placedWord == correctWord) {
        // Correct position: full credit (100%)
        totalScore += 1.0;
      } else if (placedWord != null && correctWords.contains(placedWord)) {
        // Wrong position but word exists in verse: partial credit (50%)
        totalScore += 0.5;
      }
      // Missing or completely wrong word: no credit (0%)
    }

    // If all words were placed by hints, accuracy is 0%
    if (manuallyPlaced == 0) return 0.0;

    return (totalScore / manuallyPlaced) * 100;
  }

  bool get _canSubmit => !isCompleted && placedWords.every((w) => w != null);

  void _onSubmitPressed() {
    // Allow submission once all words are placed, regardless of correctness
    setState(() => isCompleted = true);
    _submitPractice();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(TranslationKeys.practiceModeWordBank);

    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceWordBank),
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
        final palette = ReaderPalette.of(context);
        final hintLabel = hintsUsed > 0
            ? context.tr(
                TranslationKeys.memoryPracticeHintCount, {'count': hintsUsed})
            : context.tr(TranslationKeys.memoryPracticeHint);

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
              MemoryBarAction(
                icon: Icons.visibility_outlined,
                tooltip: context.tr(TranslationKeys.practiceShowAnswer),
                onPressed: !isCompleted ? _showAnswer : null,
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(TranslationKeys.wordBankTapWordsInstruction),
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    height: 1.45,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 12),
                MemoryAnswerCard(
                  label: context.tr(TranslationKeys.wordBankYourAnswer),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildAnswerSlots(),
                  ),
                ),
                WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.practiceWordBank,
                  title: l10n.walkthroughPracticeWordBankTitle,
                  description: l10n.walkthroughPracticeWordBankDesc,
                  screen: WalkthroughScreen.practiceWordBank,
                  stepNumber: 1,
                  totalSteps: 1,
                  onNext: _onNext,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MemorySectionLabel.muted(
                        context,
                        context.tr(TranslationKeys.practiceModeWordBank),
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                      ),
                      if (availableWords.isNotEmpty &&
                          availableWords.every((w) => w.isUsed))
                        // Every word is in the answer: say so instead of
                        // leaving the label over an empty area. Placed words
                        // go back to the bank on tap until the answer is
                        // checked.
                        Text(
                          context.tr(isCompleted
                              ? TranslationKeys.wordBankAllPlacedDone
                              : TranslationKeys.wordBankAllPlaced),
                          key: const Key('word_bank_all_placed'),
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            height: 1.45,
                            color: palette.muted,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < availableWords.length; i++)
                              if (!availableWords[i].isUsed) _buildWordChip(i),
                          ],
                        ),
                    ],
                  ),
                ),
                if (detectedLanguage != 'en') ...[
                  const SizedBox(height: 14),
                  Text(
                    context.tr(TranslationKeys.wordBankLongPressHint),
                    style: AppFonts.inter(fontSize: 12.5, color: palette.dim),
                  ),
                ],
              ],
            ),
            bottomBar: MemoryActionBar(
              secondary: [
                MemoryActionPill(
                  label: context.tr(TranslationKeys.practiceClear),
                  icon: Icons.backspace_outlined,
                  onPressed: !isCompleted ? _clearAll : null,
                ),
                MemoryActionPill(
                  label: hintLabel,
                  icon: Icons.lightbulb_outline_rounded,
                  badge: hintsUsed > 0 ? '$hintsUsed' : null,
                  onPressed: !isCompleted ? _useHint : null,
                ),
              ],
              primary: MemoryPrimaryPill(
                label: context.tr(TranslationKeys.practiceSubmit),
                onPressed: _canSubmit ? _onSubmitPressed : null,
              ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

  /// Placed words in slot order, then one placeholder for the next slot.
  /// Gaps left by removing a word show as placeholders in place.
  List<Widget> _buildAnswerSlots() {
    final lastFilled = placedWords.lastIndexWhere((w) => w != null);
    final slots = <Widget>[];
    for (var i = 0; i < placedWords.length; i++) {
      final word = placedWords[i];
      if (word == null && i > lastFilled + 1) continue;
      slots.add(_buildAnswerSlot(i));
    }
    return slots;
  }

  Widget _buildAnswerSlot(int index) {
    final word = placedWords[index];
    if (word == null) {
      return MemoryTokenChip(
        key: ValueKey('answer_slot_$index'),
        label: '',
        state: MemoryTokenState.placeholder,
        minWidth: 70,
      );
    }
    final state = !isCompleted
        ? MemoryTokenState.selected
        : word == correctWords[index]
            ? MemoryTokenState.correct
            : MemoryTokenState.wrong;
    return MemoryTokenChip(
      key: ValueKey('answer_slot_$index'),
      label: word,
      state: state,
      onTap: !isCompleted ? () => _removeWord(index) : null,
    );
  }

  Widget _buildWordChip(int index) {
    final wordItem = availableWords[index];
    final showTranslit = showingTransliteration.contains(index) &&
        wordItem.transliteration != null;

    return GestureDetector(
      key: ValueKey('bank_word_$index'),
      onLongPress: wordItem.transliteration != null && !isCompleted
          ? () => _toggleTransliteration(index)
          : null,
      child: MemoryTokenChip(
        label: showTranslit
            ? '${wordItem.original}\n${wordItem.transliteration}'
            : wordItem.original,
        onTap: !isCompleted ? () => _selectWord(index) : null,
      ),
    );
  }
}
