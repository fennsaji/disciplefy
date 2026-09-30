import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

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
    final palette = ReaderPalette.of(context);
    final warning = palette.isDark ? AppColors.warning : AppColors.warningDark;
    final canUse = freezeDaysAvailable > 0;

    return PopupDialog(
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.ac_unit_rounded),
          eyebrow: context.tr(TranslationKeys.streakProtectionEyebrow),
          title: context.tr(TranslationKeys.streakProtectionTitle),
          body: context.tr(TranslationKeys.streakProtectionExplanation),
        ),
        const SizedBox(height: 18),

        // Streak at risk
        PopupPanel(
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    TranslationKeys.streakProtectionAtRisk,
                    {'count': '$currentStreak'},
                  ),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: warning,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Available freeze days
        PopupPanel(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.streakProtectionAvailable),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.ac_unit_rounded, color: palette.accentIcon, size: 18),
              const SizedBox(width: 4),
              Text(
                '$freezeDaysAvailable',
                key: const Key('streak_protection_count'),
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // How to earn more
        Text(
          context.tr(TranslationKeys.streakProtectionEarnMore),
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 12.5,
            color: palette.dim,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        PopupPrimaryButton(
          key: const Key('streak_protection_use'),
          label: context.tr(TranslationKeys.streakProtectionUse),
          icon: Icons.ac_unit_rounded,
          onPressed: canUse
              ? () {
                  onConfirm();
                  Navigator.of(context).pop(true);
                }
              : null,
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('streak_protection_cancel'),
          label: context.tr(TranslationKeys.streakProtectionCancel),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
