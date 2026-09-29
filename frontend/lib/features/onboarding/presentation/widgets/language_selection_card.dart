import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// A selectable language row: code circle, native name over its English
/// name, and a radio on the right. The selected row gets an indigo border
/// and tint.
class LanguageSelectionCard extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  /// Line under the native name. Defaults to the language's English name.
  final String? secondaryLabel;

  const LanguageSelectionCard({
    super.key,
    required this.language,
    required this.isSelected,
    required this.onTap,
    this.secondaryLabel,
  });

  /// English names, shown under the native script so the row is readable
  /// before the reader has chosen a language.
  static String englishName(AppLanguage language) => switch (language) {
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'Hindi',
        AppLanguage.malayalam => 'Malayalam',
      };

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    const indigo = AppColors.brandPrimary;
    final radius = BorderRadius.circular(18);

    final fill = isSelected
        ? indigo.withValues(alpha: palette.isDark ? 0.14 : 0.07)
        : palette.card;
    final border = isSelected
        ? const BorderSide(color: indigo, width: 1.5)
        : BorderSide(color: palette.hairline);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(borderRadius: radius, side: border),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? indigo : palette.raised,
                    ),
                    child: Text(
                      language.code.toUpperCase(),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : palette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.displayName,
                          style: AppFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          secondaryLabel ?? englishName(language),
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Radio(isSelected: isSelected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool isSelected;

  const _Radio({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.brandPrimary : Colors.transparent,
        border: isSelected
            ? null
            : Border.all(color: palette.dim.withValues(alpha: 0.8), width: 1.5),
      ),
      child: isSelected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
