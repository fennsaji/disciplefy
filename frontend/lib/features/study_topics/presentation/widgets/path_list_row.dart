import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// One path in a list (Topics tab category groups, category page): gradient icon tile, title, status,
/// level · topics · XP · days, and progress once enrolled.
class PathListRow extends StatelessWidget {
  final LearningPath path;
  final VoidCallback onTap;

  const PathListRow({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topics = path.isEnrolled
        ? '${path.topicsCompleted}/${path.topicsCount}'
        : '${path.topicsCount}';
    final meta = [
      discipleLevelLabel(context, path.discipleLevel),
      '$topics ${context.tr(TranslationKeys.learningPathsTopics)}',
      '${path.totalXp} ${context.tr(TranslationKeys.learningPathsXp)}',
      '${path.estimatedDays} ${context.tr(TranslationKeys.learningPathsDays)}',
    ].join(' · ');

    return GuestLockedPathTile(
      path: path,
      // On the corner of the icon tile.
      badgeAlignment: Alignment.topLeft,
      badgePadding: const EdgeInsets.only(left: 42, top: 6),
      child: _row(context, palette, meta),
    );
  }

  Widget _row(BuildContext context, ReaderPalette palette, String meta) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: PathLevelStyle.gradientFor(path.discipleLevel),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                iconForPath(path.iconName, category: path.category),
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        path.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      _RowStatus(path: path),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  ),
                  if (path.isEnrolled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (path.progressPercentage / 100)
                                  .clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: palette.raised,
                              valueColor: AlwaysStoppedAnimation(palette.gold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${path.progressPercentage}%',
                          style: AppFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: palette.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: palette.dim),
          ],
        ),
      ),
    );
  }
}

/// Completed / in progress / featured pill for a list row.
class _RowStatus extends StatelessWidget {
  final LearningPath path;

  const _RowStatus({required this.path});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final String label;
    if (path.isCompleted) {
      label = context.tr(TranslationKeys.learningPathsCompleted);
    } else if (path.isInProgress) {
      label = context.tr(TranslationKeys.learningPathsInProgress);
    } else if (path.isFeatured) {
      label = context.tr(TranslationKeys.learningPathsFeatured);
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.gold,
        ),
      ),
    );
  }
}
