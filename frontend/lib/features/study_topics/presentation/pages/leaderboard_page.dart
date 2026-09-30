import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/leaderboard_entry.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/leaderboard_parts.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';

/// XP leaderboard: podium for the top three, the ranked list below it and
/// the current user's rank pinned to the bottom.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<LeaderboardBloc>().add(const LoadLeaderboard());
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.studyTopics);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.studyTopics);
        }
      },
      child: Scaffold(
        backgroundColor: ReaderPalette.of(context).page,
        body: PhotoWash.forKey(
          photoKey: 'leaderboard',
          height: 520,
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<LeaderboardBloc, LeaderboardState>(
              builder: (context, state) {
                if (state is LeaderboardError) {
                  return _buildErrorState(context);
                }
                if (state is LeaderboardLoaded) {
                  return _buildContent(context, state.entries, state.userRank);
                }
                return _buildLoadingState(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      children: [
        LeaderboardTitleBar(onBack: _goBack),
        Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: ReaderPalette.of(context).gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ReaderPalette.of(context);
    return Column(
      children: [
        LeaderboardTitleBar(onBack: _goBack),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(TranslationKeys.leaderboardError),
                    style: AppFonts.inter(fontSize: 16, color: palette.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context
                        .read<LeaderboardBloc>()
                        .add(const RefreshLeaderboard()),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.ctaFill,
                      foregroundColor: palette.ctaInk,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr(TranslationKeys.commonRetry)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LeaderboardEntry> entries,
    UserXpRank userRank,
  ) {
    final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: ReaderPalette.of(context).gold,
            onRefresh: () async =>
                context.read<LeaderboardBloc>().add(const RefreshLeaderboard()),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: LeaderboardTitleBar(onBack: _goBack),
                ),
                SliverToBoxAdapter(child: LeaderboardPodium(entries: entries)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => LeaderboardRow(entry: rest[index]),
                    childCount: rest.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          ),
        ),
        LeaderboardUserRankBar(
          userRank: userRank,
          gapAbove: leaderboardGapAbove(entries, userRank),
        ),
      ],
    );
  }
}
