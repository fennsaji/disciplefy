import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../data/services/transliteration_service.dart';
import '../../domain/entities/practice_result_params.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../utils/quality_calculator.dart';

/// Unified Practice Results Page for all memory verse practice modes.
///
/// Shows practice completion stats including:
/// - Accuracy percentage with visual indicator
/// - Quality rating (auto-calculated)
/// - Time spent
/// - Hints used
/// - Practice mode
///
/// Provides navigation options:
/// - "Done" - Returns to practice mode selection for this verse
/// - "Practice Again" - Restarts the same practice mode
class PracticeResultsPage extends StatefulWidget {
  final PracticeResultParams params;

  const PracticeResultsPage({
    super.key,
    required this.params,
  });

  @override
  State<PracticeResultsPage> createState() => _PracticeResultsPageState();
}

class _PracticeResultsPageState extends State<PracticeResultsPage> {
  @override
  void initState() {
    super.initState();
    _submitPracticeSession();
  }

  void _submitPracticeSession() {
    // Submit the practice session to the BLoC
    context.read<MemoryVerseBloc>().add(
          SubmitPracticeSessionEvent(
            memoryVerseId: widget.params.verseId,
            practiceMode: widget.params.practiceMode,
            qualityRating: widget.params.qualityRating,
            confidenceRating: widget.params.confidenceRating,
            accuracyPercentage: widget.params.accuracyPercentage,
            timeSpentSeconds: widget.params.timeSpentSeconds,
            hintsUsed: widget.params.hintsUsed,
          ),
        );
  }

  void _handleDone() {
    // Navigate back to practice mode selection for this verse
    // Pass last mode so recommendation can exclude it
    final lastMode = widget.params.practiceMode;
    context.go(
        '/memory-verses/practice/${widget.params.verseId}?lastMode=$lastMode');
  }

