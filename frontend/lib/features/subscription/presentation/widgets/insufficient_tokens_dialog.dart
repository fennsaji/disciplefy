import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tokens/domain/entities/token_status.dart';

/// Dialog shown when user has insufficient tokens to generate a study guide.
///
/// Displays current token balance vs required cost, plan upgrade options,
/// and navigation to the pricing or token purchase page.
class InsufficientTokensDialog extends StatelessWidget {
  final TokenStatus tokenStatus;

  /// The number of tokens required for this operation (if known).
  final int? requiredTokens;

  const InsufficientTokensDialog({
    super.key,
    required this.tokenStatus,
    this.requiredTokens,
  });

  /// Show the insufficient tokens dialog as a modal.
  static Future<void> show(
    BuildContext context, {
    required TokenStatus tokenStatus,
    int? requiredTokens,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => InsufficientTokensDialog(
        tokenStatus: tokenStatus,
        requiredTokens: requiredTokens,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, colorScheme),
            const SizedBox(height: 16),
            _buildTokenBalance(isDark, colorScheme),
            const SizedBox(height: 16),
            _buildUpgradePlans(isDark, colorScheme, theme),
            const SizedBox(height: 16),
            _buildInfoBox(isDark),
            const SizedBox(height: 20),
            if (tokenStatus.canPurchaseTokens) ...[
              _buildPurchaseTokensButton(context, isDark, colorScheme),
              const SizedBox(height: 8),
            ],
            _buildActionButtons(context, isDark, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.brandSecondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.token_rounded,
            color: AppColors.brandSecondary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Not Enough Tokens',
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white.withOpacity(0.95)
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You need tokens to generate a study guide.',
                style: AppFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withOpacity(0.65)
                      : colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenBalance(bool isDark, ColorScheme colorScheme) {
    final bgColor = isDark
        ? Colors.white.withOpacity(0.07)
        : colorScheme.onSurface.withOpacity(0.06);
    final labelStyle = AppFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark
          ? Colors.white.withOpacity(0.75)
          : colorScheme.onSurface.withOpacity(0.75),
    );
    final valueStyle = AppFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: AppColors.error,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your balance', style: labelStyle),
              Text('${tokenStatus.totalTokens} tokens', style: valueStyle),
            ],
          ),
          if (requiredTokens != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Required', style: labelStyle),
                Text('$requiredTokens tokens',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white.withOpacity(0.85)
                          : colorScheme.onSurface,
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradePlans(
      bool isDark, ColorScheme colorScheme, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upgrade for more tokens:',
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 10),
        _buildPlanRow(
          isDark: isDark,
          colorScheme: colorScheme,
          icon: Icons.radio_button_unchecked,
          iconColor: isDark ? Colors.white54 : Colors.black45,
          label: 'Standard',
          detail: '20 tokens/day  ₹79/month',
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          isDark: isDark,
          colorScheme: colorScheme,
          icon: Icons.info_outline,
          iconColor: AppColors.brandSecondary,
          label: 'Plus',
          detail: '50 tokens/day  ₹149/month',
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          isDark: isDark,
          colorScheme: colorScheme,
          icon: Icons.info_outline,
          iconColor: AppColors.brandSecondary,
          label: 'Premium',
          detail: 'Unlimited  ₹499/month',
        ),
      ],
    );
  }

  Widget _buildPlanRow({
    required bool isDark,
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withOpacity(0.85)
                      : colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
              TextSpan(
                text: detail,
                style: AppFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandSecondary.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.brandSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your daily tokens reset at midnight. You can also purchase additional tokens anytime.',
              style: AppFonts.inter(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.75)
                    : AppColors.brandSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTokensButton(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pop();
          GoRouter.of(context)
              .push(AppRoutes.tokenPurchase, extra: tokenStatus);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.brandSecondary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Purchase Tokens',
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.brandSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Maybe Later',
              style: AppFonts.inter(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              GoRouter.of(context).push(AppRoutes.pricing);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'View Plans',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
