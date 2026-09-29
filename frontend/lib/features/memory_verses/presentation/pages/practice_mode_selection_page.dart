import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/repositories/memory_verse_repository.dart';
import 'package:disciplefy_bible_study/features/memory_verses/models/memory_verse_config.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_mode_info_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_mode_row.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/unlock_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Practice mode selection page.
///
/// Shows available practice modes with:
/// - Mode icon, name, and description
/// - Success rate badge (from actual practice history)
/// - Difficulty indicator
/// - "Master This Next" recommendations based on progression
///
/// Progression system:
/// - Users progress through modes from easiest to hardest
/// - A mode is "proficient" when user achieves 70%+ accuracy with 3+ practices
/// - "Master This Next" recommends the first non-proficient mode in progression order
class PracticeModeSelectionPage extends StatefulWidget {
  final String verseId;
  final String? lastPracticeMode;

  const PracticeModeSelectionPage({
    super.key,
    required this.verseId,
    this.lastPracticeMode,
  });

  @override
  State<PracticeModeSelectionPage> createState() =>
      _PracticeModeSelectionPageState();
}

class _PracticeModeSelectionPageState extends State<PracticeModeSelectionPage> {
  MemoryVerseEntity? currentVerse;
  List<PracticeModeEntity> availableModes = [];
  PracticeModeType? recommendedMode;
  bool _isFirstRecommendation = true;
  DifficultyFilter selectedFilter = DifficultyFilter.all;
  bool _isLoading = true;
  bool _hasError = false;

  BuildContext? _showcaseContext;
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  /// Map of mode type to stats from database
  final Map<PracticeModeType, PracticeModeEntity> _modeStatsMap = {};

