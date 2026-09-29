import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/achievement.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_level.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/widgets/achievement_unlock_dialog.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';

/// My Progress, in the S3 grouped-cards style.
///
/// Level card with XP progress, three headline stats, the achievement
/// badges, then streaks and the remaining statistics as group cards.
class StatsDashboardPage extends StatefulWidget {
  const StatsDashboardPage({super.key});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  static const _categoryOrder = [
    AchievementCategory.study,
    AchievementCategory.streak,
    AchievementCategory.memory,
    AchievementCategory.voice,
    AchievementCategory.saved,
  ];

  @override
  void initState() {
    super.initState();
    // Load stats when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationBloc>().add(const LoadGamificationStats());
    });
  }

  void _refresh() => context
      .read<GamificationBloc>()
      .add(const LoadGamificationStats(forceRefresh: true));

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: palette.page,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: BlocBuilder<GamificationBloc, GamificationState>(
          buildWhen: (a, b) => a.level != b.level,
          builder: (context, state) => SettingsTopBar(
            title: l10n.progressTitle,
            subtitle: state.level == null
                ? null
                : '${state.level!.title} · ${context.tr(TranslationKeys.gamificationCurrentLevel, {
                        'level': '${state.level!.level}'
                      })}',
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            actions: [
              IconButton(
                tooltip: l10n.progressRetry,
                onPressed: _refresh,
                icon: Icon(Icons.refresh, color: palette.muted),
              ),
            ],
          ),
        ),
      ),
      body: BlocConsumer<GamificationBloc, GamificationState>(
        listener: (context, state) {
          // Show achievement unlock notification
          if (state.hasPendingNotifications && state.nextNotification != null) {
            _showAchievementUnlockDialog(context, state.nextNotification!);
          }
        },
        builder: (context, state) {
          if (state.status == GamificationStatus.loading &&
              state.stats == null) {
            return const Center(
              child: CircularProgressIndicator(color: settingsPrimaryFill),
            );
          }

          if (state.status == GamificationStatus.error && state.stats == null) {
            return _buildErrorState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              // Wait a bit for the state to update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                if (state.level != null)
                  _LevelCard(
                    level: state.level!,
                    nextTitle: LevelConfigs.getNextLevel(state.level!.level)
                        ?.getTitle(state.languageCode),
                  ),
                if (state.stats != null) ...[
                  const SizedBox(height: 12),
                  _buildHeadlineStats(context, state),
                ],
                if (state.achievements.isNotEmpty) ...[
                  SettingsSectionLabel(context.tr(
                    TranslationKeys.gamificationAchievementsCount,
                    {
                      'unlocked': '${state.unlockedCount}',
                      'total': '${state.totalCount}',
                    },
                  )),
                  _AchievementBadges(
                    achievements: _orderedAchievements(state.achievements),
                    onTap: (a) => _showAchievementDetails(context, a, state),
                  ),
                ],
                if (state.stats != null) ...[
                  ..._buildStreaksSection(context, state),
                  ..._buildStatisticsSection(context, state),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Achievement> _orderedAchievements(List<Achievement> achievements) => [
        for (final category in _categoryOrder)
          ...achievements.where((a) => a.category == category),
      ];

  Widget _buildHeadlineStats(BuildContext context, GamificationState state) {
    final stats = state.stats!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SettingsStatTile(
              icon: Icons.local_fire_department_outlined,
              tone: SettingsTone.gold,
              value: '${stats.studyCurrentStreak}',
              label: context.tr(TranslationKeys.gamificationDayStreakLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SettingsStatTile(
              icon: Icons.menu_book_outlined,
              value: '${stats.totalStudiesCompleted}',
              label: context.tr(TranslationKeys.gamificationStudiesLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SettingsStatTile(
              icon: Icons.psychology_outlined,
              tone: SettingsTone.green,
              value: '${stats.totalMemoryVerses}',
              label: context.tr(TranslationKeys.gamificationVersesLabel),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStreaksSection(
      BuildContext context, GamificationState state) {
    final l10n = AppLocalizations.of(context)!;
    final stats = state.stats!;
    String days(int n) => '$n ${l10n.progressDays}';
    return [
      SettingsSectionLabel(l10n.progressStreaks),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.local_fire_department_outlined,
            tone: SettingsTone.gold,
            title: l10n.progressStudyStreak,
            value: days(stats.studyCurrentStreak),
          ),
          SettingsRow(
            icon: Icons.auto_stories_outlined,
            tone: SettingsTone.sky,
            title: l10n.progressVerseStreak,
            value: days(stats.verseCurrentStreak),
          ),
          if (stats.studyLongestStreak > 0)
            SettingsRow(
              icon: Icons.emoji_events_outlined,
              tone: SettingsTone.gold,
              title: l10n.progressPersonalBest,
              value: days(stats.studyLongestStreak),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildStatisticsSection(
      BuildContext context, GamificationState state) {
    final l10n = AppLocalizations.of(context)!;
    final stats = state.stats!;
    return [
      SettingsSectionLabel(l10n.progressStatistics),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.access_time,
            tone: SettingsTone.sky,
            title: l10n.progressTimeSpent,
            value: stats.formattedTimeSpent,
          ),
          SettingsRow(
            icon: Icons.mic_none_outlined,
            tone: SettingsTone.green,
            title: l10n.progressVoiceSessions,
            value: '${stats.totalVoiceSessions}',
          ),
          SettingsRow(
            icon: Icons.bookmark_border,
            tone: SettingsTone.amber,
            title: l10n.progressSavedGuides,
            value: '${stats.totalSavedGuides}',
          ),
          SettingsRow(
            icon: Icons.calendar_today_outlined,
            tone: SettingsTone.green,
            title: l10n.progressStudyDays,
            value: '${stats.totalStudyDays}',
          ),
          SettingsRow(
            icon: Icons.leaderboard_outlined,
            title: l10n.progressViewLeaderboard,
            value: stats.isOnLeaderboard ? '#${stats.leaderboardRank}' : null,
            onTap: () => AppRouter.router.goToLeaderboard(),
          ),
        ],
      ),
    ];
  }

  Widget _buildErrorState(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SettingsIconTile(
              icon: Icons.error_outline,
              tone: SettingsTone.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.progressFailedLoad,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.commonErrorTryAgain),
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SettingsButton(
              label: l10n.progressRetry,
              icon: Icons.refresh,
              height: 46,
              onPressed: () => context
                  .read<GamificationBloc>()
                  .add(const LoadGamificationStats()),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementUnlockDialog(
      BuildContext context, AchievementUnlockResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AchievementUnlockDialog(
        achievement: result,
        onDismiss: () {
          Navigator.of(dialogContext).pop();
          // Dismiss the notification from the bloc
          context
              .read<GamificationBloc>()
              .add(const DismissAchievementNotification());
        },
      ),
    );
  }

  void _showAchievementDetails(
    BuildContext context,
    Achievement achievement,
    GamificationState state,
  ) {
    final stats = state.stats;
    final progressMap = <AchievementCategory, int>{
      if (stats != null) ...{
        AchievementCategory.study: stats.totalStudiesCompleted,
        AchievementCategory.streak: stats.studyCurrentStreak,
        AchievementCategory.memory: stats.totalMemoryVerses,
        AchievementCategory.voice: stats.totalVoiceSessions,
        AchievementCategory.saved: stats.totalSavedGuides,
      },
    };
    final current =
        achievement.currentProgress ?? progressMap[achievement.category];

    showSettingsSheet<void>(
      context: context,
      builder: (sheetContext) {
        final palette = ReaderPalette.of(sheetContext);
        final l10n = AppLocalizations.of(sheetContext)!;
        final threshold = achievement.threshold;
        return SettingsSheetFrame(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AchievementCircle(achievement: achievement, size: 80),
            const SizedBox(height: 16),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: achievement.isUnlocked ? palette.text : palette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            XpRewardPill(xp: achievement.xpReward),
            const SizedBox(height: 16),
            if (!achievement.isUnlocked &&
                threshold != null &&
                threshold > 0 &&
                current != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.getProgress(current),
                  minHeight: 6,
                  backgroundColor: palette.raised,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(settingsPrimaryFill),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sheetContext.tr(TranslationKeys.gamificationProgressCount, {
                  'current': '${current.clamp(0, threshold)}',
                  'total': '$threshold',
                }),
                style: AppFonts.inter(fontSize: 12, color: palette.muted),
              ),
              const SizedBox(height: 12),
            ],
            if (achievement.isUnlocked && achievement.unlockedAt != null)
              Text(
                '${l10n.progressUnlockedOn} ${_formatDate(achievement.unlockedAt!)}',
                style: AppFonts.inter(fontSize: 12, color: palette.muted),
              )
            else if (!achievement.isUnlocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Text(
                      l10n.progressLocked,
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Level name eyebrow, total XP, XP to the next level and a progress bar.
class _LevelCard extends StatelessWidget {
  final UserLevel level;
  final String? nextTitle;

  const _LevelCard({required this.level, required this.nextTitle});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final xp = NumberFormat.decimalPattern().format(level.currentXp);
    final remaining = level.isMaxLevel
        ? l10n.progressMaxLevel
        : nextTitle != null
            ? context.tr(TranslationKeys.gamificationXpToLevel, {
                'xp': NumberFormat.decimalPattern()
                    .format(level.xpNeededForNextLevel),
                'level': nextTitle,
              })
            : '${level.xpNeededForNextLevel} ${l10n.progressXpToNextLevel}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: palette.isDark
              ? [
                  settingsPrimaryFill.withValues(alpha: 0.22),
                  palette.card,
                ]
              : [
                  const Color(0xFFE6E4FC),
                  palette.card,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level.title.toUpperCase(),
            style: AppFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: palette.accentIcon,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '$xp XP',
                style: AppFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  height: 1.1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  remaining,
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            value: '${(level.progressToNextLevel * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: level.progressToNextLevel,
                minHeight: 7,
                backgroundColor:
                    palette.isDark ? palette.raised : const Color(0xFFE4E4EA),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(settingsPrimaryFill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-per-row grid of achievement circles with names.
class _AchievementBadges extends StatelessWidget {
  final List<Achievement> achievements;
  final ValueChanged<Achievement> onTap;

  const _AchievementBadges({required this.achievements, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const gap = 8.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final circle = itemWidth.clamp(40.0, 58.0);
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final achievement in achievements)
              SizedBox(
                width: itemWidth,
                child: Semantics(
                  button: true,
                  label: achievement.name,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(achievement),
                    child: Column(
                      children: [
                        AchievementCircle(
                          achievement: achievement,
                          size: circle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          achievement.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: achievement.isUnlocked
                                ? palette.text
                                : palette.dim,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Round badge: gold tint when unlocked, raised and faded when locked.
class AchievementCircle extends StatelessWidget {
  final Achievement achievement;
  final double size;

  const AchievementCircle({
    super.key,
    required this.achievement,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gold = SettingsToneColors.of(context, SettingsTone.gold);
    final unlocked = achievement.isUnlocked;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? gold.fill : palette.raised,
        border: Border.all(
          color: unlocked
              ? gold.foreground.withValues(alpha: 0.5)
              : palette.hairline,
          width: 1.5,
        ),
      ),
      child: Opacity(
        opacity: unlocked ? 1 : 0.35,
        child: Text(
          achievement.icon,
          style: TextStyle(fontSize: size * 0.42),
        ),
      ),
    );
  }
}
