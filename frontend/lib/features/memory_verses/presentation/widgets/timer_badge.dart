import 'package:flutter/material.dart';

import '../utils/verse_review_utils.dart';

/// A badge widget that displays the elapsed review time.
///
/// Shows a timer icon and the formatted elapsed time in MM:SS format.
/// Uses the theme's primary container color for background.
class TimerBadge extends StatelessWidget {
  /// The elapsed time in seconds to display.
  final int elapsedSeconds;

  const TimerBadge({
    super.key,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              VerseReviewUtils.formatTime(elapsedSeconds),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
