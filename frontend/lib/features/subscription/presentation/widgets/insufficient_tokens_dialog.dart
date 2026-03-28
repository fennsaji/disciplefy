import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
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
            _buildHeader(context, isDark, colorScheme),
            const SizedBox(height: 16),
            _buildTokenBalance(context, isDark, colorScheme),
            const SizedBox(height: 16),
            _buildUpgradePlans(context, isDark, colorScheme, theme),
            const SizedBox(height: 16),
            _buildInfoBox(context, isDark, colorScheme),
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

  Widget _buildHeader(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.token_rounded,
            color: colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(TranslationKeys.tokenDialogTitle),
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
                context.tr(TranslationKeys.tokenDialogSubtitle),
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

  Widget _buildTokenBalance(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
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
              Text(context.tr(TranslationKeys.tokenDialogYourCredits),
                  style: labelStyle),
              Text(
                '${tokenStatus.totalTokens} ${context.tr(TranslationKeys.tokenDialogCreditsUnit)}',
                style: valueStyle,
              ),
            ],
          ),
          if (requiredTokens != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr(TranslationKeys.tokenDialogNeeded),
                    style: labelStyle),
                Text(
                  '$requiredTokens ${context.tr(TranslationKeys.tokenDialogCreditsUnit)}',
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white.withOpacity(0.85)
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradePlans(BuildContext context, bool isDark,
      ColorScheme colorScheme, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.tokenDialogGetMore),
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
          detail: '20 credits/day — ₹79/month',
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          isDark: isDark,
          colorScheme: colorScheme,
          icon: Icons.info_outline,
          iconColor: colorScheme.primary,
          label: 'Plus',
          detail: '50 credits/day — ₹149/month',
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          isDark: isDark,
          colorScheme: colorScheme,
          icon: Icons.info_outline,
          iconColor: colorScheme.primary,
          label: 'Premium',
          detail: 'Unlimited credits — ₹499/month',
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

  Widget _buildInfoBox(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(TranslationKeys.tokenDialogInfoBox),
              style: AppFonts.inter(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.75)
                    : colorScheme.primary,
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
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          context.tr(TranslationKeys.tokenDialogPurchase),
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
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
              context.tr(TranslationKeys.tokenDialogMaybeLater),
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
              backgroundColor: context.appInteractive,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              context.tr(TranslationKeys.tokenDialogViewPlans),
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
