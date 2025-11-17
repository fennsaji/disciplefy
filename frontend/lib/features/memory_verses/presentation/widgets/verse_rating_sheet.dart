import 'package:flutter/material.dart';

import 'quality_rating_buttons.dart';

/// A bottom sheet widget for selecting verse review quality rating.
///
/// Displays a modal bottom sheet with a handle bar, title, and quality rating buttons.
/// When a rating is selected, the sheet is dismissed and the callback is triggered.
class VerseRatingSheet extends StatelessWidget {
  /// Callback invoked when a quality rating is selected.
  ///
  /// The sheet is automatically dismissed before this callback is called.
  final Function(int rating) onRatingSelected;

  const VerseRatingSheet({
    super.key,
    required this.onRatingSelected,
  });

  /// Shows the verse rating bottom sheet.
  ///
  /// [context] - The build context to show the sheet in.
  /// [onRatingSelected] - Callback invoked when a rating is selected.
  static void show(
    BuildContext context, {
    required Function(int rating) onRatingSelected,
  }) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Text(
                  'How well did you remember?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Rating buttons
                QualityRatingButtons(
                  onRatingSelected: (rating) {
                    Navigator.pop(context);
                    onRatingSelected(rating);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is only used via the static show() method
    // The build method is not used
    throw UnimplementedError(
      'VerseRatingSheet should be shown using VerseRatingSheet.show()',
    );
  }
}
