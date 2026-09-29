import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Formats a 1-based section number the way the reader shows it: `01`, `02`…
String formatSectionNumber(int number) => number.toString().padLeft(2, '0');

/// "01  Title" heading used for every block of a study guide: the generated
/// sections and the end-of-guide blocks (share, follow-up chat, notes), so
/// numbering reads as one sequence down the page.
class NumberedSectionHeader extends StatelessWidget {
  /// 1-based number, or null to show no number.
  final int? number;
  final String title;

  /// Replaces the number (e.g. a pulsing speaker while read aloud).
  final Widget? leading;

  /// Optional trailing widgets (copy button, chevron…).
  final List<Widget> trailing;

  /// Colour of the title; defaults to the reader text colour.
  final Color? titleColor;

  final double titleSize;

  const NumberedSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.leading,
    this.trailing = const [],
    this.titleColor,
    this.titleSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final lead = leading ??
        (number == null
            ? null
            : Text(
                formatSectionNumber(number!),
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.gold,
                  letterSpacing: 0.4,
                ),
              ));

    return Row(
      children: [
        if (lead != null) ...[
          // Numbers sit on the title's cap height rather than its box centre.
          Padding(padding: const EdgeInsets.only(top: 2), child: lead),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: AppFonts.poppins(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: titleColor ?? palette.text,
              height: 1.25,
            ),
          ),
        ),
        ...trailing,
      ],
    );
  }
}

/// 1px separator between reader sections.
class ReaderHairline extends StatelessWidget {
  const ReaderHairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: ReaderPalette.of(context).hairline);
}
