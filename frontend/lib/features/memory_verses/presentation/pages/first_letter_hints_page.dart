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

/// First letter hints practice mode.
///
/// Shows first letter of each word with tap-to-reveal functionality.
/// Tracks hint usage (how many words were revealed).
/// Goal: Minimize hints used for higher score.
class FirstLetterHintsPage extends StatefulWidget {
  final String verseId;

  const FirstLetterHintsPage({
    super.key,
    required this.verseId,
  });

  @override
  State<FirstLetterHintsPage> createState() => _FirstLetterHintsPageState();
}

class _FirstLetterHintsPageState extends State<FirstLetterHintsPage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;
  List<HintWord> hintWords = [];
  int hintsUsed = 0;
  bool isCompleted = false;

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
          _initializeHintWords();
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

  void _initializeHintWords() {
    if (currentVerse == null) return;

    // Include reference at the end of verse text for memorization
    final fullText =
        '${currentVerse!.verseText} ${currentVerse!.verseReference}';
    final words = fullText.split(' ');
    hintWords = words.map((word) {
      final firstLetter = word.isNotEmpty ? word[0] : '';
      final hint = firstLetter + '_' * (word.length - 1);
      return HintWord(
        word: word,
        hint: hint,
        isRevealed: false,
      );
    }).toList();
  }

  void _revealWord(int index) {
    if (hintWords[index].isRevealed) return;

    setState(() {
      hintWords[index].isRevealed = true;
      hintsUsed++;
    });
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Calculate accuracy based on hints used
    // Fewer hints = higher accuracy
    final totalWords = hintWords.length;
    final accuracy = totalWords > 0
        ? ((totalWords - hintsUsed) / totalWords * 100).clamp(0.0, 100.0)
        : 100.0;

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'first_letter',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
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
          title: Text(context.tr(TranslationKeys.practiceModeFirstLetter)),
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
                    _HintsBadge(
                      hintsUsed: hintsUsed,
                      totalWords: hintWords.length,
                    ),
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
                    const SizedBox(height: 16),
                    // Instructions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        context.tr(TranslationKeys.firstLetterInstruction),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _HintWordsView(
                          hintWords: hintWords,
                          onWordTap: _revealWord,
                        ),
                      ),
                    ),
                    // Submit Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitPractice,
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

/// Hint word entry
class HintWord {
  final String word;
  final String hint;
  bool isRevealed;

  HintWord({
    required this.word,
    required this.hint,
    required this.isRevealed,
  });
}

/// Hints used badge
class _HintsBadge extends StatelessWidget {
  final int hintsUsed;
  final int totalWords;

  const _HintsBadge({
    required this.hintsUsed,
    required this.totalWords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = totalWords > 0 ? (hintsUsed / totalWords) * 100 : 0;

    final color = percentage <= 20
        ? Colors.green
        : percentage <= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            percentage <= 20
                ? Icons.lightbulb_outline
                : percentage <= 50
                    ? Icons.lightbulb
                    : Icons.lightbulb,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Hints Used: $hintsUsed/$totalWords',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hint words view
class _HintWordsView extends StatelessWidget {
  final List<HintWord> hintWords;
  final ValueChanged<int> onWordTap;

  const _HintWordsView({
    required this.hintWords,
    required this.onWordTap,
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
        spacing: 8,
        runSpacing: 12,
        children: hintWords.asMap().entries.map((entry) {
          final index = entry.key;
          final hintWord = entry.value;

          return _HintWordChip(
            hintWord: hintWord,
            onTap: () => onWordTap(index),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual hint word chip
class _HintWordChip extends StatelessWidget {
  final HintWord hintWord;
  final VoidCallback onTap;

  const _HintWordChip({
    required this.hintWord,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: hintWord.isRevealed ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hintWord.isRevealed
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hintWord.isRevealed
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha((0.3 * 255).round()),
            width: hintWord.isRevealed ? 2 : 1,
          ),
        ),
        child: Text(
          hintWord.isRevealed ? hintWord.word : hintWord.hint,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight:
                hintWord.isRevealed ? FontWeight.bold : FontWeight.normal,
            color: hintWord.isRevealed
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
            fontFamily: hintWord.isRevealed ? null : 'monospace',
          ),
        ),
      ),
    );
  }
}
