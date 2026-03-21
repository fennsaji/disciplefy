import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../bloc/leaderboard_bloc.dart';
import '../bloc/leaderboard_event.dart';
import '../bloc/leaderboard_state.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          if (state is LeaderboardInitial || state is LeaderboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LeaderboardError) {
            return _buildErrorState(context, state.message);
          }
          if (state is LeaderboardLoaded) {
            return _buildContent(
                context, state.entries, state.userRank, isDark);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 64),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.leaderboardError),
              style: AppFonts.inter(
                  fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context
                  .read<LeaderboardBloc>()
                  .add(const RefreshLeaderboard()),
              icon: const Icon(Icons.refresh),
              label: Text(context.tr(TranslationKeys.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LeaderboardEntry> entries,
    UserXpRank userRank,
    bool isDark,
  ) {
    return Column(
      children: [
        _buildHeader(context, entries, isDark),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: entries.length > 3 ? entries.length - 3 : 0,
            itemBuilder: (context, index) =>
                _buildLeaderboardRow(context, entries[index + 3], isDark),
          ),
        ),
        _buildUserRankSection(context, userRank, isDark),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, List<LeaderboardEntry> entries, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1040), const Color(0xFF0F1729)]
              : [const Color(0xFF4F46E5).withOpacity(0.08), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.studyTopics);
                      }
                    },
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(TranslationKeys.leaderboardTitle),
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildPodiumSection(context, entries, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumSection(
      BuildContext context, List<LeaderboardEntry> entries, bool isDark) {
    if (entries.isEmpty) return const SizedBox(height: 20);

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFB0BEC5);
    const bronzeColor = Color(0xFFCD8B5A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(
            child: second != null
                ? _buildPodiumItem(context, second, 2, silverColor, 88, isDark)
                : const SizedBox(),
          ),
          const SizedBox(width: 6),
          // 1st place
          Expanded(
            child: first != null
                ? _buildPodiumItem(context, first, 1, goldColor, 120, isDark)
                : const SizedBox(),
          ),
          const SizedBox(width: 6),
          // 3rd place
          Expanded(
            child: third != null
                ? _buildPodiumItem(context, third, 3, bronzeColor, 68, isDark)
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
    BuildContext context,
    LeaderboardEntry entry,
    int rank,
    Color color,
    double platformHeight,
    bool isDark,
  ) {
    final avatarRadius = rank == 1 ? 34.0 : 27.0;
    final fontSize = rank == 1 ? 26.0 : 20.0;
    final lightIndigo =
        isDark ? const Color(0xFFA5B4FC) : AppTheme.primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (rank == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('👑', style: TextStyle(fontSize: rank == 1 ? 22 : 0)),
          )
        else
          const SizedBox(height: 26),

        // Avatar with glow for 1st
        Container(
          decoration: rank == 1
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 16,
                        spreadRadius: 2),
                  ],
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: color.withOpacity(isDark ? 0.22 : 0.15),
                child: Text(
                  entry.displayName.isNotEmpty
                      ? entry.displayName[0].toUpperCase()
                      : '?',
                  style: AppFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: lightIndigo,
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F1729) : Colors.white,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: AppFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: rank == 1 ? const Color(0xFF7A5C00) : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Name
        Text(
          entry.displayName,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 6),

        // Podium platform
        Container(
          height: platformHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.7), color.withOpacity(0.4)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entry.totalXp} XP',
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(
      BuildContext context, LeaderboardEntry entry, bool isDark) {
    final theme = Theme.of(context);
    final lightIndigo =
        isDark ? const Color(0xFFA5B4FC) : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark
                ? const Color(0xFF1E293B)
                : theme.colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(14),
        border: entry.isCurrentUser
            ? Border.all(
                color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 17,
            backgroundColor:
                AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.12),
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: lightIndigo,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              entry.displayName,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight:
                    entry.isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: lightIndigo.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entry.totalXp} XP',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: lightIndigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankSection(
      BuildContext context, UserXpRank userRank, bool isDark) {
    final theme = Theme.of(context);
    final lightIndigo =
        isDark ? const Color(0xFFA5B4FC) : AppTheme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppTheme.primaryColor.withOpacity(isDark ? 0.25 : 0.15),
                child: Icon(Icons.person_rounded, color: lightIndigo, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.leaderboardYourRank),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userRank.isRanked ? '#${userRank.rank}' : '–',
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 1,
                      height: 14,
                      color: Colors.white.withOpacity(0.35),
                    ),
                    Text(
                      '${userRank.totalXp} XP',
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
