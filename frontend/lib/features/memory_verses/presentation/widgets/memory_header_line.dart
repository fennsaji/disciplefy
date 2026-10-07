import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// One quiet line under the Memory Verses title: a gold flame, then
/// "4-day streak · 5 verses". Tapping it (when [onTap] is set) offers the
/// streak freeze.
class MemoryHeaderLine extends StatelessWidget {
  final int streak;
  final int verseCount;
  final VoidCallback? onTap;

  const MemoryHeaderLine({
    super.key,
    required this.streak,
    required this.verseCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final text = context.tr(
      verseCount == 1
          ? TranslationKeys.memoryHeaderLineOne
          : TranslationKeys.memoryHeaderLine,
      {'streak': '$streak', 'count': '$verseCount'},
    );
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_outlined,
              size: 16, color: palette.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return line;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: line,
      ),
    );
  }
}