  String _userTier = 'free';
  List<String> _unlockedModesToday = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _triggerWalkthroughIfNeeded();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    // Wait for data to load and the grid to render before starting showcase.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.practiceModes)) return;
      // Extra delay so mode cards are rendered before showcase starts.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!)
          .startShowCase([ShowcaseKeys.memoryPracticeMode]);
    });
  }

  /// Load verse info and practice mode stats in parallel
  Future<void> _loadData() async {
    try {
      // Load verse, mode stats, user tier, and today's unlocked modes in parallel
      await Future.wait([
        _loadVerse(),
        _loadPracticeModeStats(),
        _loadUserTier(),
        _loadUnlockedModesToday(),
      ]);

      if (!mounted) return;

      // Build available modes list with stats and calculate recommendation
      _buildAvailableModes();
      _calculateRecommendation();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Load verse from repository
  Future<void> _loadVerse() async {
    final repository = sl<MemoryVerseRepository>();
    final result = await repository.getVerseById(widget.verseId);

    result.fold(
      (failure) {
        throw Exception('Failed to load verse');
      },
      (verse) {
        currentVerse = verse;
      },
    );
  }

  /// Load practice mode stats for this verse from Supabase
  Future<void> _loadPracticeModeStats() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('memory_practice_modes')
          .select(
              'mode_type, times_practiced, success_rate, average_time_seconds, is_favorite')
          .eq('memory_verse_id', widget.verseId);

      final List<dynamic> data = response as List<dynamic>;

      for (final item in data) {
        final modeTypeStr = item['mode_type'] as String;
        final modeType = PracticeModeTypeExtension.fromJson(modeTypeStr);

        _modeStatsMap[modeType] = PracticeModeEntity(
          modeType: modeType,
          timesPracticed: item['times_practiced'] as int? ?? 0,
          successRate: (item['success_rate'] as num?)?.toDouble() ?? 0.0,
          averageTimeSeconds: item['average_time_seconds'] as int?,
          isFavorite: item['is_favorite'] as bool? ?? false,
        );
      }
    } catch (e) {
      // If stats can't be loaded, continue with empty stats
      // This allows the page to still work for new verses
      Logger.debug('Failed to load practice mode stats: $e');
    }
  }

  /// Load user's active subscription tier from Supabase.
  ///
  /// Uses the canonical `get_user_plan_with_subscription` RPC function which
  /// correctly handles all tier detection cases: admin users, premium trials,
  /// plan_id JOIN, plan_type fallback for IAP subscriptions, standard trial,
  /// and grace period — identical logic to what the backend enforces.
  Future<void> _loadUserTier() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client.rpc(
          'get_user_plan_with_subscription',
          params: {'p_user_id': user.id});

      if (response != null) {
        _userTier = (response as String?) ?? 'free';
      }
    } catch (e) {
      Logger.debug('Failed to load user tier: $e');
    }
  }

  /// Load today's unlocked practice modes for this verse from Supabase
  Future<void> _loadUnlockedModesToday() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Use UTC date to match CURRENT_DATE used by the edge function and SQL functions
      final todayDate =
          DateTime.now().toUtc().toIso8601String().substring(0, 10);

      final response = await Supabase.instance.client
          .from('daily_unlocked_modes')
          .select('unlocked_modes')
          .eq('user_id', user.id)
          .eq('memory_verse_id', widget.verseId)
          .eq('practice_date', todayDate)
          .maybeSingle();

      if (response != null) {
        final modes = response['unlocked_modes'];
        if (modes is List) {
          _unlockedModesToday = List<String>.from(modes);
        }
      }
    } catch (e) {
      Logger.debug('Failed to load unlocked modes: $e');
    }
  }

  /// Build available modes list in progression order with stats
  void _buildAvailableModes() {
    availableModes = PracticeModeProgression.progressionOrder.map((modeType) {
      // Use stats from database if available, otherwise create default
      return _modeStatsMap[modeType] ??
          PracticeModeEntity(
            modeType: modeType,
            timesPracticed: 0,
            successRate: 0.0,
            isFavorite: false,
          );
    }).toList();
  }

  /// Calculate recommendation based on progression system
  ///
  /// Logic:
  /// 1. Find the first mode in progression order that is NOT proficient
  /// 2. If all modes are proficient, recommend the first mode not yet mastered
  /// 3. If all modes mastered, recommend mode least recently practiced (or first mode)
  ///
  /// Also determines if this is "First" (no modes proficient) or "Next" (some proficient)
  void _calculateRecommendation() {
    // Check if any mode is already proficient (to determine First vs Next)
    final anyProficient = availableModes.any((mode) => mode.isProficient);
    _isFirstRecommendation = !anyProficient;

    // Find first non-proficient mode in progression order
    for (final mode in availableModes) {
      if (!mode.isProficient) {
        recommendedMode = mode.modeType;
        return;
      }
    }

    // All modes are proficient - find first non-mastered mode
    // This counts as "next" since user has already achieved proficiency
    _isFirstRecommendation = false;
    for (final mode in availableModes) {
      if (!mode.isMastered) {
        recommendedMode = mode.modeType;
        return;
      }
    }

    // All modes mastered - recommend first mode for maintenance
    // Could also recommend least recently practiced, but we don't track that yet
    recommendedMode = availableModes.isNotEmpty
        ? availableModes.first.modeType
        : PracticeModeType.flipCard;
  }

  /// Handle back navigation - go to memory verses home when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to memory verses home
      GoRouter.of(context).goToMemoryVerses();
    }
  }

  /// Get memory verse config from system config service (DB-driven).
  /// Falls back to default config if not loaded yet.
  MemoryVerseConfig get _memoryConfig {
    try {
      return sl<SystemConfigService>().config?.memoryVerseConfig ??
          MemoryVerseConfig.defaultConfig();
    } catch (_) {
      return MemoryVerseConfig.defaultConfig();
    }
  }

  /// Check if a mode is tier-locked based on user's subscription.
  /// Uses DB-driven config via SystemConfigService.
  bool _isModeTierLocked(PracticeModeType modeType) {
    return !_memoryConfig.hasAccessToMode(_userTier, modeType.toJson());
  }

  /// Check if a mode has reached daily unlock limit.
  /// Uses DB-driven unlock limits via SystemConfigService.
  bool _isModeUnlockLimitReached(PracticeModeType modeType) {
    final unlockLimit = _memoryConfig.getUnlockLimitForTier(_userTier);

    // -1 means unlimited (e.g. premium)
    if (unlockLimit == -1) return false;

    // If mode is already unlocked today, it's not limited
    if (_unlockedModesToday.contains(modeType.toJson())) return false;

    // If user has reached their daily unlock limit, mode is locked
    return _unlockedModesToday.length >= unlockLimit;
  }

  List<PracticeModeEntity> _filterModes() {
    if (selectedFilter == DifficultyFilter.all) {
      return availableModes;
    }

    return availableModes.where((mode) {
      switch (selectedFilter) {
        case DifficultyFilter.easy:
          return mode.difficulty == Difficulty.easy;
        case DifficultyFilter.medium:
          return mode.difficulty == Difficulty.medium;
        case DifficultyFilter.hard:
          return mode.difficulty == Difficulty.hard;
        case DifficultyFilter.all:
          return true;
      }
    }).toList();
  }

  void _selectMode(PracticeModeType modeType) {
    // Preemptive daily review limit check
    final blocState = context.read<MemoryVerseBloc>().state;
    if (blocState is DueVersesLoaded &&
        blocState.statistics.isDailyReviewLimitReached) {
      // Allow re-practice of verses already reviewed today
      final today = DateTime.now();
      final alreadyReviewedToday = currentVerse?.lastReviewed != null &&
          currentVerse!.lastReviewed!.year == today.year &&
          currentVerse!.lastReviewed!.month == today.month &&
          currentVerse!.lastReviewed!.day == today.day;

      if (!alreadyReviewedToday) {
        DailyReviewLimitDialog.show(
          context,
          currentTier: _userTier,
        );
        return;
      }
    }

    // Navigate to the appropriate practice page based on mode type
    // All modes use context.push() to maintain proper back navigation stack
    switch (modeType) {
      case PracticeModeType.flipCard:
        // Push to verse review page (flip card mode)
        context.push('/memory-verse-review', extra: {
          'verseId': widget.verseId,
          'verseIds': null,
        });
        break;
      case PracticeModeType.wordBank:
        context.push('/memory-verses/practice/word-bank/${widget.verseId}');
        break;
      case PracticeModeType.cloze:
        context.push('/memory-verses/practice/cloze/${widget.verseId}');
        break;
      case PracticeModeType.firstLetter:
        context.push('/memory-verses/practice/first-letter/${widget.verseId}');
        break;
      case PracticeModeType.progressive:
        context.push('/memory-verses/practice/progressive/${widget.verseId}');
        break;
      case PracticeModeType.wordScramble:
        context.push('/memory-verses/practice/word-scramble/${widget.verseId}');
        break;
      case PracticeModeType.audio:
        context.push('/memory-verses/practice/audio/${widget.verseId}');
        break;
      case PracticeModeType.typeItOut:
        context.push('/memory-verses/practice/type-it-out/${widget.verseId}');
        break;
    }
  }

  /// Get unlock limit based on tier from DB-driven config.
  /// Returns -1 for unlimited (premium).
  int _getUnlockLimit() {
    return _memoryConfig.getUnlockLimitForTier(_userTier);
  }

  /// Get translated difficulty filter label
  String _getDifficultyFilterLabel(
      BuildContext context, DifficultyFilter filter) {
    switch (filter) {
      case DifficultyFilter.all:
        return context.tr(TranslationKeys.difficultyAll);
      case DifficultyFilter.easy:
        return context.tr(TranslationKeys.difficultyEasy);
      case DifficultyFilter.medium:
        return context.tr(TranslationKeys.difficultyMedium);
      case DifficultyFilter.hard:
        return context.tr(TranslationKeys.difficultyHard);
    }
  }

  /// Localized name of a mode from its API slug ("word_bank").
  String _modeNameFromSlug(String slug) {
    try {
      switch (PracticeModeTypeExtension.fromJson(slug)) {
        case PracticeModeType.flipCard:
          return context.tr(TranslationKeys.practiceModeFlipCard);
        case PracticeModeType.wordBank:
          return context.tr(TranslationKeys.practiceModeWordBank);
        case PracticeModeType.cloze:
          return context.tr(TranslationKeys.practiceModeCloze);
        case PracticeModeType.firstLetter:
          return context.tr(TranslationKeys.practiceModeFirstLetter);
        case PracticeModeType.progressive:
          return context.tr(TranslationKeys.practiceModeProgressive);
        case PracticeModeType.wordScramble:
          return context.tr(TranslationKeys.practiceModeWordScramble);
        case PracticeModeType.audio:
          return context.tr(TranslationKeys.practiceModeAudio);
        case PracticeModeType.typeItOut:
          return context.tr(TranslationKeys.practiceModeTypeItOut);
      }
    } catch (_) {
      return slug;
    }
  }

  void _openUpgrade() {
    context
        .push(AppRoutes.pricing, extra: const {'preselectedPlan': 'standard'});
  }

  void _showLockedMode(bool isTierLocked) {
    if (isTierLocked) {
      _openUpgrade();
      return;
    }
    UnlockLimitExceededDialog.show(
      context,
      unlockedModes: _unlockedModesToday,
      unlockedCount: _unlockedModesToday.length,
      limit: _getUnlockLimit(),
      tier: _userTier,
      verseReference: currentVerse?.verseReference ?? '',
    );
  }

  String? _headerSubtitle(BuildContext context) {
    if (_isLoading) return context.tr(TranslationKeys.practiceSelectionLoading);
    if (_hasError) return null;
    return currentVerse?.verseReference;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final filteredModes = _filterModes();

    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.practiceModes),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: Scaffold(
            backgroundColor: palette.page,
            appBar: MemoryTopBar(
              title: context.tr(TranslationKeys.practiceSelectionTitle),
              subtitle: _headerSubtitle(context),
              onBack: _handleBackNavigation,
            ),
            body: SafeArea(
              top: false,
              child: WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.memoryPracticeMode,
                title:
                    AppLocalizations.of(context)!.walkthroughPracticeModesTitle,
                description:
                    AppLocalizations.of(context)!.walkthroughPracticeModesDesc,
                screen: WalkthroughScreen.practiceModes,
                stepNumber: 1,
                totalSteps: 1,
                onNext: _onNext,
                child: _isLoading
                    ? const LedgerLoading()
                    : CustomScrollView(
                        slivers: [
                          if (_hasError)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    kMemoryGutter, 4, kMemoryGutter, 0),
                                child: LedgerNotice(
                                  icon: Icons.error_outline_rounded,
                                  text: context.tr(TranslationKeys
                                      .practiceSelectionLoadError),
                                  tone: LedgerTone.error,
                                ),
                              ),
                            )
                          else ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    kMemoryGutter, 0, kMemoryGutter, 12),
                                child: Text(
                                  context.tr(TranslationKeys
                                      .practiceSelectionSubtitle),
                                  style: AppFonts.inter(
                                    fontSize: 14,
                                    color: palette.muted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    kMemoryGutter, 0, kMemoryGutter, 0),
                                child: _buildUnlockedModesIndicator(),
                              ),
                            ),
                          ],
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 14, bottom: 4),
                              child: MemoryChipBar(
                                chips: [
                                  Text(
                                    context.tr(TranslationKeys
                                        .practiceSelectionFilter),
                                    style: AppFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: palette.muted,
                                    ),
                                  ),
                                  for (final filter in DifficultyFilter.values)
                                    MemoryChoiceChip(
                                      label: _getDifficultyFilterLabel(
                                          context, filter),
                                      selected: selectedFilter == filter,
                                      onTap: () => setState(
                                          () => selectedFilter = filter),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (filteredModes.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: LedgerMessage(
                                icon: Icons.filter_alt_off_outlined,
                                title: context.tr(
                                    TranslationKeys.practiceSelectionNoModes),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                  kMemoryGutter, 0, kMemoryGutter, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final mode = filteredModes[index];
                                    final isRecommended =
                                        mode.modeType == recommendedMode;
                                    final isTierLocked =
                                        _isModeTierLocked(mode.modeType);
                                    return PracticeModeRow(
                                      mode: mode,
                                      isRecommended: isRecommended,
                                      isFirstRecommended: isRecommended &&
                                          _isFirstRecommendation,
                                      isTierLocked: isTierLocked,
                                      isUnlockLimitReached:
                                          _isModeUnlockLimitReached(
                                              mode.modeType),
                                      onTap: () => _selectMode(mode.modeType),
                                      onInfoTap: () =>
                                          PracticeModeInfoSheet.show(
                                              context, mode.modeType),
                                      onLockedTap: () =>
                                          _showLockedMode(isTierLocked),
                                    );
                                  },
                                  childCount: filteredModes.length,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

  /// Banner with today's unlock allowance and an Upgrade link, or a single
  /// line for plans with every mode unlocked.
  Widget _buildUnlockedModesIndicator() {
    final palette = ReaderPalette.of(context);
    final gold = MemoryToneColors.of(context, MemoryTone.gold);
    final unlockLimit = _getUnlockLimit();
    final unlockedCount = _unlockedModesToday.length;
    final isUnlimited = _userTier == 'premium' || unlockLimit == -1;

    final String title;
    String? detail;
    if (isUnlimited) {
      title = context.tr(TranslationKeys.memoryScreensAllModesUnlocked);
    } else {
      title = context.tr(TranslationKeys.memoryScreensModesUnlockedToday, {
        'count': unlockedCount,
        'limit': unlockLimit,
      });
      final slotsRemaining = unlockLimit - unlockedCount;
      if (slotsRemaining <= 0) {
        detail = context.tr(TranslationKeys.memoryScreensDailyLimitReached);
      } else if (slotsRemaining == unlockLimit) {
        detail = unlockLimit == 1
            ? context.tr(TranslationKeys.practiceChooseOneMode)
            : context.tr(
                TranslationKeys.practiceChooseModes, {'limit': unlockLimit});
      } else {
        detail = slotsRemaining == 1
            ? context.tr(TranslationKeys.practiceUnlockOneMore)
            : context.tr(TranslationKeys.practiceUnlockMoreModes,
                {'count': slotsRemaining});
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: gold.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isUnlimited ? Icons.lock_open_rounded : Icons.key_outlined,
            size: 20,
            color: gold.foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.35,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      color: palette.muted,
                      height: 1.35,
                    ),
                  ),
                // Modes already unlocked today.
                if (!isUnlimited && unlockedCount > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final slug in _unlockedModesToday)
                        MemoryTag(
                          label: _modeNameFromSlug(slug),
                          tone: MemoryTone.success,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!isUnlimited)
            TextButton(
              onPressed: _openUpgrade,
              style: TextButton.styleFrom(
                foregroundColor: palette.accentIcon,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(48, 40),
              ),
              child: Text(
                context.tr(TranslationKeys.memoryScreensUpgrade),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.accentIcon,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Difficulty filter options
enum DifficultyFilter {
  all,
  easy,
  medium,
  hard,
}
