import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/reset_progress_error_localizer.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/core/widgets/destructive_confirm_dialog.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/daily_goal_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_streak_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/add_manual_verse_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_verse_list_item.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/milestone_celebration_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/options_menu_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/streak_protection_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/suggested_verses_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/widgets/notification_enable_prompt.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Memory verses deck: streak and counts, today's review goal, Champions
/// and Statistics links, language filter, then the verses due for review and the ones coming up, as quiet
/// rows split by hairlines.
class MemoryVersesHomePage extends StatefulWidget {
  const MemoryVersesHomePage({super.key});

  @override
  State<MemoryVersesHomePage> createState() => _MemoryVersesHomePageState();
}

class _MemoryVersesHomePageState extends State<MemoryVersesHomePage> {
  DueVersesLoaded? _lastLoadedState;
  VerseLanguage? _selectedLanguageFilter;
  final ScrollController _scrollController = ScrollController();
  bool _hasTriggeredMemoryVersePrompt = false;
  StreamSubscription<TokenState>? _tokenSubscription;
  MemoryStreakEntity? _memoryStreak;
  DailyGoalEntity? _dailyGoal;

  // Builder context from ShowCaseWidget — use this for ShowCaseWidget.of() calls.
  // this.context is an ancestor of ShowCaseWidget; ShowCaseWidget.of(this.context) fails.
  BuildContext? _showcaseContext;

  // Prevents the walkthrough from being triggered more than once per visit.
  bool _walkthroughTriggered = false;

