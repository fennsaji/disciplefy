import 'package:flutter/material.dart';

/// Quality rating buttons for SM-2 algorithm (0-5 scale).
///
/// Displays 6 buttons with clear descriptions:
/// - 0: Complete blackout
/// - 1: Incorrect, but familiar
/// - 2: Incorrect, but remembered parts
/// - 3: Correct with difficulty
/// - 4: Correct with hesitation
/// - 5: Perfect recall
class QualityRatingButtons extends StatelessWidget {
  final Function(int) onRatingSelected;

  const QualityRatingButtons({
    super.key,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRatingButton(
          context: context,
          rating: 5,
          label: 'Perfect!',
          description: 'Perfect recall, no hesitation',
          color: Colors.green,
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 8),
        _buildRatingButton(
          context: context,
          rating: 4,
          label: 'Good',
          description: 'Correct with slight hesitation',
          color: Colors.lightGreen,
          icon: Icons.thumb_up,
        ),
        const SizedBox(height: 8),
        _buildRatingButton(
          context: context,
          rating: 3,
          label: 'Hard',
          description: 'Correct with significant difficulty',
          color: Colors.blue,
          icon: Icons.pending,
        ),
        const SizedBox(height: 8),
        _buildRatingButton(
          context: context,
          rating: 2,
          label: 'Wrong',
          description: 'Incorrect, but remembered parts',
          color: Colors.orange,
          icon: Icons.restart_alt,
        ),
        const SizedBox(height: 8),
        _buildRatingButton(
          context: context,
          rating: 1,
          label: 'Barely',
          description: 'Incorrect, but recognized when shown',
          color: Colors.deepOrange,
          icon: Icons.error_outline,
        ),
        const SizedBox(height: 8),
        _buildRatingButton(
          context: context,
          rating: 0,
          label: 'Forgot',
          description: 'Complete blackout, no memory',
          color: Colors.red,
          icon: Icons.close,
        ),
      ],
    );
  }

  /// Darkens a color for WCAG AA contrast (4.5:1) on light backgrounds
  Color _getDarkenedColor(Color color) {
    // Convert to HSL, reduce lightness to ensure sufficient contrast
    final hslColor = HSLColor.fromColor(color);
    // Target lightness of 0.35-0.40 for dark enough contrast on white
    final darkenedHsl = hslColor.withLightness(0.35);
    return darkenedHsl.toColor();
  }

  Widget _buildRatingButton({
    required BuildContext context,
    required int rating,
    required String label,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    // Use darkened color for text and icons to meet WCAG AA contrast
    final foregroundColor = _getDarkenedColor(color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onRatingSelected(rating),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: foregroundColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Label and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rating.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
