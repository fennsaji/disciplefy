import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';

/// Soft paywall dialog shown at usage thresholds (80%, 100%)
///
/// Implements psychological principles:
/// - Loss aversion: "Don't lose your streak"
/// - Urgency: Token count and remaining usage
class SoftPaywallDialog extends StatelessWidget {
  final int percentage;
  final int tokensRemaining;
  final int streakDays;
  final String userPlan;

  const SoftPaywallDialog({
    required this.percentage,
    required this.tokensRemaining,
    this.streakDays = 0,
    this.userPlan = 'free',
    super.key,
  });

  /// Show the soft paywall dialog
  static Future<void> show(
    BuildContext context, {
    required int percentage,
    required int tokensRemaining,
    int streakDays = 0,
    String userPlan = 'free',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SoftPaywallDialog(
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        streakDays: streakDays,
        userPlan: userPlan,
      ),
    );
  }

  String get _planDisplayName {
    final name = userPlan.toLowerCase();
    return name.substring(0, 1).toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = AppColors.warning;

    final String title;
    final String message;

    if (percentage >= 100) {
      title = '🚫 No Study Tokens Left';
      message = streakDays > 0
          ? 'You\'ve used all your tokens today. Don\'t lose your $streakDays-day streak!'
          : 'You\'ve used all your daily study tokens. Purchase more or upgrade for unlimited access.';
    } else {
      title = '⚠️ Running Low on Study Tokens';
      message = streakDays > 0
          ? 'Only $tokensRemaining tokens left today. Don\'t lose your $streakDays-day streak!'
          : 'Only $tokensRemaining tokens left today. Upgrade for unlimited access.';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 28),
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
          const SizedBox(height: 12),
          // Action buttons stacked vertically
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(AppRoutes.pricing);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size.fromHeight(44),
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
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                final tokenState = context.read<TokenBloc>().state;
                final tokenStatus =
                    tokenState is TokenLoaded ? tokenState.tokenStatus : null;
                Navigator.of(context).pop();
                router.push(AppRoutes.tokenPurchase, extra: tokenStatus);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primaryColor),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Purchase Tokens',
                style: AppFonts.inter(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Continue on $_planDisplayName',
                style: AppFonts.inter(
                  color: isDark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
