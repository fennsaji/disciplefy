import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// Dialog displaying the XP leaderboard with top 10 users.
///
/// Shows real users with 200+ XP, fills remaining spots with placeholder data.
/// Always displays current user's rank at the bottom.
class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({super.key});

  /// Shows the leaderboard dialog.
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const LeaderboardDialog(),
    );
  }

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  late Future<({List<LeaderboardEntry> entries, UserXpRank userRank})> _future;
  final _dataSource = LeaderboardRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _future = _dataSource.getLeaderboardWithUserRank();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
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
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<
            ({List<LeaderboardEntry> entries, UserXpRank userRank})>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(TranslationKeys.leaderboardError),
                        style: AppFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            return _buildContent(context, data.entries, data.userRank);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr(TranslationKeys.leaderboardClose)),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LeaderboardEntry> entries,
    UserXpRank userRank,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Leaderboard list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildLeaderboardRow(context, entries[index]);
            },
          ),
        ),
        const Divider(height: 24),
        // Current user rank section
        _buildUserRankSection(context, userRank),
      ],
    );
  }

  Widget _buildLeaderboardRow(BuildContext context, LeaderboardEntry entry) {
    final theme = Theme.of(context);
    final isTopThree = entry.rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppTheme.primaryColor.withOpacity(0.1)
            : entry.isPlaceholder
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: entry.isCurrentUser
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 36,
            child: _buildRankBadge(context, entry.rank, isTopThree),
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
                color: entry.isPlaceholder
                    ? theme.colorScheme.onSurfaceVariant.withOpacity(0.7)
                    : theme.colorScheme.onSurface,
                fontStyle:
                    entry.isPlaceholder ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: entry.isPlaceholder
                  ? Colors.grey.withOpacity(0.2)
                  : AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.totalXp} XP',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    entry.isPlaceholder ? Colors.grey : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank, bool isTopThree) {
    if (isTopThree) {
      return _buildMedalIcon(rank);
    }

    final theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMedalIcon(int rank) {
    const IconData icon = Icons.emoji_events;
    Color color;

    switch (rank) {
      case 1:
        color = const Color(0xFFFFD700); // Gold
        break;
      case 2:
        color = const Color(0xFFC0C0C0); // Silver
        break;
      case 3:
        color = const Color(0xFFCD7F32); // Bronze
        break;
      default:
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildUserRankSection(BuildContext context, UserXpRank userRank) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(TranslationKeys.leaderboardYourRank),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          // Rank display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userRank.isRanked ? '#${userRank.rank}' : '-',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${userRank.totalXp} XP',
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
