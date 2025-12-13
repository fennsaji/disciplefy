import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../domain/entities/achievement.dart';
import '../bloc/gamification_bloc.dart';
import '../bloc/gamification_event.dart';
import '../bloc/gamification_state.dart';
import '../widgets/xp_progress_bar.dart';
import '../widgets/streak_display.dart';
import '../widgets/achievements_grid.dart';
import '../widgets/achievement_unlock_dialog.dart';

/// Stats Dashboard page showing comprehensive gamification data
///
/// Displays:
/// - User profile with level and XP progress
/// - Study and verse streaks
/// - Statistics (studies, time, rank)
/// - Achievement badges with progress
class StatsDashboardPage extends StatefulWidget {
  const StatsDashboardPage({super.key});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load stats when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationBloc>().add(const LoadGamificationStats());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
        ),
        title: Text(
          'My Progress',
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              // Refresh stats
              context
                  .read<GamificationBloc>()
                  .add(const LoadGamificationStats(forceRefresh: true));
            },
            icon: Icon(
              Icons.refresh,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
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
              child: CircularProgressIndicator(),
            );
          }

          if (state.status == GamificationStatus.error && state.stats == null) {
            return _buildErrorState(context, state.errorMessage);
          }

          // Build content with available data
          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<GamificationBloc>()
                  .add(const LoadGamificationStats(forceRefresh: true));
              // Wait a bit for the state to update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header with level
                  _buildProfileHeader(context, state),
                  const SizedBox(height: 24),

                  // XP Progress bar
                  if (state.level != null) ...[
                    XpProgressBar(level: state.level!),
                    const SizedBox(height: 24),
                  ],

                  // Streaks section
                  if (state.stats != null) ...[
                    StreakDisplay(
                      studyStreak: state.stats!.studyCurrentStreak,
                      verseStreak: state.stats!.verseCurrentStreak,
                      longestStreak: state.stats!.studyLongestStreak,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Statistics section
                  if (state.stats != null) ...[
                    _buildStatisticsSection(context, state),
                    const SizedBox(height: 24),
                  ],

                  // Achievements section
                  if (state.achievements.isNotEmpty) ...[
                    AchievementsGrid(
                      achievements: state.achievements,
                      progressMap: _buildProgressMap(state),
                      showAllAchievements: true,
                      onAchievementTap: (achievement) {
                        _showAchievementDetails(context, achievement);
                      },
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, GamificationState state) {
    final theme = Theme.of(context);
    final authProvider = sl<AuthStateProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Profile avatar with level badge
          Stack(
            children: [
              _buildProfileAvatar(context, authProvider),
              if (state.level != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${state.level!.level}',
                        style: AppFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Name and level title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.profileBasedDisplayName,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (state.level != null)
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.level!.title,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                if (state.stats != null)
                  Text(
                    '${state.stats!.totalXp} XP total',
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          // Leaderboard rank badge
          if (state.stats?.isOnLeaderboard == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${state.stats!.leaderboardRank}',
                    style: AppFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(
      BuildContext context, AuthStateProvider authProvider) {
    final theme = Theme.of(context);
    final profilePictureUrl = authProvider.profilePictureUrl;

    // Show network image if available and user is not anonymous
    if (profilePictureUrl != null && !authProvider.isAnonymous) {
      return CircleAvatar(
        radius: 35,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: ClipOval(
          child: Image.network(
            profilePictureUrl,
            width: 70,
            height: 70,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                size: 35,
                color: theme.colorScheme.primary,
              );
            },
          ),
        ),
      );
    }

    // Fallback to icon
    return CircleAvatar(
      radius: 35,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      child: Icon(
        authProvider.isAnonymous ? Icons.person_outline : Icons.person,
        size: 35,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildStatisticsSection(
      BuildContext context, GamificationState state) {
    final theme = Theme.of(context);
    final stats = state.stats!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.menu_book,
                  iconColor: AppTheme.primaryColor,
                  label: 'Studies',
                  value: '${stats.totalStudiesCompleted}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.access_time,
                  iconColor: Colors.blue,
                  label: 'Time Spent',
                  value: stats.formattedTimeSpent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.psychology,
                  iconColor: Colors.purple,
                  label: 'Memory Verses',
                  value: '${stats.totalMemoryVerses}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.mic,
                  iconColor: Colors.teal,
                  label: 'Voice Sessions',
                  value: '${stats.totalVoiceSessions}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bookmark,
                  iconColor: Colors.orange,
                  label: 'Saved Guides',
                  value: '${stats.totalSavedGuides}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today,
                  iconColor: Colors.green,
                  label: 'Study Days',
                  value: '${stats.totalStudyDays}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? errorMessage) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load stats',
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Please try again later',
              style: AppFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context
                    .read<GamificationBloc>()
                    .add(const LoadGamificationStats());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<AchievementCategory, int> _buildProgressMap(GamificationState state) {
    if (state.stats == null) return {};

    final stats = state.stats!;
    return {
      AchievementCategory.study: stats.totalStudiesCompleted,
      AchievementCategory.streak: stats.studyCurrentStreak,
      AchievementCategory.memory: stats.totalMemoryVerses,
      AchievementCategory.voice: stats.totalVoiceSessions,
      AchievementCategory.saved: stats.totalSavedGuides,
    };
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

  void _showAchievementDetails(BuildContext context, Achievement achievement) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.colorScheme.onSurface.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: TextStyle(
                    fontSize: 40,
                    color: achievement.isUnlocked ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              achievement.name,
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: achievement.isUnlocked
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              achievement.description,
              style: AppFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // XP Reward
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '+${achievement.xpReward} XP',
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Status
            if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
              Text(
                'Unlocked on ${_formatDate(achievement.unlockedAt!)}',
                style: AppFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ] else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Locked',
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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

/// Card widget for displaying individual statistics
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
