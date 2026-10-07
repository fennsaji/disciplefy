import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_streak.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/achievement.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_level.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_stats.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/utils/unlock_dates.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/widgets/achievement_unlock_dialog.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';

/// My Progress, in the grouped-cards style.
///
/// Profile header (avatar, name, total XP, leaderboard rank), level card
/// with XP progress, three headline stats, achievements by category with
/// their progress, then streaks and the remaining statistics as group cards.
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
        preferredSize: const Size.fromHeight(76),
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
            return Center(
              child: CircularProgressIndicator(
                  color: settingsPrimaryFill(context)),
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
                _ProfileHeader(state: state),
                const SizedBox(height: 12),
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
                  _AchievementsProgressBar(
                    unlocked: state.unlockedCount,
                    total: state.totalCount,
                  ),
                  ..._buildAchievementGroups(context, state),
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

  Map<AchievementCategory, int> _progressMap(GamificationState state) {
    final stats = state.stats;
    if (stats == null) return const {};
    return {
      AchievementCategory.study: stats.totalStudiesCompleted,
      AchievementCategory.streak: stats.studyCurrentStreak,
      AchievementCategory.memory: stats.totalMemoryVerses,
      AchievementCategory.voice: stats.totalVoiceSessions,
      AchievementCategory.saved: stats.totalSavedGuides,
    };
  }

  String _categoryTitle(BuildContext context, AchievementCategory category) {
    final l10n = AppLocalizations.of(context)!;
    return switch (category) {
      AchievementCategory.study => '📚 ${l10n.achievementCategoryStudy}',
      AchievementCategory.streak => '🔥 ${l10n.achievementCategoryStreak}',
      AchievementCategory.memory => '🧠 ${l10n.achievementCategoryMemory}',
      AchievementCategory.voice => '🎙️ ${l10n.achievementCategoryVoice}',
      AchievementCategory.saved => '📕 ${l10n.achievementCategorySaved}',
    };
  }

  /// One small heading and group card per category, in [_categoryOrder].
  List<Widget> _buildAchievementGroups(
      BuildContext context, GamificationState state) {
    final progress = _progressMap(state);
    return [
      for (final category in _categoryOrder)
        if (state.achievements.any((a) => a.category == category)) ...[
          _CategoryHeading(_categoryTitle(context, category)),
          SettingsGroup(
            children: [
              for (final achievement
                  in state.achievements.where((a) => a.category == category))
                _AchievementRow(
                  achievement: achievement,
                  currentProgress:
                      achievement.currentProgress ?? progress[category],
                  onTap: () =>
                      _showAchievementDetails(context, achievement, state),
                ),
            ],
          ),
        ],
    ];
  }

  /// The one daily streak, as Home shows it: the app-wide daily verse
  /// bloc's copy when it has one (it updates the moment the verse is read
  /// or a lesson finished), else null and the stats' copy of the same
  /// streak is used.
  DailyVerseStreak? _liveDailyStreak(BuildContext context) {
    try {
      final verseState = context.watch<DailyVerseBloc>().state;
      if (verseState is DailyVerseLoaded) return verseState.streak;
    } on ProviderNotFoundException {
      // No daily verse bloc above this page (e.g. opened in isolation).
    }
    return null;
  }

  int _dailyStreak(BuildContext context, UserStats stats) =>
      _liveDailyStreak(context)?.currentStreak ?? stats.verseCurrentStreak;

  /// Best run of the same daily streak; never below the current one.
  int _dailyBest(BuildContext context, UserStats stats) {
    final live = _liveDailyStreak(context);
    final longest = live?.longestStreak ?? stats.verseLongestStreak;
    final current = live?.currentStreak ?? stats.verseCurrentStreak;
    return longest > current ? longest : current;
  }

  Widget _buildHeadlineStats(BuildContext context, GamificationState state) {
    final stats = state.stats!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SettingsStatTile(
              icon: Icons.local_fire_department_outlined,
              value: '${_dailyStreak(context, stats)}',
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

  /// The current daily streak is the headline "Day streak" tile; this
  /// section adds its best run. There is one streak, so no separate study
  /// or verse streak rows.
  List<Widget> _buildStreaksSection(
      BuildContext context, GamificationState state) {
    final l10n = AppLocalizations.of(context)!;
    final best = _dailyBest(context, state.stats!);
    if (best <= 0) return const [];
    return [
      SettingsSectionLabel(l10n.progressStreaks),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.emoji_events_outlined,
            title: l10n.progressPersonalBest,
            value: '$best ${l10n.progressDays}',
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
    final current = achievement.currentProgress ??
        _progressMap(state)[achievement.category];

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
                  valueColor: AlwaysStoppedAnimation<Color>(
                      settingsPrimaryFill(context)),
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
                '${l10n.progressUnlockedOn} ${formatUnlockDate(achievement.unlockedAt!)}',
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
    final percent = '${(level.progressToNextLevel * 100).round()}%';
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
          colors: [
            settingsPrimaryFill(context)
                .withValues(alpha: palette.isDark ? 0.22 : 0.12),
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
              fontSize: 12,
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
            value: percent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: level.progressToNextLevel,
                minHeight: 7,
                backgroundColor: palette.raised,
                valueColor:
                    AlwaysStoppedAnimation<Color>(settingsPrimaryFill(context)),
              ),
            ),
          ),
          if (!level.isMaxLevel) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ExcludeSemantics(
                child: Text(
                  percent,
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar with the level number, display name, total XP and, when ranked,
/// a tappable leaderboard rank.
class _ProfileHeader extends StatelessWidget {
  final GamificationState state;

  const _ProfileHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final auth =
        sl.isRegistered<AuthStateProvider>() ? sl<AuthStateProvider>() : null;
    final name = auth?.profileBasedDisplayName ?? '';
    final photoUrl = auth?.profilePictureUrl;
    final stats = state.stats;
    final level = state.level;
    final initial = name.trim().isEmpty ? null : name.trim()[0].toUpperCase();

    Widget fallback() => Center(
          child: initial == null
              ? Icon(Icons.person_outline, size: 28, color: palette.accentIcon)
              : Text(
                  initial,
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                  ),
                ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        SettingsToneColors.of(context, SettingsTone.gold).fill,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl == null
                      ? fallback()
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => fallback(),
                        ),
                ),
                if (level != null)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Semantics(
                      label: context.tr(
                          TranslationKeys.gamificationCurrentLevel,
                          {'level': '${level.level}'}),
                      excludeSemantics: true,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: settingsPrimaryFill(context),
                          border: Border.all(color: palette.card, width: 2),
                        ),
                        child: Text(
                          '${level.level}',
                          style: AppFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                if (stats != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.decimalPattern().format(stats.totalXp)} ${l10n.progressXpTotal}',
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          if (stats?.isOnLeaderboard == true) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.progressViewLeaderboard,
              child: Material(
                color: SettingsToneColors.of(context, SettingsTone.gold).fill,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => AppRouter.router.goToLeaderboard(),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 18, color: palette.gold),
                        const SizedBox(height: 2),
                        Text(
                          '#${stats!.leaderboardRank}',
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Overall unlocked / total bar under the achievements heading.
class _AchievementsProgressBar extends StatelessWidget {
  final int unlocked;
  final int total;

  const _AchievementsProgressBar({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      value: '$unlocked/$total',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total > 0 ? unlocked / total : 0,
          minHeight: 6,
          backgroundColor: palette.raised,
          valueColor:
              AlwaysStoppedAnimation<Color>(settingsPrimaryFill(context)),
        ),
      ),
    );
  }
}

/// Category name above its group of achievements ("📚 Study").
class _CategoryHeading extends StatelessWidget {
  final String text;

  const _CategoryHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}

/// One achievement: badge, name, description, then either its progress
/// toward the threshold or when it was unlocked; XP reward on the right.
class _AchievementRow extends StatelessWidget {
  final Achievement achievement;
  final int? currentProgress;
  final VoidCallback onTap;

  const _AchievementRow({
    required this.achievement,
    required this.currentProgress,
    required this.onTap,
  });

  String _relativeDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return relativeUnlockLabel(
      date,
      now: DateTime.now(),
      today: l10n.progressToday,
      yesterday: l10n.progressYesterday,
      daysAgo: l10n.progressDaysAgo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final unlocked = achievement.isUnlocked;
    final threshold = achievement.threshold;
    final current = currentProgress ?? 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AchievementCircle(achievement: achievement, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: AppFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: unlocked ? palette.text : palette.muted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      color: palette.muted,
                      height: 1.35,
                    ),
                  ),
                  if (!unlocked && threshold != null && threshold > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: achievement.getProgress(current),
                              minHeight: 5,
                              backgroundColor: palette.raised,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  settingsPrimaryFill(context)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${current.clamp(0, threshold)}/$threshold',
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (unlocked && achievement.unlockedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.progressUnlocked} ${_relativeDate(context, achievement.unlockedAt!)}',
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (achievement.xpReward > 0) ...[
              const SizedBox(width: 8),
              XpRewardPill(xp: achievement.xpReward, compact: true),
            ],
          ],
        ),
      ),
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
