import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// Full-screen leaderboard page showing XP rankings.
///
/// Displays top 10 users with 200+ XP, fills remaining spots with placeholder data.
/// Always shows current user's rank at the bottom.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<({List<LeaderboardEntry> entries, UserXpRank userRank})> _future;
  final _dataSource = LeaderboardRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _future = _dataSource.getLeaderboardWithUserRank();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.studyTopics),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              context.tr(TranslationKeys.leaderboardTitle),
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<
          ({List<LeaderboardEntry> entries, UserXpRank userRank})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(context);
          }

          final data = snapshot.data!;
          return _buildContent(context, data.entries, data.userRank);
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.leaderboardError),
              style: AppFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loadData();
                });
              },
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
  ) {
    return Column(
      children: [
        // Top 3 podium section
        _buildPodiumSection(context, entries),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),

        // Remaining rankings list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: entries.length > 3 ? entries.length - 3 : 0,
            itemBuilder: (context, index) {
              return _buildLeaderboardRow(context, entries[index + 3]);
            },
          ),
        ),

        // Current user rank section (sticky at bottom)
        _buildUserRankSection(context, userRank),
      ],
    );
  }

  Widget _buildPodiumSection(
      BuildContext context, List<LeaderboardEntry> entries) {
    if (entries.isEmpty) return const SizedBox(height: 20);

    final theme = Theme.of(context);

    // Get top 3 entries (or fewer if not enough)
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place (left)
          if (second != null)
            Expanded(
              child: _buildPodiumCard(
                context,
                entry: second,
                height: 100,
                medalColor: const Color(0xFFC0C0C0), // Silver
                rank: 2,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // 1st place (center, tallest)
          if (first != null)
            Expanded(
              child: _buildPodiumCard(
                context,
                entry: first,
                height: 130,
                medalColor: const Color(0xFFFFD700), // Gold
                rank: 1,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // 3rd place (right)
          if (third != null)
            Expanded(
              child: _buildPodiumCard(
                context,
                entry: third,
                height: 80,
                medalColor: const Color(0xFFCD7F32), // Bronze
                rank: 3,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    BuildContext context, {
    required LeaderboardEntry entry,
    required double height,
    required Color medalColor,
    required int rank,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (rank == 1)
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFFFFD700),
            size: 24,
          ),

        const SizedBox(height: 4),

        // Avatar with medal
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 36 : 30,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              child: Text(
                entry.displayName.isNotEmpty
                    ? entry.displayName[0].toUpperCase()
                    : '?',
                style: AppFonts.poppins(
                  fontSize: rank == 1 ? 28 : 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$rank',
                style: AppFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Name
        Text(
          entry.displayName,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // XP
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: medalColor.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${entry.totalXp} XP',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(BuildContext context, LeaderboardEntry entry) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppTheme.primaryColor.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${entry.rank}',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              entry.displayName,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight:
                    entry.isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${entry.totalXp} XP',
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankSection(BuildContext context, UserXpRank userRank) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // User icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Label
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.leaderboardYourRank),
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              // Rank and XP display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userRank.isRanked ? '#${userRank.rank}' : '-',
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 1,
                      height: 16,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    Text(
                      '${userRank.totalXp} XP',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
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
