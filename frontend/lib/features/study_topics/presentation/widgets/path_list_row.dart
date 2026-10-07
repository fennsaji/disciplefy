import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';

/// Blue used for a path whose colour is missing or falls in the indigo
/// range (the design has no indigo).
const Color _pathTileFallback = Color(0xFF2563EB);

/// Colour of [path]'s icon tile: the path's own colour (green, blue, red,
/// purple… as curated per path), with indigo hues moved to blue.
Color pathTileColor(LearningPath path) {
  var hex = path.color.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final value = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
  if (value == null) return _pathTileFallback;
  final color = Color(value);
  final hue = HSVColor.fromColor(color).hue;
  if (hue >= 228 && hue <= 250) return _pathTileFallback;
  return color;
}

/// The lesson an enrolled, unfinished path is on (1-based), else null.
int? enrolledLessonOf(LearningPath path) {
  if (!path.isEnrolled || path.isCompleted || path.topicsCount <= 0) {
    return null;
  }
  return (path.topicsCompleted + 1).clamp(1, path.topicsCount);
}

/// One path in a list (Topics categories, All paths, category page): a
/// coloured icon tile, the title, and "{n} lessons · {d} days" — or, for a
/// path the user is on, "Lesson N of M" in gold. No level or XP.
class PathListRow extends StatelessWidget {
  final LearningPath path;

  /// The lesson the user is on. Defaults to the next lesson of an enrolled,
  /// unfinished path.
  final int? currentLesson;

  /// Marks the user's current path with a gold "Current" tag.
  final bool isCurrent;
  final VoidCallback? onTap;

  const PathListRow({
    super.key,
    required this.path,
    this.currentLesson,
    this.isCurrent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GuestLockedPathTile(
      path: path,
      // On the corner of the icon tile.
      badgeAlignment: Alignment.topLeft,
      badgePadding: const EdgeInsets.only(left: 30, top: 4),
      child: _row(context, ReaderPalette.of(context)),
    );
  }

  Widget _row(BuildContext context, ReaderPalette palette) {
    final lesson = currentLesson ?? enrolledLessonOf(path);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              key: Key('path_row_tile_${path.id}'),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pathTileColor(path),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForPath(path.iconName, category: path.category),
                color: Colors.white,
                size: 22,
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
                        path.displayTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      if (isCurrent)
                        const _CurrentTag()
                      else
                        _RowStatus(path: path),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (lesson != null)
                    Text(
                      context.tr(TranslationKeys.allPathsLessonOf, {
                        'n': lesson,
                        'total': path.topicsCount,
                      }),
                      key: Key('path_row_lesson_${path.id}'),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.gold,
                      ),
                    )
                  else
                    Text(
                      context.tr(TranslationKeys.learningPathsLessonsDays, {
                        'n': path.topicsCount,
                        'd': path.estimatedDays,
                      }),
                      style: AppFonts.inter(fontSize: 13, color: palette.muted),
                    ),
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

/// Completed / featured pill for a list row. A path in progress shows its
/// lesson instead.
class _RowStatus extends StatelessWidget {
  final LearningPath path;

  const _RowStatus({required this.path});

  @override
  Widget build(BuildContext context) {
    final String label;
    if (path.isCompleted) {
      label = context.tr(TranslationKeys.learningPathsCompleted);
    } else if (path.isFeatured && !path.isEnrolled) {
      label = context.tr(TranslationKeys.learningPathsFeatured);
    } else {
      return const SizedBox.shrink();
    }
    return _GoldTag(label: label);
  }
}

/// Gold "Current" tag on the user's current path.
class _CurrentTag extends StatelessWidget {
  const _CurrentTag();

  @override
  Widget build(BuildContext context) => _GoldTag(
        key: const Key('path_row_current_tag'),
        label: context.tr(TranslationKeys.allPathsCurrent),
      );
}

class _GoldTag extends StatelessWidget {
  final String label;

  const _GoldTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
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
