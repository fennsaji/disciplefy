import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/di/injection_container.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';
import '../../../subscription/presentation/widgets/upgrade_required_dialog.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../notifications/presentation/widgets/notification_enable_prompt.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/memory_streak_entity.dart';
import '../../domain/entities/daily_goal_entity.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/add_manual_verse_dialog.dart';
import '../widgets/add_verse_options_sheet.dart';
import '../widgets/suggested_verses_sheet.dart';
import '../widgets/memory_verse_list_item.dart';
import '../widgets/options_menu_sheet.dart';
import '../widgets/statistics_card.dart';
import '../widgets/streak_display_widget.dart';
import '../widgets/daily_goal_progress_widget.dart';
import '../widgets/milestone_celebration_dialog.dart';
import '../widgets/streak_protection_dialog.dart';
import '../widgets/memory_verse_navigation_bar.dart';
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';

class MemoryVersesHomePage extends StatefulWidget {
  const MemoryVersesHomePage({super.key});

  @override
  State<MemoryVersesHomePage> createState() => _MemoryVersesHomePageState();
}

class _MemoryVersesHomePageState extends State<MemoryVersesHomePage> {
  DueVersesLoaded? _lastLoadedState;
  VerseLanguage? _selectedLanguageFilter;
  bool _hasTriggeredMemoryVersePrompt = false;
  bool _isAccessDenied = false;
  StreamSubscription<TokenState>? _tokenSubscription;
  MemoryStreakEntity? _memoryStreak;
  DailyGoalEntity? _dailyGoal;