  /// Advances the showcase to the next step.
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkPlanAccess();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<MemoryVerseBloc>().state;
      if (state is DueVersesLoaded && state.hasMore && !state.isLoadingMore) {
        context.read<MemoryVerseBloc>().add(LoadMoreVerses(
              language: _selectedLanguageFilter?.code,
            ));
      }
    }
  }

  /// Checks if user has access to Memory Verses (Standard+ only)
  void _checkPlanAccess() {
    // Route is already protected by LockedFeatureWrapper in app_router.dart
    // If user reaches this page, they have access - just load verses
    _loadVerses();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.memoryVerses)) return;
      // Build key list dynamically — verse card step only if list is non-empty
      final hasVerses =
          _lastLoadedState != null && _lastLoadedState!.verses.isNotEmpty;
      final keys = [
        ShowcaseKeys.memoryAddVerse,
        if (hasVerses) ShowcaseKeys.memoryVerseCard,
      ];
      ShowCaseWidget.of(_showcaseContext!).startShowCase(keys);
    });
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
    final reminderPrompted = await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.memoryVerseReminder,
      languageCode: languageCode,
    );

    // Only fall through to the overdue prompt when the reminder one did not
    // appear (already enabled, or previously dismissed) — never stack two
    // sheets on top of each other.
    if (reminderPrompted != null || !mounted) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.memoryVerseOverdue,
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

  /// Gold line under the title: "N due today" or "All caught up", hidden
  /// until the deck has loaded and when the deck is empty.
  String? _dueSubtitle() {
    final loaded = _lastLoadedState;
    if (loaded == null || loaded.statistics.totalVerses == 0) return null;
    final due = loaded.statistics.dueVerses;
    if (due <= 0) return context.tr(TranslationKeys.memoryScreensAllCaughtUp);
    return context.tr(
        TranslationKeys.memoryScreensDueTodayCount, {'count': due.toString()});
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether the verse list is non-empty at build time.
    // Used for both the tooltip totalSteps and the walkthrough key list.
    final hasVerses =
        _lastLoadedState != null && _lastLoadedState!.verses.isNotEmpty;

    // Route is protected by LockedFeatureWrapper - no need for access checks here
    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.memoryVerses),
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: Scaffold(
            backgroundColor: ReaderPalette.of(context).page,
            appBar: MemoryTopBar(
              title: context.tr(TranslationKeys.memoryTitle),
              subtitle: _dueSubtitle(),
              onBack: _handleBackNavigation,
              actions: [
                WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.memoryAddVerse,
                  title:
                      AppLocalizations.of(context)!.walkthroughMemoryAddTitle,
                  description:
                      AppLocalizations.of(context)!.walkthroughMemoryAddDesc,
                  screen: WalkthroughScreen.memoryVerses,
                  stepNumber: 1,
                  totalSteps: hasVerses ? 2 : 1,
                  tooltipPosition: TooltipPosition.bottom,
                  arrowAlignment: Alignment.centerRight,
                  onNext: _onNext,
                  child: MemoryBarAction(
                    icon: Icons.add,
                    tooltip: context.tr(TranslationKeys.memoryHomeAddVerse),
                    onPressed: () => _showAddVerseOptions(context),
                  ),
                ),
                MemoryBarAction(
                  icon: Icons.more_vert,
                  tooltip: context.tr(TranslationKeys.memoryHomeOptions),
                  onPressed: () => _showOptionsMenu(context),
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
                      backgroundColor: AppColors.info,
                    ),
                  );
                  // Reload streak to show updated freeze days
                  context
                      .read<MemoryVerseBloc>()
                      .add(const LoadMemoryStreakEvent());
                } else if (state is MemoryVerseError) {
                  final isOffline = context.read<ConnectivityBloc>().state
                      is ConnectivityOffline;
                  if (!isOffline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(context
                                  .tr(TranslationKeys.commonErrorTryAgain)),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.error,
                        // persist:false — since Flutter 3.44 a SnackBar with an action
                        // defaults to persist:true, so it never times out AND blocks every
                        // later snackbar behind it in the app-wide queue.
                        persist: false,
                        action: SnackBarAction(
                          label: context.tr(TranslationKeys.commonRetry),
                          textColor: Colors.white,
                          onPressed: _loadVerses,
                        ),
                      ),
                    );
                  }
                } else if (state is PracticeSessionSubmitted) {
                  // Silently refresh verse list so stats (review count, next date)
                  // reflect the just-completed practice session.
                  _loadVerses(forceRefresh: true);
                } else if (state is VerseAdded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadVerses(forceRefresh: true);
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
                      backgroundColor: AppColors.warning,
                    ),
                  );
                } else if (state is VerseDeleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(context.tr(TranslationKeys.memoryDeleteSuccess)),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadVerses(forceRefresh: true);
                }
              },
              builder: (context, state) {
                // Track latest loaded state for stale-while-revalidate
                if (state is DueVersesLoaded) {
                  _lastLoadedState = state;
                  // Defer walkthrough until after verses load so hasVerses is accurate.
                  if (!_walkthroughTriggered) {
                    _walkthroughTriggered = true;
                    _triggerWalkthroughIfNeeded();
                  }
                }

                // Show current loaded state (includes silent background refresh)
                if (state is DueVersesLoaded) {
                  return _buildLoadedState(state, hasVerses: hasVerses);
                }

                // Preserve loaded state during transient states — no flicker
                if (_lastLoadedState != null) {
                  return _buildLoadedState(_lastLoadedState!,
                      hasVerses: hasVerses);
                }

                // No cached data yet — if offline show offline message, else spinner
                if (context.read<ConnectivityBloc>().state
                    is ConnectivityOffline) {
                  return _buildOfflineState();
                }
                return _buildLoadingState();
              },
            ),
          ).withAuthProtection(),
        );
      },
    );
  }

  Widget _buildOfflineState() {
    return LedgerMessage(
      icon: Icons.wifi_off_rounded,
      title: context.tr(TranslationKeys.memoryScreensOfflineTitle),
      body: context.tr(TranslationKeys.memoryScreensOfflineBody),
    );
  }

  Widget _buildLoadingState() {
    return LedgerLoading(label: context.tr(TranslationKeys.memoryHomeLoading));
  }

  Widget _buildLoadedState(DueVersesLoaded state, {bool hasVerses = false}) {
    // Show full empty state only when user has no verses at all
    if (state.statistics.totalVerses == 0) {
      return _buildEmptyState();
    }

    final palette = ReaderPalette.of(context);
    final dueVerses = state.verses.where((v) => v.isDue).toList();
    final upcomingVerses = state.verses.where((v) => !v.isDue).toList();
    final firstVerseId = dueVerses.isNotEmpty
        ? dueVerses.first.id
        : (upcomingVerses.isNotEmpty ? upcomingVerses.first.id : null);

    return RefreshIndicator(
      color: palette.accentIcon,
      onRefresh: () async {
        _loadVerses(forceRefresh: true);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(kMemoryGutter, 4, kMemoryGutter, 0),
              child: _buildSummary(state),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildLanguageFilter(context),
            ),
          ),
          if (state.verses.isEmpty)
            SliverToBoxAdapter(child: _buildFilteredEmptyMessage())
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kMemoryGutter),
                child: MemorySectionLabel(
                  '${context.tr(TranslationKeys.memoryDueForReview)} (${dueVerses.length})',
                  padding: const EdgeInsets.only(top: 20),
                ),
              ),
            ),
            if (dueVerses.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      kMemoryGutter, 12, kMemoryGutter, 4),
                  child: Text(
                    context.tr(TranslationKeys.memoryScreensNothingDue),
                    style: AppFonts.inter(fontSize: 14, color: palette.muted),
                  ),
                ),
              )
            else
              _buildVerseSliver(dueVerses, firstVerseId),
            if (upcomingVerses.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: kMemoryGutter),
                  child: MemorySectionLabel(
                    context.tr(TranslationKeys.memoryScreensComingUp),
                    padding: const EdgeInsets.only(top: 24),
                  ),
                ),
              ),
              _buildVerseSliver(upcomingVerses, firstVerseId),
            ],
          ],
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: LedgerLoading(),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// Rows of one section. The very first row of the list carries the
  /// walkthrough step that points at a verse card.
  Widget _buildVerseSliver(
    List<MemoryVerseEntity> verses,
    String? firstVerseId,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: kMemoryGutter),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final verse = verses[index];
            final row = MemoryVerseListItem(
              verse: verse,
              onTap: () => _navigateToReviewPage(context, verse.id),
              onDelete: () => _showDeleteConfirmation(context, verse),
              masteryLevel: verse.masteryLevel,
            );
            if (verse.id == firstVerseId) {
              return WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.memoryVerseCard,
                title:
                    AppLocalizations.of(context)!.walkthroughMemoryVerseTitle,
                description:
                    AppLocalizations.of(context)!.walkthroughMemoryVerseDesc,
                screen: WalkthroughScreen.memoryVerses,
                stepNumber: 2,
                totalSteps: 2,
                onNext: _onNext,
                child: row,
              );
            }
            return row;
          },
          childCount: verses.length,
        ),
      ),
    );
  }

  /// Build message when filter returns no results but user has verses
  Widget _buildFilteredEmptyMessage() {
    return LedgerMessage(
      icon: Icons.search_off_rounded,
      title: context.tr(TranslationKeys.memoryNoVersesInLanguage),
      body: context.tr(TranslationKeys.memoryTryDifferentFilter),
    );
  }

  /// Day streak / verses / mastered tiles, then the daily review goal bar.
  Widget _buildSummary(DueVersesLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatTiles(state),
        if (_dailyGoal != null) ...[
          const SizedBox(height: 20),
          _buildGoalProgress(
            context.tr(TranslationKeys.memoryHomeDailyReviews),
            _dailyGoal!.completedReviews,
            _dailyGoal!.targetReviews,
          ),
        ],
        const SizedBox(height: 16),
        _buildQuickLinks(),
        const SizedBox(height: 16),
        const MemoryHairline(),
      ],
    );
  }

  /// Champions and Statistics entry points (also in the options menu).
  Widget _buildQuickLinks() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MemoryActionPill(
            label: context.tr(TranslationKeys.memoryHomeChampions),
            icon: Icons.emoji_events_outlined,
            height: 44,
            onPressed: () => context.push('/memory-verses/champions'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MemoryActionPill(
            label: context.tr(TranslationKeys.memoryHomeStatistics),
            icon: Icons.bar_chart_outlined,
            height: 44,
            onPressed: () => context.push('/memory-verses/stats'),
          ),
        ),
      ],
    );
  }

  /// Three equal tiles: day streak (gold flame, taps into streak
  /// protection like the old pill), verses (lavender) and mastered (gold).
  Widget _buildStatTiles(DueVersesLoaded state) {
    final palette = ReaderPalette.of(context);
    final streak = _memoryStreak;
    final total = state.statistics.totalVerses;
    final mastered = state.statistics.masteredVerses;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HomeStatTile(
              icon: Icons.local_fire_department_outlined,
              iconColor: palette.gold,
              value: streak == null ? '–' : '${streak.currentStreak}',
              label: context.tr(TranslationKeys.memoryScreensStatDayStreak),
              onTap: streak == null ? null : _onStreakTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HomeStatTile(
              icon: Icons.psychology_outlined,
              iconColor: palette.accentIcon,
              value: '$total',
              label: context.tr(total == 1
                  ? TranslationKeys.memoryScreensStatVerse
                  : TranslationKeys.memoryScreensStatVerses),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HomeStatTile(
              icon: Icons.emoji_events_outlined,
              iconColor: palette.gold,
              value: '$mastered',
              label: context.tr(TranslationKeys.memoryScreensStatMastered),
            ),
          ),
        ],
      ),
    );
  }

  /// Offers a streak freeze when today is not practised yet and one is
  /// available (same behaviour as the previous streak pill).
  void _onStreakTap() {
    final streak = _memoryStreak;
    if (streak == null) return;
    if (!streak.isPracticedToday && streak.canUseFreeze) {
      StreakProtectionDialog.show(
        context,
        freezeDaysAvailable: streak.freezeDaysAvailable,
        currentStreak: streak.currentStreak,
        onConfirm: () {
          context.read<MemoryVerseBloc>().add(
                UseStreakFreezeEvent(freezeDate: DateTime.now()),
              );
        },
      );
    }
  }

  Widget _buildGoalProgress(String label, int current, int target) {
    final palette = ReaderPalette.of(context);
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = target > 0 && current >= target;
    final color = isComplete ? context.appSuccess : palette.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isComplete) ...[
              Icon(Icons.check_circle, size: 15, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              context.tr(TranslationKeys.memoryScreensCountOfTotal, {
                'count': current.toString(),
                'total': target.toString(),
              }),
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: kMemoryTabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MemoryProgressBar(value: progress, color: color),
      ],
    );
  }

  Widget _buildEmptyState() {
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 44, color: palette.accentIcon),
            const SizedBox(height: 18),
            Text(
              context.tr(TranslationKeys.memoryHomeNoVersesTitle),
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.memoryHomeNoVersesSubtitle),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14.5,
                color: palette.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                width: double.infinity,
                child: MemoryPrimaryPill(
                  label: context.tr(TranslationKeys.memoryHomeAddFirstVerse),
                  icon: Icons.add,
                  onPressed: () => _showAddVerseOptions(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the user's current plan from TokenBloc state, defaulting to 'standard'
  String _getCurrentPlan() {
    try {
      final tokenState = context.read<TokenBloc>().state;
      if (tokenState is TokenLoaded) {
        return tokenState.tokenStatus.userPlan.name;
      }
    } catch (_) {}
    return 'standard';
  }

  /// Opens the add-verse sheet: daily verse / suggested / custom tiles on
  /// top of the suggested list. The daily and custom tiles close the sheet
  /// and run the same flows as before.
  void _showAddVerseOptions(BuildContext context) {
    _showSuggestedVersesSheet(
      context,
      onAddFromDaily: () => _showAddFromDailyDialog(context),
      onAddManually: () => _showAddManuallyDialog(context),
    );
  }

  void _showSuggestedVersesSheet(
    BuildContext context, {
    VoidCallback? onAddFromDaily,
    VoidCallback? onAddManually,
  }) {
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
      onAddFromDaily: onAddFromDaily,
      onAddManually: onAddManually,
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
      _addDailyVerseToDeck(
          context, dailyVerseState.verse, dailyVerseState.currentLanguage);
    } else if (dailyVerseState is DailyVerseOffline) {
      // Works offline too, because a verse without a server id is added by its
      // own text rather than by a lookup.
      _addDailyVerseToDeck(
          context, dailyVerseState.verse, dailyVerseState.currentLanguage);
    } else {
      // Daily verse not loaded yet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryDailyVerseNotLoaded)),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  /// Adds the day's verse to the memory deck.
  ///
  /// A verse the server returned without an id carries a synthetic `temp-<date>`
  /// id locally, and the add-from-daily endpoint resolves that id against a
  /// cache row that, in exactly those cases, was never written — so the tap
  /// failed for the rest of the day. The entity already holds the reference and
  /// text for every language, so add it directly instead of asking the server
  /// to look up something it does not have.
  void _addDailyVerseToDeck(
    BuildContext context,
    DailyVerseEntity verse,
    VerseLanguage language,
  ) {
    final bloc = context.read<MemoryVerseBloc>();

    if (verse.id.startsWith('temp-')) {
      bloc.add(AddVerseManually(
        verseReference: verse.getReferenceText(language),
        verseText: verse.getVerseText(language),
        language: language.code,
      ));
      return;
    }

    bloc.add(AddVerseFromDaily(verse.id, language: language.code));
  }

  Future<void> _showAddManuallyDialog(BuildContext context) async {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();

    // Get default language: use filter if selected, otherwise the user's
    // study content language. Verse text is scripture, not UI chrome, so it
    // follows the content axis — the UI language is a different setting and
    // using it here defaulted the dialog to the wrong language for anyone
    // whose two preferences differ.
    VerseLanguage defaultLanguage;
    if (_selectedLanguageFilter != null) {
      defaultLanguage = _selectedLanguageFilter!;
    } else {
      var contentLanguageCode = AppLanguage.english.code;
      try {
        final resolved =
            await sl<LanguagePreferenceService>().getStudyContentLanguage();
        contentLanguageCode = resolved.code;
      } catch (_) {
        // Fall back to English if the preference cannot be read.
      }
      defaultLanguage = _getVerseLanguageFromCode(contentLanguageCode);
    }

    if (!context.mounted) return;

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
    return Semantics(
      label: context.tr(TranslationKeys.memoryFilterByLanguage),
      container: true,
      child: MemoryChipBar(
        chips: [
          MemoryChoiceChip(
            label: context.tr(TranslationKeys.memoryAll),
            selected: _selectedLanguageFilter == null,
            onTap: () {
              setState(() => _selectedLanguageFilter = null);
              _loadVerses();
            },
          ),
          for (final language in VerseLanguage.values)
            MemoryChoiceChip(
              label: language.displayName,
              selected: _selectedLanguageFilter == language,
              onTap: () {
                setState(() => _selectedLanguageFilter = language);
                _loadVerses();
              },
            ),
        ],
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
      onReset: () => _handleResetProgress(context),
    );
  }

  /// Confirms and then deletes the entire memory verse deck.
  ///
  /// `MemoryVerseBloc` is registered as a `Factory` in the DI container, so
  /// `sl<MemoryVerseBloc>()` would return a fresh, disconnected instance —
  /// `context.read` is required to reach the one actually driving this page.
  /// `GamificationBloc`, by contrast, is a `LazySingleton` with no
  /// `BlocProvider` anywhere in the app, so it must be reached via
  /// `sl<GamificationBloc>()`; `context.read<GamificationBloc>()` would throw
  /// `ProviderNotFoundException`.
  Future<void> _handleResetProgress(BuildContext context) async {
    final bloc = context.read<MemoryVerseBloc>();
    final gamificationBloc = sl<GamificationBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.tr(TranslationKeys.memoryResetSuccess);

    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: context.tr(TranslationKeys.memoryResetTitle),
      consequences: [
        context.tr(TranslationKeys.memoryResetItemVerses),
        context.tr(TranslationKeys.memoryResetItemProgress),
        context.tr(TranslationKeys.memoryResetItemStreak),
        context.tr(TranslationKeys.memoryResetItemBadges),
      ],
      confirmWord: context.tr(TranslationKeys.resetProgressConfirmWord),
      confirmLabel: context.tr(TranslationKeys.memoryResetConfirm),
    );

    if (!confirmed) return;

    // Wait for the bloc to settle so the snackbar reflects the real outcome.
    //
    // If the user navigates away while the reset round-trip is outstanding,
    // this widget's `dispose()` closes the bloc, ending its stream with no
    // matching state. `orElse` supplies a sentinel so this await completes
    // cleanly instead of throwing an uncaught `StateError`; the
    // `context.mounted` check below then skips the snackbar since there is
    // no widget left to report to (the reset still completes server-side).
    final completion = bloc.stream.firstWhere(
      (state) =>
          state is MemoryProgressResetSuccess ||
          state is MemoryProgressResetError,
      orElse: () => const MemoryVerseInitial(),
    );

    bloc.add(const ResetMemoryProgressRequested());

    final outcome = await completion;

    if (!context.mounted) return;

    if (outcome is MemoryProgressResetSuccess) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      // Clear the stale-while-revalidate snapshot so the builder cannot
      // re-render the just-deleted deck while the reload below is in
      // flight.
      setState(() {
        _lastLoadedState = null;
      });
      // Deck is empty now — reload using the same helper the rest of the
      // page uses, so the language filter and gamification widgets
      // (streak, daily goal) are refreshed consistently rather than by
      // coincidence of the empty-state UI hiding stale values.
      _loadVerses();
      // Memory badges and challenge progress are gone; refetch gamification
      // stats so they reflect the reset immediately.
      gamificationBloc.add(const RefreshGamificationStats());
    } else if (outcome is MemoryProgressResetError) {
      final errorMessage = localizeResetProgressError(
        context,
        code: outcome.code,
        isNetworkError: outcome.isNetworkError,
        fallbackMessage: outcome.message,
      );
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _navigateToReviewPage(BuildContext context, String verseId) {
    // Check daily review limit before navigating
    final blocState = context.read<MemoryVerseBloc>().state;
    if (blocState is DueVersesLoaded) {
      final stats = blocState.statistics;
      if (stats.isDailyReviewLimitReached) {
        // Allow re-practice of verses already reviewed today
        final verse = blocState.verses.firstWhere(
          (v) => v.id == verseId,
          orElse: () => blocState.verses.first,
        );
        final today = DateTime.now();
        final alreadyReviewedToday = verse.lastReviewed != null &&
            verse.lastReviewed!.year == today.year &&
            verse.lastReviewed!.month == today.month &&
            verse.lastReviewed!.day == today.day;

        if (!alreadyReviewedToday) {
          DailyReviewLimitDialog.show(
            context,
            currentTier: _getCurrentPlan(),
          );
          return;
        }
      }
    }

    // Navigate to practice mode selection to let user choose their preferred mode
    context.push('/memory-verses/practice/$verseId');
  }

  void _startReviewAll(BuildContext context, List<MemoryVerseEntity> verses) {
    if (verses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryNoVersesToReview)),
          backgroundColor: AppColors.warning,
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
      builder: (dialogContext) => SettingsDialog(
        title: context.tr(TranslationKeys.memoryDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse.verseReference,
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ReaderPalette.of(dialogContext).gold,
              ),
            ),
            const SizedBox(height: 10),
            Text(context.tr(TranslationKeys.memoryDeleteConfirmation)),
          ],
        ),
        actions: [
          SettingsButton(
            key: const Key('memory_delete_cancel'),
            label: context.tr(TranslationKeys.memoryDeleteCancel),
            kind: SettingsButtonKind.neutral,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          SettingsButton(
            key: const Key('memory_delete_confirm'),
            label: context.tr(TranslationKeys.memoryDeleteConfirm),
            kind: SettingsButtonKind.destructive,
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MemoryVerseBloc>().add(DeleteVerse(verse.id));
            },
          ),
        ],
      ),
    );
  }
}

/// Home summary tile: icon top-left, big number, muted label that wraps.
class _HomeStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _HomeStatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: palette.hairline),
    );
    return Semantics(
      button: onTap != null,
      label: '$value $label',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      height: 1.15,
                      fontFeatures: kMemoryTabular,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
