import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/transliteration_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/tier_locked_mode_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/unlock_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_limit_exceeded_dialog.dart';

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
  /// When the verse is due next, taken from the [PracticeSessionSubmitted]
  /// that answers this page's own submission. Held here rather than read
  /// from the bloc's current state, which later events replace and which may
  /// still hold a previous session's result when the page opens.
  DateTime? _nextReviewDate;

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
    final params = widget.params;
    final palette = ReaderPalette.of(context);

    return BlocListener<MemoryVerseBloc, MemoryVerseState>(
      listener: (context, state) {
        // submit-memory-practice already runs the achievement check
        // server-side; queue its result directly instead of re-checking
        // (a second RPC call races the same idempotent insert and always
        // reports is_new=false, silently dropping the unlock popup).
        if (state is PracticeSessionSubmitted &&
            state.newAchievements.isNotEmpty) {
          sl<GamificationBloc>()
              .add(QueueAchievementNotifications(state.newAchievements));
        }

        if (state is PracticeSessionSubmitted) {
          final verse = state.verse;
          if (verse != null && verse.id == params.verseId) {
            setState(() => _nextReviewDate = verse.nextReviewDate);
          }
        }

        // Handle tier-locked error
        if (state is MemoryVerseError &&
            state.code == 'PRACTICE_MODE_TIER_LOCKED') {
          // Show tier-locked dialog
          // Note: In production, we'd parse the error details from the failure
          // For now, show a generic dialog
          TierLockedModeDialog.show(
            context,
            mode: params.practiceMode,
            currentTier: 'free', // TODO: Get from user subscription
            availableModes: ['flip_card', 'type_it_out'],
            requiredTier: 'standard',
            message: context.tr(TranslationKeys.commonErrorTryAgain),
          );
        }

        // Handle unlock limit exceeded error
        if (state is MemoryVerseError &&
            state.code == 'PRACTICE_UNLOCK_LIMIT_EXCEEDED') {
          // Show unlock limit exceeded dialog
          // Note: In production, we'd parse the error details from the failure
          UnlockLimitExceededDialog.show(
            context,
            unlockedModes: [], // TODO: Parse from error details
            unlockedCount: 1,
            limit: 1,
            tier: 'free', // TODO: Get from user subscription
            verseReference: params.verseReference,
          );
        }

        // Handle daily review limit reached
        if (state is MemoryVerseError &&
            state.code == 'DAILY_REVIEW_LIMIT_REACHED') {
          DailyReviewLimitDialog.show(
            context,
            currentTier: 'free', // TODO: Get from user subscription
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleDone();
        },
        child: Scaffold(
          backgroundColor: palette.page,
          appBar: MemoryTopBar(
            title: context.tr(TranslationKeys.practiceComplete),
            subtitle:
                '${_getTranslatedModeName(context, params.practiceMode)} · ${params.verseReference}',
            useCloseIcon: true,
            onBack: _handleDone,
          ),
          body: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(kMemoryGutter, 8, kMemoryGutter, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _buildAccuracyRing()),
                const SizedBox(height: 16),
                _buildQualityStars(params.qualityRating),
                const SizedBox(height: 8),
                Text(
                  _qualityLabel(context, params.qualityRating),
                  textAlign: TextAlign.center,
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                _buildNextReview(),
                const SizedBox(height: 14),
                _buildVerseExcerpt(),
                const SizedBox(height: 18),
                _buildStatTiles(),
                if (params.showedAnswer) ...[
                  const SizedBox(height: 10),
                  _buildPenaltyNote(),
                ],
                if (params.blankComparisons != null &&
                    params.blankComparisons!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildAnswerCard(params.blankComparisons!),
                ],
              ],
            ),
          ),
          bottomNavigationBar: MemoryActionBar(
            secondary: [
              MemoryActionPill(
                label: context.tr(TranslationKeys.practiceResultsPracticeAgain),
                onPressed: _handlePracticeAgain,
              ),
            ],
            primary: MemoryPrimaryPill(
              label: context.tr(TranslationKeys.practiceResultsDone),
              onPressed: _handleDone,
            ),
          ),
        ),
      ),
    ).withAuthProtection();
  }

  MemoryTone get _accuracyTone {
    final accuracy = widget.params.accuracyPercentage;
    if (accuracy >= 80) return MemoryTone.success;
    if (accuracy >= 50) return MemoryTone.gold;
    return MemoryTone.error;
  }

  /// Five stars for the recall quality (1-5), filled up to the rating.
  Widget _buildQualityStars(int rating) {
    final palette = ReaderPalette.of(context);
    final safe = rating.clamp(0, 5);
    return Semantics(
      label: '$safe / 5',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < safe ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 26,
              color: i < safe ? palette.gold : palette.dim,
            ),
        ],
      ),
    );
  }

  /// The practised verse: reference and the start of its text.
  Widget _buildVerseExcerpt() {
    final palette = ReaderPalette.of(context);
    final params = widget.params;
    return Column(
      children: [
        Text(
          params.verseReference,
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          params.verseText,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.inter(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: palette.muted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  /// "Answer Shown: Yes (penalty applied)" under the tiles.
  Widget _buildPenaltyNote() {
    final warning = MemoryToneColors.of(context, MemoryTone.warning);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.visibility_outlined, size: 17, color: warning.foreground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${context.tr(TranslationKeys.practiceResultsAnswerShown)}: '
            '${context.tr(TranslationKeys.practiceResultsPenaltyApplied)}',
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: warning.foreground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyRing() {
    final palette = ReaderPalette.of(context);
    final tone = MemoryToneColors.of(context, _accuracyTone);
    final accuracy = widget.params.accuracyPercentage.clamp(0.0, 100.0);
    final sweepIn = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label:
          '${accuracy.round()}% ${context.tr(TranslationKeys.practiceResultsAccuracy)}',
      excludeSemantics: true,
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // One short sweep-in on first build, then static.
            TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: sweepIn ? 0 : accuracy / 100, end: accuracy / 100),
              duration:
                  sweepIn ? const Duration(milliseconds: 700) : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => CustomPaint(
                key: const Key('practice_results_accuracy_arc'),
                size: const Size.square(150),
                painter: AccuracyArcPainter(
                  progress: progress,
                  trackColor: palette.raised,
                  arcColor: tone.foreground,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${accuracy.round()}%',
                      style: AppFonts.poppins(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        fontFeatures: kMemoryTabular,
                      ),
                    ),
                  ),
                  Text(
                    context.tr(TranslationKeys.practiceResultsAccuracy),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gold "Next review in N days / tomorrow / today", shown once the
  /// submission returns the rescheduled verse.
  Widget _buildNextReview() {
    final palette = ReaderPalette.of(context);
    final next = _nextReviewDate;
    if (next == null) return const SizedBox(height: 8);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = next.toLocal();
    final days =
        DateTime(local.year, local.month, local.day).difference(today).inDays;
    final String text;
    if (days <= 0) {
      text = context.tr(TranslationKeys.memoryScreensNextReviewToday);
    } else if (days == 1) {
      text = context.tr(TranslationKeys.memoryScreensNextReviewTomorrow);
    } else {
      text = context.tr(TranslationKeys.memoryScreensNextReviewInDays,
          {'count': days.toString()});
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        key: const Key('practice_results_next_review'),
        textAlign: TextAlign.center,
        style: AppFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.gold,
        ),
      ),
    );
  }

  Widget _buildStatTiles() {
    final params = widget.params;
    return MemoryStatRow(
      tiles: [
        MemoryStatTile(
          value: formatPracticeDuration(params.timeSpentSeconds),
          label: context.tr(TranslationKeys.memoryScreensStatTime),
        ),
        MemoryStatTile(
          value: params.hintsUsed.toString(),
          label: context.tr(params.hintsUsed == 1
              ? TranslationKeys.memoryScreensStatHint
              : TranslationKeys.memoryScreensStatHints),
        ),
        MemoryStatTile(
          value: context.tr(params.showedAnswer
              ? TranslationKeys.memoryScreensYes
              : TranslationKeys.memoryScreensNo),
          valueColor: params.showedAnswer ? context.appWarning : null,
          label: context.tr(TranslationKeys.memoryScreensStatAnswerShown),
        ),
      ],
    );
  }

  /// The typed / placed answer as a green-and-red word diff, then the words
  /// that were missed or misspelled.
  Widget _buildAnswerCard(List<BlankComparison> comparisons) {
    final palette = ReaderPalette.of(context);
    final params = widget.params;
    final detectedLanguage =
        TransliterationService.detectLanguage(params.verseText);

    // One flowing paragraph: each placed word or phrase is trimmed, inner
    // whitespace collapsed, and joined to the next by a single space, so
    // multi-word phrases wrap like prose instead of as separate blocks.
    final spans = <TextSpan>[];
    final missed = <String>[];
    for (final comparison in comparisons) {
      final isExtraWord = comparison.expected == '(extra)';
      final isClose = comparison.matchType == MatchType.close;
      // Unfilled blanks/slots are marked '(missing)' or '(empty)'; they show
      // under "Missed", not as typed words.
      final isMissing = comparison.userInput == '(missing)' ||
          comparison.userInput == '(empty)';
      final input = comparison.userInput.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (!isMissing && input.isNotEmpty) {
        final color = isExtraWord || !comparison.isCorrect
            ? context.appError
            : isClose
                ? palette.gold
                : context.appSuccess;
        if (spans.isNotEmpty) spans.add(const TextSpan(text: ' '));
        spans.add(TextSpan(
          text: input,
          style: TextStyle(
            color: color,
            decoration: isExtraWord ? TextDecoration.lineThrough : null,
            decorationColor: color,
          ),
        ));
      }
      if (!isExtraWord && (!comparison.isCorrect || isClose)) {
        // Fill-in-the-blanks is typed in Roman script, so show the expected
        // word romanized for Hindi/Malayalam verses; other modes place the
        // original words, so keep the original script.
        final expected =
            params.practiceMode == 'cloze' && detectedLanguage != 'en'
                ? (TransliterationService.transliterate(
                        comparison.expected, detectedLanguage) ??
                    comparison.expected)
                : comparison.expected;
        missed.add(expected.trim().replaceAll(RegExp(r'\s+'), ' '));
      }
    }

    return MemoryAnswerCard(
      label: context.tr(TranslationKeys.practiceResultsYourAnswer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spans.isEmpty)
            Text('—', style: AppFonts.inter(fontSize: 16, color: palette.muted))
          else
            Text.rich(
              TextSpan(children: spans),
              key: const Key('practice_results_answer'),
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: palette.text,
              ),
            ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.memoryScreensMissed,
                  {'words': '“${missed.join(' ')}”'}),
              style: AppFonts.inter(
                fontSize: 13.5,
                color: palette.muted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _qualityLabel(BuildContext context, int rating) {
    switch (rating) {
      case 5:
        return context.tr(TranslationKeys.memoryScreensQualityPerfect);
      case 4:
        return context.tr(TranslationKeys.memoryScreensQualityGood);
      case 3:
        return context.tr(TranslationKeys.memoryScreensQualityOk);
      case 2:
        return context.tr(TranslationKeys.memoryScreensQualityNeedsWork);
      default:
        return context.tr(TranslationKeys.memoryScreensQualityTryAgain);
    }
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

/// Accuracy ring: a full track circle and, over it, a round-capped arc that
/// starts at 12 o'clock and sweeps clockwise for [progress] (0..1).
class AccuracyArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const AccuracyArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(AccuracyArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
