import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../widgets/memory_heat_map.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';

/// Memory Verses Statistics Page.
///
/// Displays comprehensive memory verse statistics:
/// - Activity heat map (12-week calendar)
/// - Current and longest streaks
/// - Mastery level distribution
/// - Practice mode statistics
/// - Recent achievements
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
    return BlocProvider.value(
      value: _bloc,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBackNavigation,
            ),
            title: Text(context.tr(TranslationKeys.memoryStats)),
          ),
          body: BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
            builder: (context, state) {
              if (state is MemoryVerseLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is MemoryVerseError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: AppColors.lightTextSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load statistics',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () {
                          _bloc.add(const LoadMemoryStatisticsEvent());
                        },
                      ),
                    ],
                  ),
                );
              }

              if (state is MemoryStatisticsLoaded) {
                return _buildStatisticsContent(state.statistics);
              }

              // Default empty state
              return const Center(
                child: Text('No statistics available'),
              );
            },
          ),
        ).withAuthProtection(),
      ),
    );
  }

  Widget _buildStatisticsContent(Map<String, dynamic> statistics) {
    // Extract data from statistics
    final activityData = _parseActivityData(
        statistics['activity_data'] as Map<String, dynamic>? ?? {});
    final currentStreak = statistics['current_streak'] as int? ?? 0;
    final longestStreak = statistics['longest_streak'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Practice Activity Heat Map
          _buildSectionTitle(context.tr(TranslationKeys.practiceActivity)),
          const SizedBox(height: 16),
          MemoryHeatMap(
            activityData: activityData,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
          ),
          const SizedBox(height: 32),

          // Mastery Distribution
          _buildSectionTitle(context.tr(TranslationKeys.masteryDistribution)),
          const SizedBox(height: 16),
          _buildMasteryDistribution(
              statistics['mastery_distribution'] as Map<String, dynamic>? ??
                  {}),
          const SizedBox(height: 32),

          // Practice Mode Statistics
          _buildSectionTitle(context.tr(TranslationKeys.practiceModeStats)),
          const SizedBox(height: 16),
          _buildPracticeModeStats(
              statistics['practice_modes'] as List<dynamic>? ?? []),
          const SizedBox(height: 32),

          // Overall Statistics
          _buildSectionTitle(context.tr(TranslationKeys.overallStats)),
          const SizedBox(height: 16),
          _buildOverallStats(statistics),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _buildMasteryDistribution(Map<String, dynamic> masteryDistribution) {
    // Extract mastery counts from backend data
    final masteryData = {
      context.tr(TranslationKeys.memoryStatsBeginner):
          masteryDistribution['beginner'] as int? ?? 0,
      context.tr(TranslationKeys.memoryStatsIntermediate):
          masteryDistribution['intermediate'] as int? ?? 0,
      context.tr(TranslationKeys.memoryStatsAdvanced):
          masteryDistribution['advanced'] as int? ?? 0,
      context.tr(TranslationKeys.memoryStatsExpert):
          masteryDistribution['expert'] as int? ?? 0,
      context.tr(TranslationKeys.memoryStatsMaster):
          masteryDistribution['master'] as int? ?? 0,
    };

    final masteryColors = {
      context.tr(TranslationKeys.memoryStatsBeginner):
          AppColors.masteryBeginner,
      context.tr(TranslationKeys.memoryStatsIntermediate):
          AppColors.masteryIntermediate,
      context.tr(TranslationKeys.memoryStatsAdvanced):
          AppColors.masteryAdvanced,
      context.tr(TranslationKeys.memoryStatsExpert): AppColors.masteryExpert,
      context.tr(TranslationKeys.memoryStatsMaster): AppColors.masteryMaster,
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: masteryData.entries.map((entry) {
            final level = entry.key;
            final count = entry.value;
            final color = masteryColors[level]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      level,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    context.tr(TranslationKeys.memoryStatsVerseCount,
                        {'count': count.toString()}),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPracticeModeStats(List<dynamic> practiceModes) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Map backend data to UI format
    final modeIconMap = {
      'flip_card': Icons.flip,
      'word_bank': Icons.touch_app,
      'cloze': Icons.edit_note,
      'first_letter': Icons.abc,
      'progressive': Icons.trending_up,
      'word_scramble': Icons.shuffle,
      'audio': Icons.volume_up,
      'type_it_out': Icons.keyboard,
    };

    final modeStats = practiceModes.map((mode) {
      final modeMap = mode as Map<String, dynamic>;
      final modeType = modeMap['mode_type'] as String;
      return {
        'name': _formatModeName(modeType),
        'icon': modeIconMap[modeType] ?? Icons.stars,
        'successRate': (modeMap['success_rate'] as num?)?.toInt() ?? 0,
        'count': modeMap['times_practiced'] as int? ?? 0,
      };
    }).toList();

    if (modeStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              context.tr(TranslationKeys.noPracticeModeData),
              style: const TextStyle(color: AppColors.lightTextSecondary),
            ),
          ),
        ),
      );
    }

    return Column(
      children: modeStats.map((mode) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  mode['icon'] as IconData,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mode['count']} practices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mode['successRate']}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverallStats(Map<String, dynamic> statistics) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Extract overall statistics from backend data
    final overallStats = [
      {
        'label': context.tr(TranslationKeys.memoryStatsTotalVerses),
        'value': '${statistics['total_verses'] ?? 0}',
        'icon': Icons.book
      },
      {
        'label': context.tr(TranslationKeys.memoryStatsTotalReviews),
        'value': '${statistics['total_reviews'] ?? 0}',
        'icon': Icons.replay
      },
      {
        'label': context.tr(TranslationKeys.memoryStatsPerfectRecalls),
        'value': '${statistics['perfect_recalls'] ?? 0}',
        'icon': Icons.star
      },
      {
        'label': context.tr(TranslationKeys.memoryStatsPracticeDays),
        'value': '${statistics['total_practice_days'] ?? 0}',
        'icon': Icons.calendar_today
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: overallStats.length,
      itemBuilder: (context, index) {
        final stat = overallStats[index];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  stat['icon'] as IconData,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat['label'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatModeName(String modeType) {
    // Convert snake_case to Title Case
    return modeType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
