import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_mode_entity.dart';
import '../../domain/entities/practice_result_params.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/self_assessment_bottom_sheet.dart';
import '../widgets/timer_badge.dart';

/// Progressive reveal practice mode for memory verses.
///
/// Reveals the verse word-by-word or phrase-by-phrase to help users
/// memorize in chunks using the chunking cognitive principle.
/// Users can control the reveal speed and choose between word or phrase mode.
class ProgressiveRevealPracticePage extends StatefulWidget {
  final String verseId;

  const ProgressiveRevealPracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<ProgressiveRevealPracticePage> createState() =>
      _ProgressiveRevealPracticePageState();
}

class _ProgressiveRevealPracticePageState
    extends State<ProgressiveRevealPracticePage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  Timer? revealTimer;
  int elapsedSeconds = 0;
  int currentRevealIndex = 0;
  bool isAutoRevealing = false;
  bool isCompleted = false;
  RevealMode revealMode = RevealMode.word;
  int revealSpeedSeconds = 2; // Seconds between auto-reveals

  List<String> chunks = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
    revealTimer?.cancel();
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
          _splitTextIntoChunks(fullText);
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

  void _splitTextIntoChunks(String text) {
    if (revealMode == RevealMode.word) {
      // Split by words (space-separated)
      chunks = text.split(' ');
    } else {
      // Split by phrases (punctuation or every 4-5 words)
      chunks = _splitIntoPhrases(text);
    }
  }

  List<String> _splitIntoPhrases(String text) {
    final phrases = <String>[];
    final words = text.split(' ');
    final buffer = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      buffer.write(words[i]);

      // Split on punctuation or every 4-5 words
      final hasPunctuation = words[i].contains(RegExp(r'[.!?,;:]'));

      final wordCount = buffer.toString().split(' ').length;
      if (hasPunctuation || wordCount >= 5 || i == words.length - 1) {
        phrases.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(' ');
      }
    }

    return phrases;
  }

  void _revealNext() {
    if (currentRevealIndex < chunks.length - 1) {
      setState(() {
        currentRevealIndex++;
      });
      // Check if we've now revealed everything
      if (currentRevealIndex >= chunks.length - 1) {
        _completeReveal();
      }
    }
  }

  void _revealAll() {
    setState(() {
      currentRevealIndex = chunks.length - 1;
    });
    _completeReveal();
  }

  void _completeReveal() {
    setState(() {
      isCompleted = true;
      isAutoRevealing = false;
    });
    revealTimer?.cancel();
  }

  void _toggleAutoReveal() {
    setState(() {
      isAutoRevealing = !isAutoRevealing;
    });

    if (isAutoRevealing) {
      revealTimer = Timer.periodic(
        Duration(seconds: revealSpeedSeconds),
        (timer) {
          if (currentRevealIndex < chunks.length - 1) {
            _revealNext();
          } else {
            _completeReveal();
          }
        },
      );
    } else {
      revealTimer?.cancel();
    }
  }

  void _changeRevealMode(RevealMode newMode) {
    if (newMode == revealMode) return;

    setState(() {
      revealMode = newMode;
      currentRevealIndex = 0;
      isAutoRevealing = false;
    });
    revealTimer?.cancel();

    if (currentVerse != null) {
      // Include reference at the end of verse text for memorization
      final fullText =
          '${currentVerse!.verseText} ${currentVerse!.verseReference}';
      _splitTextIntoChunks(fullText);
    }
  }

  Future<void> _submitPractice() async {
    if (currentVerse == null) return;

    // Show self-assessment bottom sheet for passive mode
    final rating = await SelfAssessmentBottomSheet.show(context);

    // User cancelled
    if (rating == null || !mounted) return;

    // Stop the timer
    practiceTimer?.cancel();

    // Use self-assessment values
    final accuracy = rating.accuracyPercentage;
    final quality = rating.qualityRating;
    final confidence = rating.confidenceRating;
    const hintsUsed = 0;
    const showedAnswer = false;

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'progressive',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currentVerse == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(context.tr(TranslationKeys.practiceModeProgressive))),
        body: const Center(child: CircularProgressIndicator()),
      ).withAuthProtection();
    }

    // Get revealed chunks
    final revealedChunks = chunks.take(currentRevealIndex + 1).toList();
    final revealedText = revealedChunks.join(' ');

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
          title: Text(context.tr(TranslationKeys.practiceModeProgressive)),
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
                      context.tr(revealMode == RevealMode.word
                          ? TranslationKeys.progressiveRevealWordByWord
                          : TranslationKeys.progressiveRevealPhraseByPhrase),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withAlpha((0.7 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ),

              // Mode selector
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(
                            context.tr(TranslationKeys.progressiveWordByWord)),
                        selected: revealMode == RevealMode.word,
                        onSelected: (_) => _changeRevealMode(RevealMode.word),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(context
                            .tr(TranslationKeys.progressivePhraseByPhrase)),
                        selected: revealMode == RevealMode.phrase,
                        onSelected: (_) => _changeRevealMode(RevealMode.phrase),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: chunks.isEmpty
                          ? 0
                          : (currentRevealIndex + 1) / chunks.length,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentRevealIndex + 1} / ${chunks.length} ${context.tr(revealMode == RevealMode.word ? TranslationKeys.progressiveWords : TranslationKeys.progressivePhrases)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Revealed text display
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      revealedText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        height: 1.8,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Control buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: currentRevealIndex < chunks.length - 1
                                ? _revealNext
                                : null,
                            icon: const Icon(Icons.navigate_next),
                            label: Text(context
                                .tr(TranslationKeys.progressiveRevealNext)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !isCompleted ? _toggleAutoReveal : null,
                            icon: Icon(isAutoRevealing
                                ? Icons.pause
                                : Icons.play_arrow),
                            label: Text(context.tr(isAutoRevealing
                                ? TranslationKeys.progressivePause
                                : TranslationKeys.progressiveAutoReveal)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: !isCompleted ? _revealAll : null,
                            icon: const Icon(Icons.visibility),
                            label: Text(context
                                .tr(TranslationKeys.progressiveRevealAll)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isCompleted ? _submitPractice : null,
                            icon: const Icon(Icons.check),
                            label: Text(
                                context.tr(TranslationKeys.practiceSubmit)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
}

/// Reveal mode for progressive practice
enum RevealMode {
  word, // Word by word
  phrase, // Phrase by phrase
}
