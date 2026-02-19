import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import '../../../../core/theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
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
      try {
        final verse = state.verses.firstWhere((v) => v.id == widget.verseId);
        setState(() {
          currentVerse = verse;
          // Include reference at the end of verse text for memorization
          final fullText = '${verse.verseText} ${verse.verseReference}';
          _initializeWordBank(fullText);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.reviewVerseNotFound)),
              backgroundColor: AppColors.error,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.pop();
          });
        }
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _loadVerse();
      });
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

      // Check completion
      _checkCompletion();
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

  void _checkCompletion() {
    // No auto-submit - users must click Submit button
    // This method is kept for potential future use (e.g., visual feedback)
  }

  bool _isCorrectOrder() {
    for (int i = 0; i < correctWords.length; i++) {
      if (placedWords[i] != correctWords[i]) {
        return false;
      }
    }
    return true;
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

      // Check completion
      _checkCompletion();
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

  void _reset() {
    if (currentVerse != null) {
      setState(() {
        // Include reference at the end of verse text for memorization
        final fullText =
            '${currentVerse!.verseText} ${currentVerse!.verseReference}';
        _initializeWordBank(fullText);
        hintsUsed = 0;
        isCompleted = false;
        showedAnswer = false;
        elapsedSeconds = 0;
        showingTransliteration.clear();
        hintFilledSlots.clear();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currentVerse == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(context.tr(TranslationKeys.practiceModeWordBank))),
        body: const Center(child: CircularProgressIndicator()),
      ).withAuthProtection();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
          title: Text(context.tr(TranslationKeys.practiceModeWordBank)),
          actions: [
            TimerBadge(elapsedSeconds: elapsedSeconds, compact: true),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Verse Reference Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primaryContainer,
                child: Column(
                  children: [
                    Text(
                      currentVerse!.verseReference,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(TranslationKeys.wordBankTapWordsInstruction),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withAlpha((0.7 * 255).round()),
                      ),
                    ),
                    if (detectedLanguage != 'en') ...[
                      const SizedBox(height: 4),
                      Text(
                        context.tr(TranslationKeys.wordBankLongPressHint),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withAlpha((0.5 * 255).round()),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Hints counter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help,
                            size: 20, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${context.tr(TranslationKeys.practiceHints)}: $hintsUsed',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: !isCompleted ? _useHint : null,
                      icon: const Icon(Icons.lightbulb, size: 18),
                      label: Text(context.tr(TranslationKeys.practiceUseHint)),
                    ),
                  ],
                ),
              ),

              // Answer area (placed words) - 50% of available space
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(TranslationKeys.wordBankYourAnswer),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline
                                  .withAlpha((0.3 * 255).round()),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                correctWords.length,
                                (index) => _buildAnswerSlot(index),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Word Bank area - 50% of available space
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withAlpha((0.3 * 255).round()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.tr(TranslationKeys.practiceModeWordBank)} (${availableWords.where((w) => !w.isUsed).length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: !isCompleted ? _clearAll : null,
                            icon: const Icon(Icons.clear_all, size: 18),
                            label:
                                Text(context.tr(TranslationKeys.practiceClear)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              availableWords.length,
                              (index) => _buildWordChip(index),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !isCompleted ? _showAnswer : null,
                        icon: const Icon(Icons.visibility),
                        label: Text(
                            context.tr(TranslationKeys.practiceShowAnswer)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        // Allow submission once all words are placed, regardless of correctness
                        onPressed:
                            !isCompleted && placedWords.every((w) => w != null)
                                ? () {
                                    setState(() => isCompleted = true);
                                    _submitPractice();
                                  }
                                : null,
                        icon: const Icon(Icons.check),
                        label: Text(context.tr(TranslationKeys.practiceSubmit)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).withAuthProtection();
  }

  Widget _buildAnswerSlot(int index) {
    final theme = Theme.of(context);
    final word = placedWords[index];
    final isCorrect =
        isCompleted && word != null && word == correctWords[index];
    final isWrong = isCompleted && word != null && word != correctWords[index];

    return GestureDetector(
      onTap: word != null && !isCompleted ? () => _removeWord(index) : null,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 50,
          minHeight: 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: word == null
              ? theme.colorScheme.surfaceContainerHighest
                  .withAlpha((0.5 * 255).round())
              : (isCorrect
                  ? AppColors.success.withAlpha((0.15 * 255).round())
                  : (isWrong
                      ? AppColors.error.withAlpha((0.15 * 255).round())
                      : theme.colorScheme.primaryContainer)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: word == null
                ? theme.colorScheme.outline.withAlpha((0.3 * 255).round())
                : (isCorrect
                    ? AppColors.success
                    : (isWrong ? AppColors.error : theme.colorScheme.primary)),
            width: word == null ? 1 : 2,
            style: word == null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: word != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCorrect
                          ? AppColors.successDark
                          : (isWrong
                              ? AppColors.errorDark
                              : theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  if (!isCompleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.close,
                      size: 14,
                      color: theme.colorScheme.onPrimaryContainer
                          .withAlpha((0.6 * 255).round()),
                    ),
                  ],
                ],
              )
            : Text(
                '${index + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withAlpha((0.5 * 255).round()),
                ),
              ),
      ),
    );
  }

  Widget _buildWordChip(int index) {
    final theme = Theme.of(context);
    final wordItem = availableWords[index];
    final isUsed = wordItem.isUsed;
    final showTranslit = showingTransliteration.contains(index);

    return GestureDetector(
      onTap: !isUsed && !isCompleted ? () => _selectWord(index) : null,
      onLongPress: wordItem.transliteration != null && !isCompleted
          ? () => _toggleTransliteration(index)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUsed
              ? theme.colorScheme.surfaceContainerHighest
                  .withAlpha((0.3 * 255).round())
              : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUsed
                ? theme.colorScheme.outline.withAlpha((0.2 * 255).round())
                : theme.colorScheme.secondary,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              wordItem.original,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isUsed
                    ? theme.colorScheme.onSurface.withAlpha((0.3 * 255).round())
                    : theme.colorScheme.onSecondaryContainer,
                decoration: isUsed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (showTranslit && wordItem.transliteration != null) ...[
              const SizedBox(height: 2),
              Text(
                wordItem.transliteration!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
