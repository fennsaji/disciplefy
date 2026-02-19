import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// Self-assessment rating for passive practice modes (Flip Card, Progressive Reveal).
///
/// Since these modes don't have measurable user input, we ask the user
/// to rate how well they knew the verse.
class SelfAssessmentBottomSheet extends StatelessWidget {
  final void Function(SelfAssessmentRating rating) onRatingSelected;

  const SelfAssessmentBottomSheet({
    super.key,
    required this.onRatingSelected,
  });

  /// Shows the self-assessment bottom sheet and returns the selected rating.
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Text(
                context.tr(TranslationKeys.selfAssessmentTitle),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(TranslationKeys.selfAssessmentSubtitle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Rating options
              ...SelfAssessmentRating.values.map(
                (rating) => _RatingOption(
                  rating: rating,
                  onTap: () => onRatingSelected(rating),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingOption extends StatelessWidget {
  final SelfAssessmentRating rating;
  final VoidCallback onTap;

  const _RatingOption({
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: rating.backgroundColor(theme),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  rating.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.label(context),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: rating.textColor(theme),
                        ),
                      ),
                      Text(
                        rating.description(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: rating.textColor(theme).withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: rating.textColor(theme).withAlpha(128),
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
  String get emoji {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return '😟';
      case SelfAssessmentRating.knewALittle:
        return '😕';
      case SelfAssessmentRating.knewHalf:
        return '😐';
      case SelfAssessmentRating.knewMost:
        return '🙂';
      case SelfAssessmentRating.knewPerfectly:
        return '😄';
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

  Color backgroundColor(ThemeData theme) {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return theme.colorScheme.errorContainer.withAlpha(128);
      case SelfAssessmentRating.knewALittle:
        return AppColors.warning.withAlpha(51);
      case SelfAssessmentRating.knewHalf:
        return AppColors.masteryMaster.withAlpha(51);
      case SelfAssessmentRating.knewMost:
        return AppColors.successLight.withAlpha(51);
      case SelfAssessmentRating.knewPerfectly:
        return AppColors.success.withAlpha(51);
    }
  }

  Color textColor(ThemeData theme) {
    switch (this) {
      case SelfAssessmentRating.didNotKnow:
        return theme.colorScheme.error;
      case SelfAssessmentRating.knewALittle:
        return AppColors.warningDark;
      case SelfAssessmentRating.knewHalf:
        return AppColors.warningDark;
      case SelfAssessmentRating.knewMost:
        return AppColors.successDark;
      case SelfAssessmentRating.knewPerfectly:
        return AppColors.successDark;
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