  void _handlePracticeAgain() {
    // Navigate directly to the same practice mode
    final verseId = widget.params.verseId;
    final mode = widget.params.practiceMode;

    switch (mode) {
      case 'flip_card':
        context.go('/memory-verses/review/$verseId');
        break;
      case 'word_bank':
        context.go('/memory-verses/practice/word-bank/$verseId');
        break;
      case 'cloze':
        context.go('/memory-verses/practice/cloze/$verseId');
        break;
      case 'first_letter':
        context.go('/memory-verses/practice/first-letter/$verseId');
        break;
      case 'progressive':
        context.go('/memory-verses/practice/progressive/$verseId');
        break;
      case 'word_scramble':
        context.go('/memory-verses/practice/word-scramble/$verseId');
        break;
      case 'audio':
        context.go('/memory-verses/practice/audio/$verseId');
        break;
      case 'type_it_out':
        context.go('/memory-verses/practice/type-it-out/$verseId');
        break;
      default:
        // Fallback to practice mode selection
        context.go('/memory-verses/practice/$verseId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = widget.params;
    final qualityColor =
        QualityCalculator.getQualityColor(params.qualityRating);
    final accuracyColor =
        QualityCalculator.getAccuracyColor(params.accuracyPercentage);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleDone();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleDone,
          ),
          title: Text(context.tr(TranslationKeys.practiceResultsTitle)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Accuracy Circle
                _buildAccuracyCircle(theme, accuracyColor),
                const SizedBox(height: 24),

                // Quality Rating
                _buildQualityRating(theme, qualityColor),
                const SizedBox(height: 32),

                // Verse Reference
                _buildVerseReference(theme),
                const SizedBox(height: 24),

                // Stats Card
                _buildStatsCard(theme),
                const SizedBox(height: 24),

                // Blank Comparisons (Fill in the Blanks mode only)
                if (params.blankComparisons != null &&
                    params.blankComparisons!.isNotEmpty) ...[
                  _buildBlankComparisonsCard(theme),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                _buildActionButtons(theme),
              ],
            ),
          ),
        ),
      ).withAuthProtection(),
    );
  }

  Widget _buildAccuracyCircle(ThemeData theme, Color accuracyColor) {
    final accuracy = widget.params.accuracyPercentage;

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accuracyColor,
          width: 8,
        ),
        color: accuracyColor.withAlpha(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${accuracy.round()}%',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: accuracyColor,
            ),
          ),
          Text(
            context.tr(TranslationKeys.practiceResultsAccuracy),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityRating(ThemeData theme, Color qualityColor) {
    final rating = widget.params.qualityRating;
    final label = widget.params.qualityLabel;

    return Column(
      children: [
        // Stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isFilled = index < rating;
            return Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: isFilled ? qualityColor : Colors.grey.shade300,
              size: 32,
            );
          }),
        ),
        const SizedBox(height: 8),
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: qualityColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: qualityColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerseReference(ThemeData theme) {
    final params = widget.params;

    return Column(
      children: [
        Text(
          params.verseReference,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          params.verseText.length > 100
              ? '${params.verseText.substring(0, 100)}...'
              : params.verseText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final params = widget.params;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatRow(
              theme,
              Icons.timer_outlined,
              context.tr(TranslationKeys.practiceResultsTime),
              params.formattedTime,
            ),
            const Divider(height: 24),
            _buildStatRow(
              theme,
              Icons.lightbulb_outline,
              context.tr(TranslationKeys.practiceResultsHintsUsed),
              params.hintsUsed.toString(),
            ),
            const Divider(height: 24),
            _buildStatRow(
              theme,
              QualityCalculator.getModeIcon(params.practiceMode),
              context.tr(TranslationKeys.practiceResultsMode),
              _getTranslatedModeName(context, params.practiceMode),
            ),
            if (params.showedAnswer) ...[
              const Divider(height: 24),
              _buildStatRow(
                theme,
                Icons.visibility,
                context.tr(TranslationKeys.practiceResultsAnswerShown),
                context.tr(TranslationKeys.practiceResultsPenaltyApplied),
                valueColor: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBlankComparisonsCard(ThemeData theme) {
    final comparisons = widget.params.blankComparisons!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr(TranslationKeys.practiceResultsAnswerComparison),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comparisons list
            ...comparisons.asMap().entries.map((entry) {
              final index = entry.key;
              final comparison = entry.value;
              final isLast = index == comparisons.length - 1;

              return Column(
                children: [
                  _buildComparisonRow(theme, comparison, index + 1),
                  if (!isLast) const Divider(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    ThemeData theme,
    BlankComparison comparison,
    int blankNumber,
  ) {
    final isCorrect = comparison.isCorrect;
    final statusColor = isCorrect ? Colors.green : Colors.red;
    final statusIcon = isCorrect ? Icons.check_circle : Icons.cancel;

    // Detect language and transliterate correct answer for Fill-in-the-Blanks only
    // Fill-in-the-Blanks: Users type romanized text, so show romanized correct answers
    // Word Bank/Phrase Scramble: Users see original script, so show original script
    final params = widget.params;
    final detectedLanguage =
        TransliterationService.detectLanguage(params.verseText);

    String correctAnswerDisplay;
    if (params.practiceMode == 'cloze' && detectedLanguage != 'en') {
      // Fill-in-the-Blanks: Show romanized text for non-English verses
      correctAnswerDisplay = TransliterationService.transliterate(
            comparison.expected,
            detectedLanguage,
          ) ??
          comparison.expected;
    } else {
      // All other modes: Show original script
      correctAnswerDisplay = comparison.expected;
    }

    // Use appropriate label based on practice mode
    final labelKey = params.practiceMode == 'word_bank'
        ? TranslationKeys.practiceResultsWord
        : params.practiceMode == 'word_scramble'
            ? TranslationKeys.practiceResultsPhrase
            : TranslationKeys.practiceResultsBlank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blank/Word number and status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${context.tr(labelKey)} $blankNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              statusIcon,
              size: 20,
              color: statusColor,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // User's answer
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                context.tr(TranslationKeys.practiceResultsYourAnswer),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withAlpha((0.1 * 255).round())
                      : Colors.red.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green.withAlpha((0.3 * 255).round())
                        : Colors.red.withAlpha((0.3 * 255).round()),
                  ),
                ),
                child: Text(
                  comparison.userInput,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color:
                        isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Expected answer (only show if incorrect)
        if (!isCorrect) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  context.tr(TranslationKeys.practiceResultsCorrectAnswer),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Text(
                    correctAnswerDisplay,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleDone,
            icon: const Icon(Icons.check),
            label: Text(context.tr(TranslationKeys.practiceResultsDone)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handlePracticeAgain,
            icon: const Icon(Icons.refresh),
            label:
                Text(context.tr(TranslationKeys.practiceResultsPracticeAgain)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Get translated practice mode name
  String _getTranslatedModeName(BuildContext context, String mode) {
    switch (mode) {
      case 'flip_card':
        return context.tr(TranslationKeys.practiceModeFlipCard);
      case 'word_bank':
        return context.tr(TranslationKeys.practiceModeWordBank);
      case 'cloze':
        return context.tr(TranslationKeys.practiceModeCloze);
      case 'first_letter':
        return context.tr(TranslationKeys.practiceModeFirstLetter);
      case 'progressive':
        return context.tr(TranslationKeys.practiceModeProgressive);
      case 'word_scramble':
        return context.tr(TranslationKeys.practiceModeWordScramble);
      case 'audio':
        return context.tr(TranslationKeys.practiceModeAudio);
      case 'type_it_out':
        return context.tr(TranslationKeys.practiceModeTypeItOut);
      default:
        return mode;
    }
  }
}
