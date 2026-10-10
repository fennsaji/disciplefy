import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// Icon tile, title and "{n} lessons · {days} days".
class NextPathRow extends StatelessWidget {
  final LearningPath path;
  final VoidCallback onTap;

  const NextPathRow({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return GuestLockedPathTile(
      path: path,
      badgeAlignment: Alignment.topLeft,
      badgePadding: const EdgeInsets.only(left: 26, top: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: PathLevelStyle.gradientFor(path.discipleLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForPath(path.iconName, category: path.category),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.homeTodayLessonsDays, {
                        'lessons': path.topicsCount,
                        'days': path.estimatedDays,
                      }),
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }
}
