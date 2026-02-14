import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_routes.dart';

/// Soft paywall dialog shown at usage thresholds (30%, 50%, 80%)
///
/// Implements psychological principles:
/// - Loss aversion: "Don't lose your streak"
/// - Urgency: Token count and remaining usage
/// - Progressive disclosure: Different messaging at each threshold
class SoftPaywallDialog extends StatelessWidget {
  final int percentage;
  final int tokensRemaining;
  final int streakDays;

  const SoftPaywallDialog({
    required this.percentage,
    required this.tokensRemaining,
    this.streakDays = 0,
    super.key,
  });

  /// Show the soft paywall dialog
  static Future<void> show(
    BuildContext context, {
    required int percentage,
    required int tokensRemaining,
    int streakDays = 0,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SoftPaywallDialog(
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        streakDays: streakDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    final IconData icon;
    final Color color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (percentage >= 80) {
      title = '⚠️ Running Low on Study Tokens';
      message =
          'Only $tokensRemaining tokens left today. ${streakDays > 0 ? "Don't lose your $streakDays-day streak!" : "Upgrade for unlimited access."}';
      icon = Icons.warning_amber_rounded;
      color = isDark ? Colors.orange.shade400 : Colors.orange;
    } else if (percentage >= 50) {
      title = '📊 Halfway There';
      message =
          'You\'ve used $percentage% of your daily tokens. Upgrade for unlimited access?';
      icon = Icons.insights;
      color = AppTheme.primaryColor;
    } else {
      title = '💡 Great Progress!';
      message =
          'You\'ve used $percentage% of your daily study tokens. Upgrade for unlimited access?';
      icon = Icons.lightbulb_outline;
      color = AppTheme.primaryColor;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      title: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white.withOpacity(0.7) : Colors.black87,
            ),
          ),
          if (streakDays > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '$streakDays-day study streak',
                    style: AppFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withOpacity(0.9)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Continue Free',
            style: AppFonts.inter(
              color:
                  isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade700,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'See Plans',
            style: AppFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
