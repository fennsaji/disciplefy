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
import '../../../../core/theme/app_colors.dart';

/// Helper class to store word alignment results
class _WordMatch {
  final String expected;
  final String userWord;
  final bool isCorrect;

  _WordMatch({
    required this.expected,
    required this.userWord,
    required this.isCorrect,
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
    _startTimer();
    _loadVerse();
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
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
      try {
        final verse = state.verses.firstWhere((v) => v.id == widget.verseId);
        setState(() {
          currentVerse = verse;
          // Include reference at the end of verse text for memorization
          final fullText = '${verse.verseText} ${verse.verseReference}';
          _initializeExpectedText(fullText);
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

    final comparisons = <BlankComparison>[];

    // Use dynamic programming to find the best alignment between expected and user words
    final alignment = _alignWordSequences(expectedWords, userWords);

    for (final match in alignment) {
      comparisons.add(BlankComparison(
        expected: match.expected,
        userInput: match.userWord,
        isCorrect: match.isCorrect,
      ));
    }

    return comparisons;
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
        // User ran out of words - mark remaining as missing
        matches.add(_WordMatch(
          expected: expectedWord,
          userWord: '(missing)',
          isCorrect: false,
        ));
        continue;
      }

      final userWord = user[userIndex];

      // Check if current user word matches current expected word
      if (_isWordCorrect(expectedWord, userWord)) {
        matches.add(_WordMatch(
          expected: expectedWord,
          userWord: userWord,
          isCorrect: true,
        ));
        userIndex++;
      } else {
        // Current word doesn't match - check if user skipped this word
        // Look ahead: does the current user word match the NEXT expected word?
        final isNextWordMatch = expectedIndex + 1 < expected.length &&
            _isWordCorrect(expected[expectedIndex + 1], userWord);

        if (isNextWordMatch) {
          // User likely skipped the current expected word
          matches.add(_WordMatch(
            expected: expectedWord,
            userWord: '(missing)',
            isCorrect: false,
          ));
          // Don't increment userIndex - we'll match this user word with the next expected word
        } else {
          // User typed a wrong word (substitution)
          matches.add(_WordMatch(
            expected: expectedWord,
            userWord: userWord,
            isCorrect: false,
          ));
          userIndex++;
        }
      }
    }

    // Handle extra words typed by user beyond expected length
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

  /// Check if a single word matches (with transliteration support)
  bool _isWordCorrect(String expected, String user) {
    if (user == '(missing)') return false;
    if (expected.isEmpty) return false;

    // Normalize both words for comparison
    final normalizedExpected = expected.toLowerCase().trim();
    final normalizedUser = user.toLowerCase().trim();

    // Remove punctuation
    final expectedClean = normalizedExpected.replaceAll(RegExp(r'[^\w\s]'), '');
    final userClean = normalizedUser.replaceAll(RegExp(r'[^\w\s]'), '');

    // Exact match
    if (expectedClean == userClean) return true;

    // For non-English, use fuzzy matching (85%+ similarity)
    if (detectedLanguage != 'en') {
      final wordAccuracy =
          TransliterationService.calculateAccuracy(userClean, expectedClean);
      return wordAccuracy >= 85.0;
    }

    return false;
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
          title: Text(context.tr(TranslationKeys.practiceModeTypeItOut)),
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
                    // Verse Reference Header
                    _buildVerseReferenceHeader(theme),

                    // Language hint for non-English
                    if (detectedLanguage != 'en') _buildLanguageHint(theme),

                    // Text Input Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: context
                                .tr(TranslationKeys.typeItOutPlaceholder),
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),

                    // Word count row
                    _buildWordCountRow(theme),

                    // Action buttons
                    _buildActionButtons(theme),
                  ],
                ),
              ),
      ),
    ).withAuthProtection();
  }

  Widget _buildVerseReferenceHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        children: [
          Text(
            currentVerse!.verseReference,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.typeItOutInstruction),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageHint(ThemeData theme) {
    final langName =
        detectedLanguage == 'hi' ? 'Hindi (Hinglish)' : 'Malayalam (Manglish)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.keyboard,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Type in romanized $langName',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCountRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Words: $currentWordCount / $expectedWordCount',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton.icon(
            onPressed: _clearInput,
            icon: const Icon(Icons.clear, size: 18),
            label: Text(context.tr(TranslationKeys.practiceClear)),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Show Answer button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAnswer,
                icon: const Icon(Icons.visibility),
                label: Text(context.tr(TranslationKeys.practiceShowAnswer)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Submit button
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _textController.text.trim().isNotEmpty
                    ? _checkAnswer
                    : null,
                icon: const Icon(Icons.check),
                label: Text(context.tr(TranslationKeys.practiceSubmit)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