  @override
  void initState() {
    super.initState();
    _checkPlanAccess();
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  /// Checks if user has access to Memory Verses (Standard+ only)
  void _checkPlanAccess() {
    // Use the singleton TokenBloc instance which is shared across the app
    // This ensures we get the token status that was fetched on auth
    final tokenBloc = sl<TokenBloc>();
    final currentState = tokenBloc.state;

    // If already loaded, verify access immediately
    if (currentState is TokenLoaded || currentState is TokenError) {
      _verifyAccess(currentState);
      return;
    }

    // Subscribe to stream and wait for TokenLoaded or TokenError
    _tokenSubscription = tokenBloc.stream
        .where((state) => state is TokenLoaded || state is TokenError)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) => sink.add(currentState),
        )
        .first
        .asStream()
        .listen((state) {
      if (mounted) {
        _verifyAccess(state);
      }
    });
  }

  /// Verifies if user has access based on token state
  void _verifyAccess(TokenState tokenState) {
    UserPlan? userPlan;
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan;
    }

    // Block free users - Memory Verses requires Standard or Premium
    final bool hasAccess =
        userPlan == UserPlan.standard || userPlan == UserPlan.premium;

    if (!hasAccess) {
      setState(() => _isAccessDenied = true);
      // Show upgrade dialog and redirect after dismissal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        UpgradeRequiredDialog.show(
          context,
          featureName: context.tr(TranslationKeys.memoryHomeTitle),
          featureIcon: Icons.psychology_outlined,
          featureDescription:
              context.tr(TranslationKeys.memoryHomeFeatureDescription),
        ).then((_) {
          // Navigate back after dialog is dismissed
          if (mounted) {
            GoRouter.of(context).goToHome();
          }
        });
      });
      return;
    }

    // User has access - load verses
    _loadVerses();
  }

  void _loadVerses({bool forceRefresh = false}) {
    context.read<MemoryVerseBloc>().add(LoadDueVerses(
          language: _selectedLanguageFilter?.code,
          forceRefresh: forceRefresh,
        ));
    // Load gamification data
    context.read<MemoryVerseBloc>().add(const LoadMemoryStreakEvent());
    context.read<MemoryVerseBloc>().add(const LoadDailyGoalEvent());
  }

  /// Shows the memory verse reminder notification prompt (once per session)
  Future<void> _showMemoryVerseReminderPrompt() async {
    if (_hasTriggeredMemoryVersePrompt) return;
    _hasTriggeredMemoryVersePrompt = true;

    // Small delay to let the snackbar show first
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final languageCode = context.translationService.currentLanguage.code;
    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.memoryVerseReminder,
      languageCode: languageCode,
    );
  }

  /// Handle back navigation - go to home when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      GoRouter.of(context).goToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show empty scaffold while redirecting free users
    if (_isAccessDenied) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.shrink(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            onPressed: _handleBackNavigation,
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
            context.tr(TranslationKeys.memoryTitle),
            style: AppFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () => _showAddVerseOptions(context),
                tooltip: context.tr(TranslationKeys.memoryHomeAddVerse),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              onPressed: () => _showOptionsMenu(context),
              tooltip: context.tr(TranslationKeys.memoryHomeOptions),
            ),
          ],
        ),
        body: BlocConsumer<MemoryVerseBloc, MemoryVerseState>(
          listener: (context, state) {
            // Handle streak data loaded
            if (state is MemoryStreakLoaded) {
              setState(() {
                _memoryStreak = MemoryStreakEntity(
                  currentStreak: state.currentStreak,
                  longestStreak: state.longestStreak,
                  lastPracticeDate: state.lastPracticeDate,
                  totalPracticeDays: state.totalPracticeDays,
                  freezeDaysAvailable: state.freezeDaysAvailable,
                  freezeDaysUsed: state.freezeDaysUsed,
                  milestones: state.milestones,
                );
              });
            }
            // Handle daily goal data loaded
            else if (state is DailyGoalLoaded) {
              setState(() {
                _dailyGoal = DailyGoalEntity(
                  targetReviews: state.targetReviews,
                  completedReviews: state.completedReviews,
                  targetNewVerses: state.targetNewVerses,
                  addedNewVerses: state.addedNewVerses,
                  goalAchieved: state.goalAchieved,
                  bonusXpAwarded: state.bonusXpAwarded,
                );
              });
            }
            // Handle milestone reached
            else if (state is StreakMilestoneReached) {
              // Show celebration dialog
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  MilestoneCelebrationDialog.show(
                    context,
                    milestoneDays: state.milestone,
                    xpEarned: state.xpEarned,
                  );
                }
              });
              // Reload streak to show updated milestone
              context
                  .read<MemoryVerseBloc>()
                  .add(const LoadMemoryStreakEvent());
            }
            // Handle streak freeze used
            else if (state is StreakFreezeUsed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.blue,
                ),
              );
              // Reload streak to show updated freeze days
              context
                  .read<MemoryVerseBloc>()
                  .add(const LoadMemoryStreakEvent());
            } else if (state is MemoryVerseError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: context.tr(TranslationKeys.commonRetry),
                    textColor: Colors.white,
                    onPressed: _loadVerses,
                  ),
                ),
              );
            } else if (state is VerseAdded) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVerses();
              // Check memory achievements when verse is added
              sl<GamificationBloc>().add(const CheckMemoryAchievements());
              // Show notification prompt for memory verse reminder after adding first verse
              _showMemoryVerseReminderPrompt();
            } else if (state is OperationQueued) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            } else if (state is VerseDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(context.tr(TranslationKeys.memoryDeleteSuccess)),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVerses();
            }
          },
          builder: (context, state) {
            if (state is DueVersesLoaded) {
              _lastLoadedState = state;
            }
            if (state is MemoryVerseInitial) {
              return _buildLoadingState();
            }
            if (state is MemoryVerseLoading && !state.isRefreshing) {
              return _buildLoadingState();
            }
            if (state is MemoryVerseLoading && state.isRefreshing) {
              if (_lastLoadedState != null) {
                return _buildLoadedState(_lastLoadedState!);
              }
              return _buildLoadingState();
            }
            if (state is DueVersesLoaded) {
              return _buildLoadedState(state);
            }
            // Preserve loaded verses during transient states (errors, fetch operations, etc.)
            // This handles: MemoryVerseError, FetchingVerseText, VerseTextFetched,
            // FetchVerseTextError, and any other states from modal operations
            if (_lastLoadedState != null) {
              return _buildLoadedState(_lastLoadedState!);
            }
            return _buildEmptyState();
          },
        ),
      ),
    ).withAuthProtection();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.tr(TranslationKeys.memoryHomeLoading)),
        ],
      ),
    );
  }

  Widget _buildLoadedState(DueVersesLoaded state) {
    // Show full empty state only when user has no verses at all
    if (state.statistics.totalVerses == 0) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        _loadVerses(forceRefresh: true);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact streak + Daily goal + action buttons
                  _buildCompactProgressSection(state),
                  const SizedBox(height: 24),
                  _buildLanguageFilter(context),
                  const SizedBox(height: 16),
                  Text(
                    '${context.tr(TranslationKeys.memoryDueForReview)} (${state.verses.length})',
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  if (state.statistics.dueVerses > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getVersesToReviewMessage(
                          context, state.statistics.dueVerses),
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Show verses list or empty filter message
          if (state.verses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final verse = state.verses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: MemoryVerseListItem(
                        verse: verse,
                        onTap: () => _navigateToReviewPage(context, verse.id),
                        onDelete: () => _showDeleteConfirmation(context, verse),
                      ),
                    );
                  },
                  childCount: state.verses.length,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: _buildFilteredEmptyMessage(),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  /// Build message when filter returns no results but user has verses
  Widget _buildFilteredEmptyMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.memoryNoVersesInLanguage),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.memoryTryDifferentFilter),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a compact progress section combining streak, daily goal, and action buttons
  Widget _buildCompactProgressSection(DueVersesLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row with streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Streak badge
              if (_memoryStreak != null)
                GestureDetector(
                  onTap: () {
                    if (!_memoryStreak!.isPracticedToday &&
                        _memoryStreak!.canUseFreeze) {
                      StreakProtectionDialog.show(
                        context,
                        freezeDaysAvailable: _memoryStreak!.freezeDaysAvailable,
                        currentStreak: _memoryStreak!.currentStreak,
                        onConfirm: () {
                          context.read<MemoryVerseBloc>().add(
                                UseStreakFreezeEvent(
                                    freezeDate: DateTime.now()),
                              );
                        },
                      );
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_memoryStreak!.currentStreak} ${_memoryStreak!.currentStreak != 1 ? context.tr(TranslationKeys.memoryHomeStreakDays) : context.tr(TranslationKeys.memoryHomeStreakDay)}',
                          style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              // Quick stats
              Row(
                children: [
                  _buildMiniStat(
                    Icons.library_books_outlined,
                    '${state.statistics.totalVerses}',
                    context.tr(TranslationKeys.memoryHomeTotal),
                  ),
                  const SizedBox(width: 16),
                  _buildMiniStat(
                    Icons.star_outline,
                    '${state.statistics.masteredVerses}',
                    context.tr(TranslationKeys.memoryHomeMastered),
                    color: Colors.amber,
                  ),
                ],
              ),
            ],
          ),
          // Daily goal progress - Reviews only (simpler)
          if (_dailyGoal != null) ...[
            const SizedBox(height: 16),
            _buildGoalProgress(
              context.tr(TranslationKeys.memoryHomeDailyReviews),
              _dailyGoal!.completedReviews,
              _dailyGoal!.targetReviews,
              AppTheme.primaryColor,
            ),
          ],
          // Action buttons row
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.emoji_events_outlined,
                  label: context.tr(TranslationKeys.memoryHomeChampions),
                  onTap: () => context.push('/memory-verses/champions'),
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.bar_chart_outlined,
                  label: context.tr(TranslationKeys.memoryHomeStatistics),
                  onTap: () => context.push('/memory-verses/stats'),
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon,
            size: 18,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: AppFonts.inter(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalProgress(
      String label, int current, int target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = current >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                if (isComplete)
                  Icon(Icons.check_circle,
                      size: 14, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text(
                  '$current/$target',
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.green.shade400 : color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(
                isComplete ? Colors.green.shade400 : color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.secondaryPurple.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(TranslationKeys.memoryHomeNoVersesTitle),
              style: AppFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.memoryHomeNoVersesSubtitle),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAddVerseOptions(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr(TranslationKeys.memoryHomeAddFirstVerse),
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVerseOptions(BuildContext context) {
    AddVerseOptionsSheet.show(
      context,
      onAddFromDaily: () => _showAddFromDailyDialog(context),
      onAddSuggested: () => _showSuggestedVersesSheet(context),
      onAddManually: () => _showAddManuallyDialog(context),
    );
  }

  void _showSuggestedVersesSheet(BuildContext context) {
    // Get language: use filter if selected, otherwise use user's preferred language
    String language;
    if (_selectedLanguageFilter != null) {
      language = _selectedLanguageFilter!.code;
    } else {
      // Get user's preferred language from TranslationService
      language = context.translationService.currentLanguage.code;
    }

    SuggestedVersesSheet.show(
      context,
      language: language,
      onVerseAdded: () {
        // Reload verses list to show the newly added verse
        context.read<MemoryVerseBloc>().add(
              LoadDueVerses(
                forceRefresh: true,
                language: _selectedLanguageFilter?.code,
              ),
            );
      },
    );
  }

  void _showAddFromDailyDialog(BuildContext context) {
    // Get the current daily verse from DailyVerseBloc
    final dailyVerseState = context.read<DailyVerseBloc>().state;

    // Check if daily verse is loaded
    if (dailyVerseState is DailyVerseLoaded) {
      final verse = dailyVerseState.verse;
      final currentLanguage = dailyVerseState.currentLanguage;

      // Add the daily verse to memory deck
      context.read<MemoryVerseBloc>().add(
            AddVerseFromDaily(
              verse.id,
              language: currentLanguage.code,
            ),
          );
    } else if (dailyVerseState is DailyVerseOffline) {
      final verse = dailyVerseState.verse;
      final currentLanguage = dailyVerseState.currentLanguage;

      // Add the daily verse to memory deck even in offline mode
      context.read<MemoryVerseBloc>().add(
            AddVerseFromDaily(
              verse.id,
              language: currentLanguage.code,
            ),
          );
    } else {
      // Daily verse not loaded yet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryDailyVerseNotLoaded)),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showAddManuallyDialog(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();

    // Get default language: use filter if selected, otherwise use user's preferred language
    VerseLanguage defaultLanguage;
    if (_selectedLanguageFilter != null) {
      defaultLanguage = _selectedLanguageFilter!;
    } else {
      // Get user's preferred language from TranslationService
      final userLanguageCode = context.translationService.currentLanguage.code;
      defaultLanguage = _getVerseLanguageFromCode(userLanguageCode);
    }

    AddManualVerseDialog.show(
      context,
      defaultLanguage: defaultLanguage,
      onSubmit: ({
        required String verseReference,
        required String verseText,
        required String language,
      }) {
        memoryVerseBloc.add(
          AddVerseManually(
            verseReference: verseReference,
            verseText: verseText,
            language: language,
          ),
        );
      },
    );
  }

  /// Convert language code to VerseLanguage enum
  VerseLanguage _getVerseLanguageFromCode(String code) {
    switch (code) {
      case 'hi':
        return VerseLanguage.hindi;
      case 'ml':
        return VerseLanguage.malayalam;
      case 'en':
      default:
        return VerseLanguage.english;
    }
  }

  Widget _buildLanguageFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.memoryFilterByLanguage),
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildLanguageChip(
                context,
                label: context.tr(TranslationKeys.memoryAll),
                isSelected: _selectedLanguageFilter == null,
                onTap: () {
                  setState(() => _selectedLanguageFilter = null);
                  _loadVerses();
                },
              ),
              const SizedBox(width: 8),
              ...VerseLanguage.values.map((language) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildLanguageChip(
                    context,
                    label: language.displayName,
                    isSelected: _selectedLanguageFilter == language,
                    onTap: () {
                      setState(() => _selectedLanguageFilter = language);
                      _loadVerses();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 14,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    OptionsMenuSheet.show(
      context,
      onSync: () => memoryVerseBloc
          .add(SyncWithRemote(language: _selectedLanguageFilter?.code)),
      onViewStatistics: () {
        // Navigate to the new comprehensive statistics page
        context.push('/memory-verses/stats');
      },
      onViewChampions: () {
        context.push('/memory-verses/champions');
      },
    );
  }

  void _navigateToReviewPage(BuildContext context, String verseId) {
    // Navigate to practice mode selection to let user choose their preferred mode
    context.push('/memory-verses/practice/$verseId');
  }

  void _startReviewAll(BuildContext context, List<MemoryVerseEntity> verses) {
    if (verses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryNoVersesToReview)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get all verse IDs for sequential review
    final verseIds = verses.map((v) => v.id).toList();

    // Navigate to review page with batch mode
    GoRouter.of(context).goToVerseReview(
      verseId: verseIds.first,
      verseIds: verseIds,
    );
  }

  void _showDeleteConfirmation(BuildContext context, MemoryVerseEntity verse) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(TranslationKeys.memoryDeleteTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse.verseReference,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            Text(context.tr(TranslationKeys.memoryDeleteConfirmation)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr(TranslationKeys.memoryDeleteCancel)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MemoryVerseBloc>().add(DeleteVerse(verse.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr(TranslationKeys.memoryDeleteConfirm)),
          ),
        ],
      ),
    );
  }

  String _getVersesToReviewMessage(BuildContext context, int count) {
    final key = count == 1
        ? TranslationKeys.memoryVersesToReviewSingular
        : TranslationKeys.memoryVersesToReviewPlural;
    return context.tr(key, {'count': count.toString()});
  }
}
