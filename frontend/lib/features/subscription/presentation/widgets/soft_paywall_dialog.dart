import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_routes.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';

/// Soft paywall dialog shown at usage thresholds (80%, 100%)
class SoftPaywallDialog extends StatelessWidget {
  final int percentage;
  final int tokensRemaining;
  final String userPlan;

  const SoftPaywallDialog({
    required this.percentage,
    required this.tokensRemaining,
    this.userPlan = 'free',
    super.key,
  });

  /// Show the soft paywall dialog
  static Future<void> show(
    BuildContext context, {
    required int percentage,
    required int tokensRemaining,
    int streakDays = 0, // kept for API compatibility, no longer used
    String userPlan = 'free',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SoftPaywallDialog(
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        userPlan: userPlan,
      ),
    );
  }

  /// Returns a localized "resets in X hours" string based on time until midnight.
  String _resetKey(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes;

    if (minutes < 60) {
      return context.tr(TranslationKeys.tokenSoftPaywallResetSoon);
    }
    if (hours == 1) {
      return context.tr(TranslationKeys.tokenSoftPaywallResetHour);
    }
    return context.tr(
      TranslationKeys.tokenSoftPaywallResetHours,
      {'hours': '$hours'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white.withOpacity(0.9) : Colors.black87;
    final textSecondary =
        isDark ? Colors.white.withOpacity(0.65) : Colors.black54;
    final resetTime = _resetKey(context);

    final String title;
    final String message;
    final IconData titleIcon;
    final Color iconColor;

    if (percentage >= 100) {
      title = context.tr(TranslationKeys.tokenSoftPaywallUsedTitle);
      message = context.tr(
        TranslationKeys.tokenSoftPaywallUsedMessage,
        {'resetTime': resetTime},
      );
      titleIcon = Icons.nightlight_round;
      iconColor = const Color(0xFF6366F1); // indigo
    } else {
      title = context.tr(TranslationKeys.tokenSoftPaywallLowTitle);
      message = context.tr(
        TranslationKeys.tokenSoftPaywallLowMessage,
        {
          'count': '$tokensRemaining',
          'resetTime': resetTime,
        },
      );
      titleIcon = Icons.battery_2_bar_rounded;
      iconColor = const Color(0xFFF59E0B); // amber
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      title: Row(
        children: [
          Icon(titleIcon, color: iconColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
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
            style: AppFonts.inter(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 16),
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
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                context.tr(TranslationKeys.tokenSoftPaywallSeePlans),
                style: AppFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
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
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                context.tr(TranslationKeys.tokenSoftPaywallPurchase),
                style: AppFonts.inter(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
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
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                context.tr(TranslationKeys.tokenSoftPaywallMaybeLater),
                style: AppFonts.inter(color: textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
