import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../domain/entities/memory_champion_entry.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';

/// Memory Champions Leaderboard Page.
///
/// Displays rankings based on:
/// - Primary: Total verses at Master level
/// - Tiebreaker 1: Longest practice streak
/// - Tiebreaker 2: Total practice days
///
/// Features:
/// - Top 100 users shown
/// - User's rank always visible (even if not top 100)
/// - Weekly/Monthly/All-time tabs
/// - Profile badges for top 10
/// - Achievement badges displayed
class MemoryChampionsPage extends StatefulWidget {
  const MemoryChampionsPage({super.key});

  @override
  State<MemoryChampionsPage> createState() => _MemoryChampionsPageState();
}

class _MemoryChampionsPageState extends State<MemoryChampionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MemoryVerseBloc _bloc;

  String get _currentPeriod {
    switch (_tabController.index) {
      case 0:
        return 'weekly';
      case 1:
        return 'monthly';
      case 2:
        return 'all_time';
      default:
        return 'all_time';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bloc = sl<MemoryVerseBloc>();

    // Load initial leaderboard (all-time by default)
    _bloc.add(const LoadMemoryChampionsLeaderboardEvent(period: 'all_time'));

    // Listen for tab changes and reload leaderboard
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _bloc.add(LoadMemoryChampionsLeaderboardEvent(period: _currentPeriod));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            title: Text(context.tr(TranslationKeys.memoryChampions)),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: context.tr(TranslationKeys.weekly)),
                Tab(text: context.tr(TranslationKeys.monthly)),
                Tab(text: context.tr(TranslationKeys.allTime)),
              ],
            ),
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
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load leaderboard',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () {
                          _bloc.add(
                            LoadMemoryChampionsLeaderboardEvent(
                              period: _currentPeriod,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }

              if (state is MemoryChampionsLeaderboardLoaded) {
                return Column(
                  children: [
                    // User's current rank card
                    _buildUserRankCard(state.userStats),

                    // Leaderboard
                    Expanded(
                      child: _buildLeaderboard(state.leaderboard),
                    ),
                  ],
                );
              }

              // Default empty state
              return const Center(
                child: Text('No leaderboard data available'),
              );
            },
          ),
        ).withAuthProtection(),
      ),
    );
  }

  Widget _buildUserRankCard(UserMemoryStats userStats) {
    final userRank = userStats.rank;
    final userMasterVerses = userStats.masterVerses;
    final userStreak = userStats.longestStreak;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple,
            AppColors.primaryPurple.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$userRank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr(TranslationKeys.memoryChampionsRank),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.memoryChampionsYourProgress),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatBadge(
                      icon: Icons.emoji_events,
                      label: context.tr(TranslationKeys.memoryChampionsMaster),
                      value: '$userMasterVerses',
                    ),
                    const SizedBox(width: 12),
                    _buildStatBadge(
                      icon: Icons.local_fire_department,
                      label: context.tr(TranslationKeys.memoryChampionsStreak),
                      value: '$userStreak',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<MemoryChampionEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildLeaderboardCard(entry);
      },
    );
  }

  Widget _buildLeaderboardCard(MemoryChampionEntry entry) {
    final isCurrentUser = entry.isCurrentUser;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrentUser ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentUser
            ? BorderSide(color: AppColors.primaryPurple, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank with medal for top 3
            _buildRankBadge(entry.rank),
            const SizedBox(width: 16),

            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
              child: Text(
                entry.displayName[0].toUpperCase(),
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCurrentUser ? AppColors.primaryPurple : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.masterVerses} Master',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.longestStreak} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trophy icon for top 10
            if (entry.rank <= 10)
              Icon(
                Icons.military_tech,
                color: _getTrophyColor(entry.rank),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getMedalGradient(rank),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getMedalGradient(rank)[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _getMedalIcon(rank),
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    } else {
      return SizedBox(
        width: 40,
        child: Text(
          '#$rank',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      );
    }
  }

  List<Color> _getMedalGradient(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF808080)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [Colors.grey, Colors.grey];
    }
  }

  IconData _getMedalIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.looks_one;
      case 2:
        return Icons.looks_two;
      case 3:
        return Icons.looks_3;
      default:
        return Icons.star;
    }
  }

  Color _getTrophyColor(int rank) {
    if (rank <= 3) {
      return const Color(0xFFFFD700); // Gold
    } else if (rank <= 10) {
      return AppColors.primaryPurple;
    }
    return Colors.grey;
  }
}
