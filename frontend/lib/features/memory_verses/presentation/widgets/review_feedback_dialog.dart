import 'package:flutter/material.dart';

import '../utils/verse_review_utils.dart';

/// A dialog widget that displays feedback after submitting a verse review.
///
/// Shows the quality rating icon, feedback message, and next review interval.
class ReviewFeedbackDialog extends StatelessWidget {
  /// The quality rating (0-5) given for the review.
  final int qualityRating;

  /// The feedback message to display.
  final String message;

  /// The number of days until the next review.
  final int intervalDays;

  const ReviewFeedbackDialog({
    super.key,
    required this.qualityRating,
    required this.message,
    required this.intervalDays,
  });

  /// Shows the review feedback dialog.
  ///
  /// [context] - The build context to show the dialog in.
  /// [qualityRating] - The quality rating (0-5) given for the review.
  /// [message] - The feedback message to display.
  /// [intervalDays] - The number of days until the next review.
  static void show(
    BuildContext context, {
    required int qualityRating,
    required String message,
    required int intervalDays,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              VerseReviewUtils.getQualityIcon(qualityRating),
              color: VerseReviewUtils.getQualityColor(qualityRating),
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text('Review Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Review',
                    style:
                        Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In $intervalDays days',
                    style: Theme.of(dialogContext).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is only used via the static show() method
    // The build method is not used
    throw UnimplementedError(
      'ReviewFeedbackDialog should be shown using ReviewFeedbackDialog.show()',
    );
  }
}
