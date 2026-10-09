import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/generate_hero.dart';

/// "Verse of the day" row on the Generate tab: the reference and the start
/// of the verse. Tapping it starts a study of that verse.
class VerseOfDayRow extends StatelessWidget {
  final String reference;
  final String verseText;
  final VoidCallback onTap;

  const VerseOfDayRow({
    super.key,
    required this.reference,
    required this.verseText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);
    final radius = BorderRadius.circular(16);

    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : palette.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.gold
                      .withValues(alpha: palette.isDark ? 0.15 : 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.wb_sunny_outlined,
                    size: 17, color: palette.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.generateSimpleVerseOfDay),
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: palette.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$reference · $verseText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: ink.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.outline),
                ),
                child:
                    Icon(Icons.north_east_rounded, size: 15, color: ink.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
