import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_activity_grid.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Memory Verses Statistics Page.
///
/// Overall tiles (total verses, reviews, perfect recalls, practice days),
/// the practice activity heat map with streaks, mastery bars and per-mode
/// practice records (times practised and success rate).
class MemoryStatsPage extends StatefulWidget {
  const MemoryStatsPage({super.key});

  @override
  State<MemoryStatsPage> createState() => _MemoryStatsPageState();
}

class _MemoryStatsPageState extends State<MemoryStatsPage> {
  late MemoryVerseBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<MemoryVerseBloc>();
    _bloc.add(const LoadMemoryStatisticsEvent());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  /// Handle back navigation - go to memory verses home when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to memory verses home
      context.go('/memory-verses');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return BlocProvider.value(
      value: _bloc,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: Scaffold(
          backgroundColor: palette.page,
          appBar: MemoryTopBar(
            title: context.tr(TranslationKeys.memoryStats),
            subtitle: context.tr(TranslationKeys.memoryScreensStatsSubtitle),
            onBack: _handleBackNavigation,
          ),
          body: BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
            builder: (context, state) {
              if (state is MemoryVerseLoading) {
                return const LedgerLoading();
              }

              if (state is MemoryVerseError) {
                return LedgerMessage(
                  icon: Icons.error_outline_rounded,
                  title: context.tr(TranslationKeys.memoryStatsLoadFailed),
                  actionLabel: context.tr(TranslationKeys.commonRetry),
                  onAction: () => _bloc.add(const LoadMemoryStatisticsEvent()),
                  isError: true,
                );
              }

              if (state is MemoryStatisticsLoaded) {
                return _buildStatisticsContent(state.statistics);
              }

              return LedgerMessage(
                icon: Icons.insights_outlined,
                title: context.tr(TranslationKeys.memoryStatsNoData),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsContent(Map<String, dynamic> statistics) {
    final activityData = _parseActivityData(
        statistics['activity_data'] as Map<String, dynamic>? ?? {});
    final currentStreak = statistics['current_streak'] as int? ?? 0;
    final longestStreak = statistics['longest_streak'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kMemoryGutter, 4, kMemoryGutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverallStats(statistics),
          const SizedBox(height: 12),
          _ActivityPanel(
            activityData: activityData,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
          ),
          const SizedBox(height: 14),
          _Panel(
            label: context.tr(TranslationKeys.masteryDistribution),
            child: _buildMasteryDistribution(
                statistics['mastery_distribution'] as Map<String, dynamic>? ??
                    {}),
          ),
          MemorySectionLabel(
            context.tr(TranslationKeys.memoryScreensPracticeModes),
            padding: const EdgeInsets.only(top: 24, bottom: 4),
          ),
          _buildPracticeModeStats(
              statistics['practice_modes'] as List<dynamic>? ?? []),
        ],
      ),
    );
  }

  Map<DateTime, int> _parseActivityData(Map<String, dynamic> activityData) {
    final result = <DateTime, int>{};
    activityData.forEach((key, value) {
      try {
        final date = DateTime.parse(key);
        result[date] = value as int;
      } catch (e) {
        // Skip invalid dates
      }
    });
    return result;
  }

  /// Four short tiles across (verses, reviews, perfect, practice days) on a
  /// phone; on a narrow screen (320pt) or when a short label would not fit
  /// whole, two rows of two with the full labels.
  Widget _buildOverallStats(Map<String, dynamic> statistics) {
    final values = [
      '${statistics['total_verses'] ?? 0}',
      '${statistics['total_reviews'] ?? 0}',
      '${statistics['perfect_recalls'] ?? 0}',
      '${statistics['total_practice_days'] ?? 0}',
    ];
    final shortLabels = [
      context.tr(TranslationKeys.memoryStatsShortVerses),
      context.tr(TranslationKeys.memoryStatsShortReviews),
      context.tr(TranslationKeys.memoryStatsShortPerfect),
      context.tr(TranslationKeys.memoryStatsShortDays),
    ];
    final fullLabels = [
      context.tr(TranslationKeys.memoryStatsTotalVerses),
      context.tr(TranslationKeys.memoryStatsTotalReviews),
      context.tr(TranslationKeys.memoryStatsPerfectRecalls),
      context.tr(TranslationKeys.memoryStatsPracticeDays),
    ];
    List<Widget> tiles(List<String> labels) => [
          for (var i = 0; i < 4; i++)
            MemoryStatTile(value: values[i], label: labels[i]),
        ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final tileText = (constraints.maxWidth - spacing * 3) / 4 - 10;
        final fits = constraints.maxWidth >= 340 &&
            shortLabels.every((label) => _wordsFit(label, tileText));
        if (fits) {
          return MemoryStatRow(tiles: tiles(shortLabels), spacing: spacing);
        }
        final full = tiles(fullLabels);
        return Column(
          children: [
            MemoryStatRow(tiles: full.sublist(0, 2), spacing: spacing),
            const SizedBox(height: spacing),
            MemoryStatRow(tiles: full.sublist(2), spacing: spacing),
          ],
        );
      },
    );
  }

  /// Whether every word of [label] fits on a line of [width] at the tile's
  /// label style (no word broken or cut).
  bool _wordsFit(String label, double width) {
    if (width <= 0) return false;
    final style =
        DefaultTextStyle.of(context).style.merge(AppFonts.inter(fontSize: 12));
    for (final word in label.split(RegExp(r'\s+'))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      if (painter.width > width) return false;
    }
    return true;
  }

  Widget _buildMasteryDistribution(Map<String, dynamic> masteryDistribution) {
    final palette = ReaderPalette.of(context);
    final levels = <(String, int, bool)>[
      (
        context.tr(TranslationKeys.memoryStatsBeginner),
        masteryDistribution['beginner'] as int? ?? 0,
        false,
      ),
      (
        context.tr(TranslationKeys.memoryStatsIntermediate),
        masteryDistribution['intermediate'] as int? ?? 0,
        false,
      ),
      (
        context.tr(TranslationKeys.memoryStatsAdvanced),
        masteryDistribution['advanced'] as int? ?? 0,
        false,
      ),
      (
        context.tr(TranslationKeys.memoryStatsExpert),
        masteryDistribution['expert'] as int? ?? 0,
        false,
      ),
      (
        context.tr(TranslationKeys.memoryStatsMaster),
        masteryDistribution['master'] as int? ?? 0,
        true,
      ),
    ];
    final total = levels.fold<int>(0, (sum, level) => sum + level.$2);

    return Column(
      children: [
        for (final level in levels)
          Semantics(
            label: '${level.$1} ${level.$2}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Level names wrap instead of truncating (Malayalam).
                  Expanded(
                    flex: 2,
                    child: Text(
                      level.$1,
                      style:
                          AppFonts.inter(fontSize: 14.5, color: palette.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: MemoryProgressBar(
                      value: total == 0 ? 0 : level.$2 / total,
                      color: level.$3 ? palette.gold : palette.accentIcon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${level.$2}',
                      textAlign: TextAlign.end,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        fontFeatures: kMemoryTabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPracticeModeStats(List<dynamic> practiceModes) {
    final palette = ReaderPalette.of(context);
    final modeStats = practiceModes.take(20).map((mode) {
      final modeMap = mode as Map<String, dynamic>;
      final modeType = modeMap['mode_type'] as String;
      return (
        type: modeType,
        successRate: (modeMap['success_rate'] as num?)?.toInt() ?? 0,
        count: modeMap['times_practiced'] as int? ?? 0,
      );
    }).toList();

    if (modeStats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.tr(TranslationKeys.noPracticeModeData),
          style: AppFonts.inter(fontSize: 14, color: palette.muted),
        ),
      );
    }

    return Column(
      children: [
        for (final mode in modeStats)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.hairline)),
            ),
            child: Row(
              children: [
                Icon(_modeIcon(mode.type), size: 20, color: palette.accentIcon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _modeName(mode.type),
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                      Text(
                        context.tr(TranslationKeys.memoryScreensPracticesCount,
                            {'count': mode.count.toString()}),
                        style: AppFonts.inter(
                            fontSize: 12.5, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${mode.successRate}%',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.gold,
                    fontFeatures: kMemoryTabular,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _modeIcon(String modeType) {
    try {
      return PracticeModeEntity(
        modeType: PracticeModeTypeExtension.fromJson(modeType),
        timesPracticed: 0,
        successRate: 0,
        isFavorite: false,
      ).icon;
    } catch (_) {
      return Icons.stars_outlined;
    }
  }

  String _modeName(String modeType) {
    switch (modeType) {
      case 'flip_card':
        return context.tr(TranslationKeys.practiceModeFlipCard);
      case 'word_bank':
        return context.tr(TranslationKeys.practiceModeWordBank);
      case 'cloze':
        return context.tr(TranslationKeys.practiceModeCloze);
      case 'first_letter':
        return context.tr(TranslationKeys.practiceModeFirstLetter);
      case 'progressive':
        return context.tr(TranslationKeys.practiceModeProgressive);
      case 'word_scramble':
        return context.tr(TranslationKeys.practiceModeWordScramble);
      case 'audio':
        return context.tr(TranslationKeys.practiceModeAudio);
      case 'type_it_out':
        return context.tr(TranslationKeys.practiceModeTypeItOut);
      default:
        // Convert snake_case to Title Case
        return modeType
            .split('_')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}

/// Raised card with a muted tracked label, used for the mastery block.
class _Panel extends StatelessWidget {
  final String label;
  final Widget child;

  const _Panel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return MemoryAnswerCard(
      label: label,
      labelColor: palette.muted,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: child,
    );
  }
}

/// Practice activity card: title and "Last 12 weeks" with the current
/// streak badge, the heat grid with month and weekday labels, then the
/// longest streak and the Less / More scale.
class _ActivityPanel extends StatelessWidget {
  final Map<DateTime, int> activityData;
  final int currentStreak;
  final int longestStreak;

  const _ActivityPanel({
    required this.activityData,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gold = MemoryToneColors.of(context, MemoryTone.gold);
    return MemoryAnswerCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.tr(TranslationKeys.heatMapTitle),
                      style: AppFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(TranslationKeys.heatMapSubtitle),
                    style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.fill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_outlined,
                        size: 16, color: gold.foreground),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.heatMapDayStreak,
                            {'count': '$currentStreak'}),
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: gold.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PracticeActivityGrid(activityData: activityData),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                longestStreak == 1
                    ? context.tr(TranslationKeys.heatMapLongestStreakOne)
                    : context.tr(TranslationKeys.heatMapLongestStreak,
                        {'days': '$longestStreak'}),
                style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
              ),
              const PracticeActivityLegend(),
            ],
          ),
        ],
      ),
    );
  }
}
