import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Recall rating sheet for passive practice modes (Flip Card, Progressive
/// Reveal), shown after the user has seen the answer.
///
/// Those modes have no measurable input, so the user rates how well they
/// recalled the verse; the rating drives the next review date.
class SelfAssessmentBottomSheet extends StatelessWidget {
  final void Function(SelfAssessmentRating rating) onRatingSelected;

  const SelfAssessmentBottomSheet({
    super.key,
    required this.onRatingSelected,
  });

  /// Shows the sheet and returns the selected rating (null if dismissed).
  static Future<SelfAssessmentRating?> show(BuildContext context) {
    return showModalBottomSheet<SelfAssessmentRating>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => SelfAssessmentBottomSheet(
        onRatingSelected: (rating) {
          Navigator.pop(bottomSheetContext, rating);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupSheet(
      children: [
        PopupHeader(
          title: context.tr(TranslationKeys.selfAssessmentTitle),
          body: context.tr(TranslationKeys.selfAssessmentSubtitle),
        ),
        const SizedBox(height: 20),
        for (final rating in SelfAssessmentRating.values) ...[
          _RatingOption(
            rating: rating,
            onTap: () => onRatingSelected(rating),
          ),
          if (rating != SelfAssessmentRating.values.last)
            const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// One rating row: tone dot, label and one-line description, chevron.
class _RatingOption extends StatelessWidget {
  final SelfAssessmentRating rating;
  final VoidCallback onTap;

  const _RatingOption({
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final tone = MemoryToneColors.of(context, rating.tone);
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      child: Material(
        key: Key('self_assessment_${rating.name}'),
        color: palette.raised,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tone.fill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tone.foreground,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.label(context),
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rating.description(context),
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.dim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-assessment rating levels for passive practice modes.
enum SelfAssessmentRating {
  didNotKnow,
  knewALittle,
  knewHalf,
  knewMost,
  knewPerfectly,
}

extension SelfAssessmentRatingExtension on SelfAssessmentRating {
  /// Colour on the red → amber → gold → green recall scale.
  MemoryTone get tone {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return MemoryTone.error;
      case SelfAssessmentRating.knewALittle:
        return MemoryTone.warning;
      case SelfAssessmentRating.knewHalf:
        return MemoryTone.gold;
      case SelfAssessmentRating.knewMost:
      case SelfAssessmentRating.knewPerfectly:
        return MemoryTone.success;
    }
  }

  String label(BuildContext context) {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return context.tr(TranslationKeys.selfAssessmentDidNotKnow);
      case SelfAssessmentRating.knewALittle:
        return context.tr(TranslationKeys.selfAssessmentKnewALittle);
      case SelfAssessmentRating.knewHalf:
        return context.tr(TranslationKeys.selfAssessmentKnewHalf);
      case SelfAssessmentRating.knewMost:
        return context.tr(TranslationKeys.selfAssessmentKnewMost);
      case SelfAssessmentRating.knewPerfectly:
        return context.tr(TranslationKeys.selfAssessmentKnewPerfectly);
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return context.tr(TranslationKeys.selfAssessmentDidNotKnowDesc);
      case SelfAssessmentRating.knewALittle:
        return context.tr(TranslationKeys.selfAssessmentKnewALittleDesc);
      case SelfAssessmentRating.knewHalf:
        return context.tr(TranslationKeys.selfAssessmentKnewHalfDesc);
      case SelfAssessmentRating.knewMost:
        return context.tr(TranslationKeys.selfAssessmentKnewMostDesc);
      case SelfAssessmentRating.knewPerfectly:
        return context.tr(TranslationKeys.selfAssessmentKnewPerfectlyDesc);
    }
  }

  /// Accuracy percentage for this rating level.
  double get accuracyPercentage {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return 20.0;
      case SelfAssessmentRating.knewALittle:
        return 40.0;
      case SelfAssessmentRating.knewHalf:
        return 60.0;
      case SelfAssessmentRating.knewMost:
        return 80.0;
      case SelfAssessmentRating.knewPerfectly:
        return 100.0;
    }
  }

  /// Quality rating (1-5) for SM-2 algorithm.
  int get qualityRating {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return 1;
      case SelfAssessmentRating.knewALittle:
        return 2;
      case SelfAssessmentRating.knewHalf:
        return 3;
      case SelfAssessmentRating.knewMost:
        return 4;
      case SelfAssessmentRating.knewPerfectly:
        return 5;
    }
  }

  /// Confidence rating (1-5) for practice tracking.
  int get confidenceRating {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return 1;
      case SelfAssessmentRating.knewALittle:
        return 2;
      case SelfAssessmentRating.knewHalf:
        return 3;
      case SelfAssessmentRating.knewMost:
        return 4;
      case SelfAssessmentRating.knewPerfectly:
        return 5;
    }
  }
}
