import 'dart:async';
import 'dart:math';

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

/// Phrase scramble practice mode for memory verses.
///
/// Users drag and drop scrambled PHRASES (not individual words) to reconstruct
/// the verse in the correct order. Tests understanding of verse structure
/// at a higher level than Word Bank mode.
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
          _initializeScramble(fullText);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.reviewVerseNotFound)),
              backgroundColor: Colors.red,
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
    final words = text.split(' ').where((w) => w.trim().isNotEmpty).toList();
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

  bool _isCorrectOrder() {
    for (int i = 0; i < correctPhrases.length; i++) {
      if (placedPhrases[i] != correctPhrases[i]) {
        return false;
      }
    }
    return true;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currentVerse == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(context.tr(TranslationKeys.practiceModeWordScramble))),
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
          title: Text(context.tr(TranslationKeys.practiceModeWordScramble)),
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
                      context.tr(TranslationKeys.wordScrambleInstruction),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withAlpha((0.7 * 255).round()),
                      ),
                    ),
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
                        const Icon(Icons.help, size: 20, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${context.tr(TranslationKeys.practiceHints)}: $hintsUsed',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed:
                          availablePhrases.isNotEmpty && !showCorrectAnswer
                              ? _useHint
                              : null,
                      icon: const Icon(Icons.lightbulb, size: 18),
                      label: Text(context.tr(TranslationKeys.practiceUseHint)),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Verse construction area (drop targets)
              // Gets all remaining space - main work area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(
                        correctPhrases.length,
                        (index) => Padding(
                          key: ValueKey('drop_target_$index'),
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildDropTarget(index),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Available phrases area (drag sources)
              if (availablePhrases.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  color: theme.colorScheme.surfaceVariant
                      .withAlpha((0.3 * 255).round()),
                  child: Center(
                    child: Text(
                      '${context.tr(TranslationKeys.wordScrambleAvailablePhrases)} (0)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant
                            .withAlpha((0.6 * 255).round()),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    color: theme.colorScheme.surfaceVariant
                        .withAlpha((0.3 * 255).round()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr(TranslationKeys.wordScrambleAvailablePhrases)} (${availablePhrases.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children:
                                  availablePhrases.asMap().entries.map((entry) {
                                final phrase = entry.value;
                                return Padding(
                                  key: ValueKey('available_$phrase'),
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildDraggablePhrase(phrase),
                                );
                              }).toList(),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !isCompleted ? _showAnswer : null,
                            icon: const Icon(Icons.visibility),
                            label: Text(
                                context.tr(TranslationKeys.practiceShowAnswer)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !isCompleted ? _reset : null,
                            icon: const Icon(Icons.refresh),
                            label:
                                Text(context.tr(TranslationKeys.practiceReset)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isCompleted || showCorrectAnswer
                            ? _submitPractice
                            : null,
                        icon: const Icon(Icons.check),
                        label: Text(context.tr(TranslationKeys.practiceSubmit)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  Widget _buildDropTarget(int index) {
    final theme = Theme.of(context);
    final placedPhrase = placedPhrases[index];

    return DragTarget<String>(
      onWillAccept: (phrase) => placedPhrase == null,
      onAccept: (phrase) => _placePhrase(index, phrase),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.colorScheme.primary.withAlpha((0.1 * 255).round())
                : (placedPhrase != null
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surfaceVariant
                        .withAlpha((0.5 * 255).round())),
            border: Border.all(
              color: isHovered
                  ? theme.colorScheme.primary
                  : (placedPhrase != null
                      ? theme.colorScheme.outline
                      : Colors.grey.shade300),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: placedPhrase != null
              ? GestureDetector(
                  onTap: () => _removePhrase(index),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          placedPhrase,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr(TranslationKeys.wordScrambleDropHere),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDraggablePhrase(String phrase) {
    final theme = Theme.of(context);

    // Make only the drag handle draggable, rest of the chip is scrollable
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary,
        ),
      ),
      child: Row(
        children: [
          // Only the drag handle is draggable
          Draggable<String>(
            key: ValueKey('draggable_$phrase'),
            data: phrase,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  phrase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Icon(
                  Icons.drag_indicator,
                  size: 24,
                  color: theme.colorScheme.onSecondaryContainer.withAlpha(
                    (0.5 * 255).round(),
                  ),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.secondary.withAlpha((0.1 * 255).round()),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Icon(
                Icons.drag_indicator,
                size: 24,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          // The text area is not draggable - allows scrolling
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                phrase,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
