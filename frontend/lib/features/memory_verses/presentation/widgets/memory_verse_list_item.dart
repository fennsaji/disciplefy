import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/mastery_progress_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';

/// One verse in the memory deck list: a card with the reference and a
/// status tag ("Due" for a due verse), two muted lines of verse text, then a
/// thin mastery bar with the review count, interval or next due day and the
/// language code. The first verse due can carry a soft gold glow
/// ([highlighted]) on dark.
///
/// Long-press opens a delete sheet when [onDelete] is set.
class MemoryVerseListItem extends StatelessWidget {
  final MemoryVerseEntity verse;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final MasteryLevel? masteryLevel;

  /// The next verse to review: a soft gold glow on dark.
  final bool highlighted;

  const MemoryVerseListItem({
    super.key,
    required this.verse,
    required this.onTap,
    this.onDelete,
    this.masteryLevel,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final level = masteryLevel ?? verse.masteryLevel;
    final tag = _statusTag(context, level);
    final glow = highlighted && palette.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: palette.gold.withValues(alpha: 0.8),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: palette.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color:
                  glow ? palette.gold.withValues(alpha: 0.5) : palette.hairline,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress:
                onDelete != null ? () => _showDeleteMenu(context) : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            verse.verseReference,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                              height: 1.2,
                            ),
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
                  const SizedBox(height: 4),
                  Text(
                    verse.verseText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(
                      fontSize: 13.5,
                      color: palette.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFooter(context, level),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mastery bar, then review count, interval and (for a verse not due
  /// yet) when it comes back, then the language code.
  Widget _buildFooter(BuildContext context, MasteryLevel? level) {
    final palette = ReaderPalette.of(context);
    final style = AppFonts.inter(fontSize: 12, color: palette.muted);
    final reviews = verse.repetitions == 1
        ? context.tr(TranslationKeys.flipCardReviewOne)
        : context.tr(TranslationKeys.flipCardReviews,
            {'count': verse.repetitions.toString()});
    final interval = verse.intervalDays == 1
        ? context.tr(TranslationKeys.flipCardDayOne)
        : context.tr(TranslationKeys.flipCardDays,
            {'count': verse.intervalDays.toString()});
    final due = _dueLabel(context);
    final parts = [reviews, interval, if (due != null) due];
    final dot = Text(' \u00B7 ', style: style);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: MemoryProgressBar(
            value: _masteryProgress(level),
            height: 4,
            color: level == MasteryLevel.master
                ? palette.gold
                : palette.accentIcon,
          ),
        ),
        const SizedBox(width: 10),
        // Wraps rather than cutting a part off (Malayalam at 320pt).
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) dot,
                Text(parts[i], style: style),
              ],
            ],
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
    );
  }

  /// Share of the mastery ladder reached; a small dot for beginners.
  double _masteryProgress(MasteryLevel? level) {
    if (level == null) return 0.03;
    final steps = MasteryLevel.values.length - 1;
    final value = level.index / steps;
    return value < 0.03 ? 0.03 : value;
  }

  /// When a verse not due yet comes back ("Due tomorrow", "Due in 3 days");
  /// null for a due verse, whose "Due" chip already says it.
  String? _dueLabel(BuildContext context) {
    if (verse.isDue || verse.daysOverdue > 0) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(verse.nextReviewDate.year, verse.nextReviewDate.month,
        verse.nextReviewDate.day);
    final days = next.difference(today).inDays;
    if (days <= 1) {
      return context.tr(TranslationKeys.memoryScreensDueTomorrow);
    }
    return context
        .tr(TranslationKeys.memoryScreensDueInDays, {'count': days.toString()});
  }

  Widget? _statusTag(BuildContext context, MasteryLevel? level) {
    if (level == MasteryLevel.master) {
      return MemoryTag(
        label: context.tr(TranslationKeys.memoryFullyMastered),
        tone: MemoryTone.gold,
      );
    }
    // A due verse shows the calm "Due" chip, never a red overdue count.
    if (verse.isDue || verse.daysOverdue > 0) {
      return MemoryDueChip(label: context.tr(TranslationKeys.memoryDue));
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

/// The small grey "Due" chip on a verse card: 22px, radius 11, a faint
/// ink wash with a 12/600 label.
class MemoryDueChip extends StatelessWidget {
  final String label;

  const MemoryDueChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : ReaderPalette.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          // 5.5:1 or more on the wash in both themes.
          color: palette.isDark
              ? const Color(0xFFC9C9D2)
              : const Color(0xFF5C584F),
        ),
      ),
    );
  }
}
