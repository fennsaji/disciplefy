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
      color:
          palette.isDark ? Colors.black.withValues(alpha: 0.35) : palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : palette.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.gold.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_sunny_outlined,
                    size: 16, color: palette.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.generateSimpleVerseOfDay),
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: palette.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: reference,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' · $verseText'),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: ink.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.outline),
                ),
                child:
                    Icon(Icons.north_east_rounded, size: 16, color: ink.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
