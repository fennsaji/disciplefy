import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Usage meter widget that displays token consumption and upgrade prompt
///
/// Shows:
/// - Daily study tokens used vs total (resets every day)
/// - Progress bar visualization
/// - Warning state at 80%+ usage
/// - Upgrade button for users approaching limits
///
/// Daily Limits:
/// - Free: 8 tokens/day
/// - Standard: 20 tokens/day
/// - Plus: 50 tokens/day
/// - Premium: Unlimited
class UsageMeterWidget extends StatelessWidget {
  final int tokensUsed;
  final int tokensTotal;
  final VoidCallback onUpgrade;

  const UsageMeterWidget({
    required this.tokensUsed,
    required this.tokensTotal,
    required this.onUpgrade,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (tokensUsed / tokensTotal * 100).round();
    final isWarning = percentage >= 80;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning
            ? (isDark
                ? AppColors.warning.withOpacity(0.2)
                : AppColors.warningLight)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning
              ? (isDark ? AppColors.warningDark : AppColors.warning)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Study Tokens',
                style: AppFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color:
                      isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                ),
              ),
              Text(
                '$tokensUsed / $tokensTotal',
                style: AppFonts.inter(
                  color: isWarning
                      ? (isDark ? AppColors.warning : AppColors.warningDark)
                      : (isDark
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade700),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: tokensUsed / tokensTotal,
              backgroundColor:
                  isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(
                isWarning
                    ? (isDark ? AppColors.warning : AppColors.warning)
                    : AppTheme.primaryColor,
              ),
              minHeight: 6,
            ),
          ),
          if (isWarning) ...[
            const SizedBox(height: 12),
            Text(
              '⚠️ Running low! Upgrade for unlimited access',
              style: AppFonts.inter(
                color: isDark ? AppColors.warning : AppColors.warningDark,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Upgrade Now',
                  style: AppFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
