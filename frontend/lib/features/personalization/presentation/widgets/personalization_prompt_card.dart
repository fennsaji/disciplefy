import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_colors.dart';

/// Invitation to take the personalization questionnaire.
///
/// Styled as one of the home cards (flat surface, hairline border) rather
/// than a tinted gradient panel, so it reads as part of the page instead of
/// an ad dropped into it. The primary action leads; "Maybe later" is a quiet
/// text button beside it.
class PersonalizationPromptCard extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  const PersonalizationPromptCard({
    super.key,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF17171C) : Colors.white;
    final border = dark ? const Color(0x0DFFFFFF) : const Color(0xFFE9E5DB);
    final textPrimary =
        dark ? const Color(0xFFF2F2F4) : const Color(0xFF1A1917);
    final textMuted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6F6B61);
    final accent = dark ? const Color(0xFFA9A6F5) : AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.homePersonalizePromptTitle),
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr(
                                TranslationKeys.homePersonalizePromptSubtitle),
                            style: AppFonts.inter(
                                fontSize: 11.5, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(TranslationKeys.homePersonalizePromptDescription),
            style: AppFonts.inter(
              fontSize: 13,
              color: textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          // Wrap so neither label is ever cut: "Maybe later" drops below
          // the primary button when the line is too narrow.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: onGetStarted,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr(TranslationKeys.homePersonalizeGetStarted),
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: textMuted,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  context.tr(TranslationKeys.homePersonalizeMaybeLater),
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
