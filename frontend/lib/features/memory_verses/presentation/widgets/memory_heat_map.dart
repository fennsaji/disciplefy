import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Memory Heat Map Calendar Widget - GitHub-style contribution calendar.
class MemoryHeatMap extends StatelessWidget {
  final Map<DateTime, int> activityData;
  final int currentStreak;
  final int longestStreak;
  final Function(DateTime)? onDayTap;

  const MemoryHeatMap({
    super.key,
    required this.activityData,
    required this.currentStreak,
    required this.longestStreak,
    this.onDayTap,
  });

  static const double _cellSize = 12.0;
  static const double _cellGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.heatMapTitle),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.heatMapSubtitle),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                _buildStreakBadge(context),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar
            _buildCalendar(context, isDark),
            const SizedBox(height: 12),

            // Legend
            _buildLegend(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: primaryColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(
                TranslationKeys.heatMapDayStreak, {'count': '$currentStreak'}),
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, bool isDark) {
    final today = DateTime.now();
    final startDate = _getStartOfWeek(today.subtract(const Duration(days: 77)));

    // Build week data
    final List<List<DateTime?>> weeks = [];
    DateTime currentDay = startDate;

    while (currentDay.isBefore(today) || _isSameDay(currentDay, today)) {
      if (currentDay.weekday == DateTime.sunday || weeks.isEmpty) {
        weeks.add(List.filled(7, null));
      }
      final dayIndex =
          currentDay.weekday == DateTime.sunday ? 0 : currentDay.weekday;
      if (weeks.isNotEmpty && dayIndex < 7) {
        weeks.last[dayIndex] = currentDay;
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels
          _buildMonthRow(weeks),
          const SizedBox(height: 6),

          // Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              _buildDayColumn(context),
              const SizedBox(width: 8),

              // Week columns
              ...weeks.map((week) => _buildWeekColumn(week, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthRow(List<List<DateTime?>> weeks) {
    // Calculate month spans - group consecutive weeks by month
    final List<_MonthSpan> monthSpans = [];
    String? currentMonth;
    int spanStart = 0;

    for (int i = 0; i < weeks.length; i++) {
      final week = weeks[i];
      final firstDay = week.firstWhere((d) => d != null, orElse: () => null);

      if (firstDay != null) {
        final monthName = DateFormat('MMM').format(firstDay);

        if (monthName != currentMonth) {
          if (currentMonth != null) {
            monthSpans.add(_MonthSpan(currentMonth, spanStart, i - spanStart));
          }
          currentMonth = monthName;
          spanStart = i;
        }
      }
    }
    // Add the last month
    if (currentMonth != null) {
      monthSpans
          .add(_MonthSpan(currentMonth, spanStart, weeks.length - spanStart));
    }

    // Calculate total width needed for all weeks
    final totalWidth = weeks.length * (_cellSize + _cellGap);

    // Build month labels using Stack for proper positioning
    return SizedBox(
      height: 16,
      width: totalWidth,
      child: Padding(
        padding: const EdgeInsets.only(left: 36), // Align with grid
        child: Stack(
          children: monthSpans.map((span) {
            final leftOffset = span.startIndex * (_cellSize + _cellGap);
            final spanWidth = span.weekCount * (_cellSize + _cellGap);
            // Only show label if there's enough space (at least 2 weeks)
            if (span.weekCount < 2) return const SizedBox.shrink();
            return Positioned(
              left: leftOffset,
              child: SizedBox(
                width: spanWidth,
                child: Text(
                  span.month,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDayColumn(BuildContext context) {
    final days = [
      '',
      context.tr(TranslationKeys.heatMapMon),
      '',
      context.tr(TranslationKeys.heatMapWed),
      '',
      context.tr(TranslationKeys.heatMapFri),
      ''
    ];

    return Column(
      children: days.map((day) {
        return Container(
          height: _cellSize + _cellGap,
          width: 28,
          alignment: Alignment.centerRight,
          child: Text(
            day,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekColumn(List<DateTime?> week, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: _cellGap),
      child: Column(
        children: week.map((day) {
          if (day == null) {
            return SizedBox(
              width: _cellSize,
              height: _cellSize + _cellGap,
            );
          }
          return _buildCell(day, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildCell(DateTime day, bool isDark) {
    final reviewCount = activityData[_normalizeDate(day)] ?? 0;
    final isToday = _isSameDay(day, DateTime.now());
    final color = _getCellColor(reviewCount, isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: _cellGap),
      child: Tooltip(
        message: '${DateFormat('MMM d').format(day)}: $reviewCount reviews',
        child: GestureDetector(
          onTap: onDayTap != null ? () => onDayTap!(day) : null,
          child: Container(
            width: _cellSize,
            height: _cellSize,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              border: isToday
                  ? Border.all(color: AppColors.primaryPurple, width: 1.5)
                  : Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.tr(
              TranslationKeys.heatMapLongestStreak, {'days': '$longestStreak'}),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(TranslationKeys.heatMapLess),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(width: 4),
            _legendBox(_getCellColor(0, isDark)),
            _legendBox(_getCellColor(1, isDark)),
            _legendBox(_getCellColor(3, isDark)),
            _legendBox(_getCellColor(6, isDark)),
            const SizedBox(width: 4),
            Text(
              context.tr(TranslationKeys.heatMapMore),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
      ),
    );
  }

  Color _getCellColor(int count, bool isDark) {
    if (count == 0) {
      // Make empty cells visible
      return isDark ? Colors.grey[800]! : Colors.grey[200]!;
    } else if (count <= 2) {
      return const Color(0xFF9BE9A8);
    } else if (count <= 5) {
      return const Color(0xFF40C463);
    } else {
      return const Color(0xFF30A14E);
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromSunday = date.weekday == DateTime.sunday ? 0 : date.weekday;
    return DateTime(date.year, date.month, date.day - daysFromSunday);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Helper class to track month label positioning
class _MonthSpan {
  final String month;
  final int startIndex;
  final int weekCount;

  _MonthSpan(this.month, this.startIndex, this.weekCount);
}
