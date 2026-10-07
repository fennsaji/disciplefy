import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_champion_entry.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Leaderboard period shown by [MemoryChampionsPage]; [apiValue] is what the
/// leaderboard event expects.
enum ChampionsPeriod {
  weekly('weekly'),
  monthly('monthly'),
  allTime('all_time');

  final String apiValue;
  const ChampionsPeriod(this.apiValue);
}

/// Memory Champions Leaderboard Page.
///
/// Displays rankings based on:
/// - Primary: Total verses at Master level
/// - Tiebreaker 1: Longest practice streak
/// - Tiebreaker 2: Total practice days
///
/// Weekly / Monthly / All time switch, the user's own rank card, then the
/// ranked rows with medals for the top three.
class MemoryChampionsPage extends StatefulWidget {
  const MemoryChampionsPage({super.key});

  @override
  State<MemoryChampionsPage> createState() => _MemoryChampionsPageState();
}

class _MemoryChampionsPageState extends State<MemoryChampionsPage> {
  late MemoryVerseBloc _bloc;

  /// All time is loaded first, so the switch starts there (the old tab bar
  /// showed Weekly selected while listing all-time data).
  ChampionsPeriod _period = ChampionsPeriod.allTime;

  @override
  void initState() {
    super.initState();
    _bloc = sl<MemoryVerseBloc>();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _loadLeaderboard() {
    _bloc.add(LoadMemoryChampionsLeaderboardEvent(period: _period.apiValue));
  }

  void _onPeriodChanged(ChampionsPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _loadLeaderboard();
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
            title: context.tr(TranslationKeys.memoryChampions),
            subtitle:
                context.tr(TranslationKeys.memoryScreensChampionsSubtitle),
            onBack: _handleBackNavigation,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    kMemoryGutter, 4, kMemoryGutter, 12),
                child: MemorySegmentedControl<ChampionsPeriod>(
                  segments: [
                    MemorySegment(
                      value: ChampionsPeriod.weekly,
                      label: context.tr(TranslationKeys.weekly),
                    ),
                    MemorySegment(
                      value: ChampionsPeriod.monthly,
                      label: context.tr(TranslationKeys.monthly),
                    ),
                    MemorySegment(
                      value: ChampionsPeriod.allTime,
                      label: context.tr(TranslationKeys.allTime),
                    ),
                  ],
                  selected: _period,
                  onChanged: _onPeriodChanged,
                ),
              ),
              Expanded(
                child: BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
                  builder: (context, state) {
                    if (state is MemoryVerseLoading) {
                      return const LedgerLoading();
                    }

                    if (state is MemoryVerseError) {
                      return LedgerMessage(
                        icon: Icons.error_outline_rounded,
                        title: context
                            .tr(TranslationKeys.memoryChampionsLoadFailed),
                        actionLabel: context.tr(TranslationKeys.commonRetry),
                        onAction: _loadLeaderboard,
                        isError: true,
                      );
                    }

                    if (state is MemoryChampionsLeaderboardLoaded) {
                      return _buildLeaderboard(
                          state.userStats, state.leaderboard);
                    }

                    return LedgerMessage(
                      icon: Icons.emoji_events_outlined,
                      title: context.tr(TranslationKeys.memoryChampionsNoData),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(
    UserMemoryStats userStats,
    List<MemoryChampionEntry> entries,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(kMemoryGutter, 0, kMemoryGutter, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _YourRankCard(userStats: userStats),
          );
        }
        return _ChampionRow(entry: entries[index - 1]);
      },
    );
  }
}

/// Gold card with the user's rank, mastered verses and longest streak.
class _YourRankCard extends StatelessWidget {
  final UserMemoryStats userStats;

  const _YourRankCard({required this.userStats});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = palette.onSelected;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: palette.selectedFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context
                      .tr(TranslationKeys.memoryScreensYourRank)
                      .toUpperCase(),
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: palette.onSelectedMuted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    userStats.rank > 0 ? '#${userStats.rank}' : '—',
                    style: AppFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      fontFeatures: kMemoryTabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _RankStat(
            value: '${userStats.masterVerses}',
            label: context.tr(TranslationKeys.memoryScreensStatMastered),
          ),
          const SizedBox(width: 18),
          _RankStat(
            value: '${userStats.longestStreak}',
            label: context.tr(TranslationKeys.memoryScreensStatDayStreak),
          ),
        ],
      ),
    );
  }
}

class _RankStat extends StatelessWidget {
  final String value;
  final String label;

  const _RankStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = palette.onSelected;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
              fontFeatures: kMemoryTabular,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 12,
              color: palette.onSelectedMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A leaderboard line: medal (top 3) or rank number, name, gold
/// "N mastered" and the longest streak, plus a marker for ranks 4-10.
/// The current user's row is tinted.
class _ChampionRow extends StatelessWidget {
  final MemoryChampionEntry entry;

  const _ChampionRow({required this.entry});

  static const _silver = Color(0xFFB8BCC6);
  static const _bronze = Color(0xFFD08A4A);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final medal = switch (entry.rank) {
      1 => palette.gold,
      2 => palette.isDark ? _silver : const Color(0xFF7C818C),
      3 => palette.isDark ? _bronze : const Color(0xFFA0602A),
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? palette.selectedFill
                .withValues(alpha: palette.isDark ? 0.14 : 0.06)
            : null,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Semantics(
                    label: '#${entry.rank}',
                    child: Icon(Icons.workspace_premium_outlined,
                        size: 24, color: medal),
                  )
                : Text(
                    '${entry.rank}',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.muted,
                      fontFeatures: kMemoryTabular,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User names may ellipsize; the stats below never do.
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        entry.isCurrentUser ? palette.accentIcon : palette.text,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      context.tr(TranslationKeys.memoryScreensMasteredCount,
                          {'count': entry.masterVerses.toString()}),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.gold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_outlined,
                            size: 14, color: palette.muted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            context.tr(TranslationKeys.heatMapDayStreak,
                                {'count': entry.longestStreak.toString()}),
                            style: AppFonts.inter(
                              fontSize: 13,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Top-ten marker (the top three already carry medals).
          if (entry.rank > 3 && entry.rank <= 10) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: context.tr(TranslationKeys.memoryScreensTopTen),
              child: Icon(Icons.military_tech_outlined,
                  size: 22, color: palette.accentIcon),
            ),
          ],
        ],
      ),
    );
  }
}
