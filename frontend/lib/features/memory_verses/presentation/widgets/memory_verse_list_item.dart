import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/mastery_progress_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';

/// One verse in the memory deck list: bold reference with a status tag,
/// two muted lines of verse text, difficulty / review count / interval,
/// then a thin mastery bar, the due label and the language code. Rows sit on the page, split by a hairline.
///
/// Long-press opens a delete sheet when [onDelete] is set.
class MemoryVerseListItem extends StatelessWidget {
  final MemoryVerseEntity verse;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final MasteryLevel? masteryLevel;

  /// Draw the hairline under the row (off for the last row of a section).

  const MemoryVerseListItem({
    super.key,
    required this.verse,
    required this.onTap,
    this.onDelete,
    this.masteryLevel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final level = masteryLevel ?? verse.masteryLevel;
    final due = _dueLabel(context);
    final tag = _statusTag(context, level);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete != null ? () => _showDeleteMenu(context) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        verse.verseReference,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 10),
                      // Pinned to the right edge; long labels wrap inside.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: tag,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  verse.verseText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                _buildMeta(context),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: MemoryProgressBar(
                        value: _masteryProgress(level),
                        height: 4,
                        color: level == MasteryLevel.master
                            ? palette.gold
                            : palette.accentIcon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        due.$1,
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: due.$2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: _languageName(context, verse.language),
                      child: Text(
                        verse.language.toUpperCase(),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.dim,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Difficulty (from the ease factor), review count and current interval.
  Widget _buildMeta(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final style = AppFonts.inter(fontSize: 12.5, color: palette.muted);
    final (String difficulty, MemoryTone tone, IconData icon) =
        switch (verse.difficultyLevel) {
      'hard' => (
          context.tr(TranslationKeys.memoryHard),
          MemoryTone.error,
          Icons.trending_up_rounded,
        ),
      'medium' => (
          context.tr(TranslationKeys.memoryGood),
          MemoryTone.gold,
          Icons.trending_flat_rounded,
        ),
      _ => (
          context.tr(TranslationKeys.memoryEasy),
          MemoryTone.success,
          Icons.trending_down_rounded,
        ),
    };
    final toneColor = MemoryToneColors.of(context, tone).foreground;
    Widget item(IconData icon, String text, Color color, {TextStyle? s}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(text, style: s ?? style)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(
          icon,
          difficulty,
          toneColor,
          s: style.copyWith(color: toneColor, fontWeight: FontWeight.w600),
        ),
        item(
          Icons.repeat_rounded,
          verse.repetitions == 1
              ? context.tr(TranslationKeys.flipCardReviewOne)
              : context.tr(TranslationKeys.flipCardReviews,
                  {'count': verse.repetitions.toString()}),
          palette.dim,
        ),
        item(
          Icons.schedule_rounded,
          verse.intervalDays == 1
              ? context.tr(TranslationKeys.flipCardDayOne)
              : context.tr(TranslationKeys.flipCardDays,
                  {'count': verse.intervalDays.toString()}),
          palette.dim,
        ),
      ],
    );
  }

  /// Share of the mastery ladder reached; a small dot for beginners.
  double _masteryProgress(MasteryLevel? level) {
    if (level == null) return 0.03;
    final steps = MasteryLevel.values.length - 1;
    final value = level.index / steps;
    return value < 0.03 ? 0.03 : value;
  }

  (String, Color) _dueLabel(BuildContext context) {
    final palette = ReaderPalette.of(context);
    if (verse.daysOverdue > 0) {
      return (
        verse.daysOverdue == 1
            ? context.tr(TranslationKeys.memoryScreensOverdueOneDay)
            : context.tr(TranslationKeys.memoryScreensOverdueDays,
                {'count': verse.daysOverdue.toString()}),
        context.appError,
      );
    }
    if (verse.isDue) {
      return (context.tr(TranslationKeys.memoryScreensDueToday), palette.gold);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(verse.nextReviewDate.year, verse.nextReviewDate.month,
        verse.nextReviewDate.day);
    final days = next.difference(today).inDays;
    if (days <= 1) {
      return (
        context.tr(TranslationKeys.memoryScreensDueTomorrow),
        palette.muted
      );
    }
    return (
      context.tr(
          TranslationKeys.memoryScreensDueInDays, {'count': days.toString()}),
      palette.muted,
    );
  }

  Widget? _statusTag(BuildContext context, MasteryLevel? level) {
    if (level == MasteryLevel.master) {
      return MemoryTag(
        label: context.tr(TranslationKeys.memoryFullyMastered),
        tone: MemoryTone.gold,
      );
    }
    if (verse.isDue) {
      return MemoryTag(
        label: context.tr(TranslationKeys.memoryReview),
        tone: MemoryTone.accent,
      );
    }
    if (level == MasteryLevel.expert) {
      return MemoryTag(
        label: context.tr(TranslationKeys.memoryReviewMilestone),
        tone: MemoryTone.gold,
      );
    }
    if (verse.isNew) {
      return MemoryTag(
          label: context.tr(TranslationKeys.memoryScreensNewVerse));
    }
    if (level == null) return null;
    return MemoryTag(label: _levelName(context, level));
  }

  String _levelName(BuildContext context, MasteryLevel level) {
    switch (level) {
      case MasteryLevel.beginner:
        return context.tr(TranslationKeys.memoryStatsBeginner);
      case MasteryLevel.intermediate:
        return context.tr(TranslationKeys.memoryStatsIntermediate);
      case MasteryLevel.advanced:
        return context.tr(TranslationKeys.memoryStatsAdvanced);
      case MasteryLevel.expert:
        return context.tr(TranslationKeys.memoryStatsExpert);
      case MasteryLevel.master:
        return context.tr(TranslationKeys.memoryStatsMaster);
    }
  }

  void _showDeleteMenu(BuildContext context) {
    final palette = ReaderPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.appError),
              title: Text(
                context.tr(TranslationKeys.memoryDeleteTitle),
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appError,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.close, color: palette.muted),
              title: Text(
                context.tr(TranslationKeys.memoryDeleteCancel),
                style: AppFonts.inter(fontSize: 15, color: palette.text),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  String _languageName(BuildContext context, String code) {
    switch (code) {
      case 'hi':
        return context.tr(TranslationKeys.generateStudyHindi);
      case 'ml':
        return context.tr(TranslationKeys.generateStudyMalayalam);
      case 'en':
      default:
        return context.tr(TranslationKeys.generateStudyEnglish);
    }
  }
}
