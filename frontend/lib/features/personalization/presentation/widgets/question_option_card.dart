import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Single-choice answer card in the personalization questionnaire.
///
/// Same look as the onboarding language cards: card fill, 18 radius,
/// hairline border, leading icon in a tinted circle and a round mark that
/// fills with a check when selected.
class QuestionOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const QuestionOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => _OptionCard(
        label: label,
        isSelected: isSelected,
        onTap: onTap,
        icon: icon,
        multiSelect: false,
      );
}

/// Multi-choice answer card: like [QuestionOptionCard] with a rounded-square
/// check mark instead of a round one.
class MultiSelectOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const MultiSelectOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => _OptionCard(
        label: label,
        isSelected: isSelected,
        onTap: onTap,
        icon: icon,
        multiSelect: true,
      );
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool multiSelect;

  const _OptionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.multiSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    const accent = ReaderPalette.selectedFill;
    final radius = BorderRadius.circular(18);

    final fill = isSelected
        ? accent.withValues(alpha: palette.isDark ? 0.14 : 0.07)
        : palette.card;
    final border = isSelected
        ? const BorderSide(color: accent, width: 1.5)
        : BorderSide(color: palette.hairline);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: isSelected,
        checked: multiSelect ? isSelected : null,
        inMutuallyExclusiveGroup: !multiSelect,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(borderRadius: radius, side: border),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  if (icon != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? accent
                            : AppColors.brandPrimary.withValues(
                                alpha: palette.isDark ? 0.18 : 0.08),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected ? Colors.white : palette.accentIcon,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: AppFonts.inter(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CheckMark(isSelected: isSelected, square: multiSelect),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty ring (or rounded square) that fills with a white check.
class _CheckMark extends StatelessWidget {
  final bool isSelected;
  final bool square;

  const _CheckMark({required this.isSelected, required this.square});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(7) : null,
        color: isSelected ? ReaderPalette.selectedFill : Colors.transparent,
        border: isSelected
            ? null
            : Border.all(color: palette.dim.withValues(alpha: 0.8), width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
