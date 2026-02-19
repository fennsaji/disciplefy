import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Streak protection dialog.
///
/// Allows users to use a freeze day to protect their streak.
/// Shows:
/// - Explanation of freeze days
/// - Available freeze days count
/// - Warning about streak at risk
/// - Confirm/Cancel actions
class StreakProtectionDialog extends StatelessWidget {
  final int freezeDaysAvailable;
  final int currentStreak;
  final VoidCallback onConfirm;

  const StreakProtectionDialog({
    super.key,
    required this.freezeDaysAvailable,
    required this.currentStreak,
    required this.onConfirm,
  });

  /// Shows the streak protection dialog.
  ///
  /// Returns true if user confirmed, false if cancelled.
  static Future<bool> show(
    BuildContext context, {
    required int freezeDaysAvailable,
    required int currentStreak,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StreakProtectionDialog(
        freezeDaysAvailable: freezeDaysAvailable,
        currentStreak: currentStreak,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.ac_unit,
              color: AppColors.info,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Protect Your Streak',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your $currentStreak-day streak is at risk!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Explanation
          Text(
            'Use a freeze day to protect your streak on a day you couldn\'t practice.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Available freeze days
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Freeze Days:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.ac_unit,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$freezeDaysAvailable',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // How to earn more
          Text(
            'Earn 1 freeze day for every 7 consecutive days of practice (max 5).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: freezeDaysAvailable > 0
              ? () {
                  onConfirm();
                  Navigator.of(context).pop(true);
                }
              : null,
          icon: const Icon(Icons.ac_unit),
          label: const Text('Use Freeze Day'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.lightBorder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
