import 'dart:async';

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
import 'cloze_models.dart';
import '../../../../core/theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
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
      try {
        final verse = state.verses.firstWhere((v) => v.id == widget.verseId);
        setState(() {
          currentVerse = verse;
          detectedLanguage =
              TransliterationService.detectLanguage(verse.verseText);
          _initializeWordEntries();
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

  void _initializeWordEntries() {
    if (currentVerse == null) return;

    // Only tokenize verseText for cloze blanks (exclude reference)
    // The reference is displayed separately in the UI
    final verseText = currentVerse!.verseText;
    final words = verseText.split(' ');
    final blankInterval = _getBlankInterval();
    wordEntries = [];

    for (int i = 0; i < words.length; i++) {
      final isBlank = (i + 1) % blankInterval == 0;
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

  int _getBlankInterval() {
    switch (widget.difficulty) {
      case ClozeDifficulty.easy:
        return 5;
      case ClozeDifficulty.medium:
        return 3;
      case ClozeDifficulty.hard:
        return 2;
    }
  }

  void _onInputChanged(int index) {
    final entry = wordEntries.firstWhere((e) => e.index == index);
    entry.userInput = blankControllers[index]!.text;

    _calculateAccuracy();
  }

  void _calculateAccuracy() {
    final blanks = wordEntries.where((e) => e.isBlank);
    final correctBlanks =
        blanks.where((e) => _isWordCorrect(e.word, e.userInput));

    final accuracy =
        blanks.isEmpty ? 0.0 : (correctBlanks.length / blanks.length) * 100;
    final allFilled = blanks.every((e) => e.userInput.isNotEmpty);

    setState(() {
      accuracyPercentage = accuracy;
      isCompleted = allFilled;
    });
  }

  bool _isWordCorrect(String target, String input) {
    if (input.isEmpty) return false;

    // For non-English verses, transliterate the target word and compare
    // User types romanized input (Hinglish/Manglish)
    String normalizedTarget;
    if (detectedLanguage != 'en') {
      // Transliterate Hindi/Malayalam word to romanized form
      final transliterated =
          TransliterationService.transliterate(target, detectedLanguage);
      normalizedTarget = (transliterated ?? target).toLowerCase().trim();
    } else {
      normalizedTarget = target.toLowerCase().trim();
    }

    final normalizedInput = input.toLowerCase().trim();

    // Remove punctuation for comparison
    final targetWithoutPunctuation =
        normalizedTarget.replaceAll(RegExp(r'[^\w\s]'), '');
    final inputWithoutPunctuation =
        normalizedInput.replaceAll(RegExp(r'[^\w\s]'), '');

    // Exact match
    if (targetWithoutPunctuation == inputWithoutPunctuation) return true;

    // For non-English, use fuzzy matching with high threshold (85%+)
    // to account for spelling variations in Hinglish/Manglish
    if (detectedLanguage != 'en') {
      final accuracy = TransliterationService.calculateAccuracy(
        inputWithoutPunctuation,
        targetWithoutPunctuation,
      );
      return accuracy >= 85.0;
    }

    return false;
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Fill-in-the-Blanks mode has no hint button, so hintsUsed is always 0
    final blanks = wordEntries.where((e) => e.isBlank).toList();
    const int hintsUsed = 0;

    // Collect blank comparisons for results page
    final blankComparisons = blanks.map((entry) {
      final isCorrect = _isWordCorrect(entry.word, entry.userInput);
      return BlankComparison(
        expected: entry.word,
        userInput: entry.userInput.isEmpty ? '(empty)' : entry.userInput,
        isCorrect: isCorrect,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _ClozeVerseView(
                          wordEntries: wordEntries,
                          blankControllers: blankControllers,
                          showFeedback: false,
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
                          label:
                              Text(context.tr(TranslationKeys.practiceSubmit)),
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
                    ),
                  ],
                ),
              ),
      ),
    ).withAuthProtection();
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
