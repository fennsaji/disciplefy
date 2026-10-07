import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Practice activity heat grid: one column per week (oldest on the left),
/// one row per weekday (Monday on top), each cell tinted indigo by how many
/// practices happened that day.
///
/// Month names run above the columns where a month starts and Mon / Wed /
/// Fri label the rows on the left. Long-press or hover a cell for its date
/// and count. Sizes its cells to the width it gets.
class PracticeActivityGrid extends StatelessWidget {
  /// Practice count per calendar day (time of day ignored).
  final Map<DateTime, int> activityData;

  /// Number of week columns to show, ending with the current week.
  final int weeks;

  /// Injectable "today" for tests.
  final DateTime? today;

  const PracticeActivityGrid({
    super.key,
    required this.activityData,
    this.weeks = 12,
    this.today,
  });

  static const double _gap = 4;

  /// Tint of a day with [count] practices when the busiest day had
  /// [maxCount]. Shared with [PracticeActivityLegend].
  static Color cellColor(BuildContext context, int count, int maxCount) {
    final palette = ReaderPalette.of(context);
    if (count <= 0 || maxCount <= 0) return palette.raised;
    final share = count / maxCount;
    final alpha = share > 0.75
        ? 1.0
        : share > 0.5
            ? 0.72
            : share > 0.25
                ? 0.48
                : 0.28;
    return Color.alphaBlend(
      AppColors.brandPrimary.withValues(alpha: alpha),
      palette.raised,
    );
  }

  static String _format(BuildContext context, DateTime date, bool monthOnly) {
    final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    try {
      return monthOnly
          ? DateFormat.MMM(locale).format(date)
          : DateFormat.MMMd(locale).format(date);
    } catch (_) {
      // Date symbols for this locale are not loaded (no localizations
      // ancestor): fall back to intl's default locale.
      return monthOnly
          ? DateFormat.MMM().format(date)
          : DateFormat.MMMd().format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    // Monday of the first week shown. Calendar arithmetic (not Duration)
    // so daylight-saving shifts never move a cell to the wrong day.
    final firstDay = DateTime(todayDate.year, todayDate.month,
        todayDate.day - (todayDate.weekday - 1) - 7 * (weeks - 1));

    final counts = <DateTime, int>{};
    activityData.forEach((date, count) {
      final day = DateTime(date.year, date.month, date.day);
      counts[day] = (counts[day] ?? 0) + count;
    });
    final maxCount =
        counts.values.fold<int>(0, (max, value) => value > max ? value : max);

    DateTime dayAt(int week, int weekday) => DateTime(
        firstDay.year, firstDay.month, firstDay.day + week * 7 + weekday);

    final labelStyle = AppFonts.inter(fontSize: 10.5, color: palette.dim);
    final dayLabels = <int, String>{
      0: context.tr(TranslationKeys.heatMapMon),
      2: context.tr(TranslationKeys.heatMapWed),
      4: context.tr(TranslationKeys.heatMapFri),
    };

    // Month label on the first column whose Monday falls in a new month,
    // skipped when it would crowd the previous label.
    final monthStarts = <int, String>{};
    var lastLabelWeek = -99;
    for (var week = 0; week < weeks; week++) {
      final monday = dayAt(week, 0);
      final previous = week == 0 ? null : dayAt(week - 1, 0);
      if (previous == null || previous.month != monday.month) {
        if (week - lastLabelWeek >= 3 && week <= weeks - 2) {
          monthStarts[week] = _format(context, monday, true);
          lastLabelWeek = week;
        }
      }
    }

    final reviewsLabel = context.tr(TranslationKeys.flipCardReviews);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Weekday label column sized to the widest label.
        var labelWidth = 0.0;
        for (final label in dayLabels.values) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: DefaultTextStyle.of(context).style.merge(labelStyle),
            ),
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout();
          if (painter.width > labelWidth) labelWidth = painter.width;
        }
        labelWidth += 6;
        final gridWidth = constraints.maxWidth - labelWidth;
        final cell =
            ((gridWidth - _gap * (weeks - 1)) / weeks).clamp(6.0, 22.0);
        final step = cell + _gap;

        return ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(start: labelWidth),
                child: SizedBox(
                  height: 16,
                  width: gridWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final entry in monthStarts.entries)
                        PositionedDirectional(
                          start: entry.key * step,
                          top: 0,
                          child:
                              Text(entry.value, maxLines: 1, style: labelStyle),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              for (var weekday = 0; weekday < 7; weekday++) ...[
                if (weekday > 0) const SizedBox(height: _gap),
                Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      height: cell,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: dayLabels[weekday] == null
                            ? null
                            : Text(dayLabels[weekday]!,
                                maxLines: 1, style: labelStyle),
                      ),
                    ),
                    for (var week = 0; week < weeks; week++) ...[
                      if (week > 0) const SizedBox(width: _gap),
                      _cell(
                        context,
                        dayAt(week, weekday),
                        todayDate,
                        counts,
                        maxCount,
                        cell,
                        reviewsLabel,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    DateTime todayDate,
    Map<DateTime, int> counts,
    int maxCount,
    double size,
    String reviewsLabel,
  ) {
    if (day.isAfter(todayDate)) return SizedBox(width: size, height: size);
    final count = counts[day] ?? 0;
    return Tooltip(
      message: '${_format(context, day, false)} · '
          '${reviewsLabel.replaceAll('{count}', '$count')}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cellColor(context, count, maxCount),
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
      ),
    );
  }
}

/// "Less ▢▢▢▢ More" scale for [PracticeActivityGrid].
class PracticeActivityLegend extends StatelessWidget {
  const PracticeActivityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final style = AppFonts.inter(fontSize: 12, color: palette.dim);
    Widget swatch(int count) => Container(
          width: 11,
          height: 11,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: PracticeActivityGrid.cellColor(context, count, 4),
            borderRadius: BorderRadius.circular(2.5),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.tr(TranslationKeys.heatMapLess), style: style),
        const SizedBox(width: 5),
        swatch(0),
        swatch(1),
        swatch(2),
        swatch(3),
        swatch(4),
        const SizedBox(width: 5),
        Text(context.tr(TranslationKeys.heatMapMore), style: style),
      ],
    );
  }
}
