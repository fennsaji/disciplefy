import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// One selectable row of the first-run screens (a language or a goal): a
/// square leading tile, a title over an optional second line, and a check
/// (selected) or an empty ring on the right. The selected row has a gold
/// border and a faint gold tint.
class FirstRunChoiceRow extends StatelessWidget {
  /// Content of the leading tile: a script glyph or an icon.
  final Widget Function(Color color) leading;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Smallest height of the row (56 for the language rows).
  final double minHeight;

  const FirstRunChoiceRow({
    super.key,
    required this.leading,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.minHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final accent = palette.selectedFill;
    final radius = BorderRadius.circular(14);
    final fill = isSelected
        ? Color.alphaBlend(
            accent.withValues(alpha: palette.isDark ? 0.10 : 0.06),
            palette.card)
        : palette.card;
    final border = isSelected
        ? BorderSide(color: accent, width: 1.5)
        : BorderSide(color: palette.hairline);
    final tileFill = isSelected
        ? accent
        : palette.gold.withValues(alpha: palette.isDark ? 0.14 : 0.10);
    final tileInk = isSelected ? palette.onSelected : palette.accentIcon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tileFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: leading(tileInk),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: palette.text,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: AppFonts.inter(
                                fontSize: 12.5,
                                height: 1.3,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ExcludeSemantics(child: _Check(isSelected: isSelected)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool isSelected;

  const _Check({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? palette.selectedFill : Colors.transparent,
        border: isSelected
            ? null
            : Border.all(color: palette.dim.withValues(alpha: 0.8), width: 1.5),
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, size: 15, color: palette.onSelected)
          : null,
    );
  }
}
