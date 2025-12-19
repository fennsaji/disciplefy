import 'package:flutter/material.dart';

import '../utils/verse_review_utils.dart';

/// A badge widget that displays the elapsed review time.
///
/// Shows a timer icon and the formatted elapsed time in MM:SS format.
/// Uses the theme's primary container color for background.
class TimerBadge extends StatelessWidget {
  /// The elapsed time in seconds to display.
  final int elapsedSeconds;

  /// Whether this badge is used in an AppBar (uses compact padding).
  final bool compact;

  const TimerBadge({
    super.key,
    required this.elapsedSeconds,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use explicit colors for better contrast in both themes
    final backgroundColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.3)
        : theme.colorScheme.primaryContainer;
    final contentColor =
        isDark ? Colors.white : theme.colorScheme.onPrimaryContainer;

    return Padding(
      padding: EdgeInsets.all(compact ? 4.0 : 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: 20,
              color: contentColor,
            ),
            const SizedBox(width: 8),
            Text(
              VerseReviewUtils.formatTime(elapsedSeconds),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
