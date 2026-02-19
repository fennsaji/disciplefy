import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';

/// Milestone celebration dialog.
///
/// Displays animated celebration when user reaches a streak milestone.
/// Shows:
/// - Animated confetti/celebration
/// - Milestone days (10, 30, 100, 365)
/// - Congratulatory message
/// - XP reward earned
/// - Motivational message
class MilestoneCelebrationDialog extends StatelessWidget {
  final int milestoneDays;
  final int xpEarned;

  const MilestoneCelebrationDialog({
    super.key,
    required this.milestoneDays,
    required this.xpEarned,
  });

  /// Shows the milestone celebration dialog.
  static Future<void> show(
    BuildContext context, {
    required int milestoneDays,
    required int xpEarned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MilestoneCelebrationDialog(
        milestoneDays: milestoneDays,
        xpEarned: xpEarned,
      ),
    );
  }

  String _getMilestoneTitle() {
    switch (milestoneDays) {
      case 10:
        return '10-Day Streak!';
      case 30:
        return '30-Day Streak!';
      case 100:
        return '100-Day Streak!';
      case 365:
        return 'Full Year Streak!';
      default:
        return '$milestoneDays-Day Streak!';
    }
  }

  String _getMotivationalMessage() {
    switch (milestoneDays) {
      case 10:
        return 'You\'re building a great habit! Keep going!';
      case 30:
        return 'A month of dedication! Your commitment is inspiring!';
      case 100:
        return 'Incredible persistence! You\'re a memorization champion!';
      case 365:
        return 'An entire year of faithfulness! You\'re amazing!';
      default:
        return 'Your dedication is inspiring!';
    }
  }

  IconData _getMilestoneIcon() {
    switch (milestoneDays) {
      case 10:
        return Icons.stars;
      case 30:
        return Icons.emoji_events;
      case 100:
        return Icons.military_tech;
      case 365:
        return Icons.workspace_premium;
      default:
        return Icons.celebration;
    }
  }

  Color _getMilestoneColor() {
    switch (milestoneDays) {
      case 10:
        return AppColors.info;
      case 30:
        return AppColors.masteryAdvanced;
      case 100:
        return AppColors.warning;
      case 365:
        return AppColors.masteryMaster;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final milestoneColor = _getMilestoneColor();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Milestone icon with animation
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    milestoneColor.withAlpha((0.3 * 255).round()),
                    milestoneColor.withAlpha((0.1 * 255).round()),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getMilestoneIcon(),
                size: 80,
                color: milestoneColor,
              ),
            ),
            const SizedBox(height: 24),

            // Milestone title
            Text(
              _getMilestoneTitle(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: milestoneColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Motivational message
            Text(
              _getMotivationalMessage(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // XP reward
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$xpEarned XP',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: milestoneColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
