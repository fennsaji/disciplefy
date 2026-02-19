import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../memory_verses/models/memory_verse_config.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_mode_entity.dart';
import '../../domain/repositories/memory_verse_repository.dart';
import '../widgets/practice_mode_card.dart';
import '../widgets/unlock_limit_exceeded_dialog.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/app_colors.dart';

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

  /// Map of mode type to stats from database
  final Map<PracticeModeType, PracticeModeEntity> _modeStatsMap = {};

  String _userTier = 'free';
  List<String> _unlockedModesToday = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

  /// Get user-friendly mode name for display
  String _getModeName(String modeSlug) {
    const modeNames = {
      'flip_card': 'Flip Card',
      'type_it_out': 'Type It Out',
      'cloze': 'Cloze',
      'first_letter': 'First Letter',
      'progressive': 'Progressive',
      'word_scramble': 'Word Scramble',
      'word_bank': 'Word Bank',
      'audio': 'Audio',
    };
    return modeNames[modeSlug] ?? modeSlug;
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
        return context.tr(TranslationKeys.difficultyAll).toUpperCase();
      case DifficultyFilter.easy:
        return context.tr(TranslationKeys.difficultyEasy).toUpperCase();
      case DifficultyFilter.medium:
        return context.tr(TranslationKeys.difficultyMedium).toUpperCase();
      case DifficultyFilter.hard:
        return context.tr(TranslationKeys.difficultyHard).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredModes = _filterModes();
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return PopScope(
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
          title: Text(context.tr(TranslationKeys.practiceSelectionTitle)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Verse Reference Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primaryContainer,
                child: Column(
                  children: [
                    if (_isLoading)
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    else if (_hasError)
                      Text(
                        context.tr(TranslationKeys.practiceSelectionLoadError),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Text(
                        currentVerse?.verseReference ??
                            context
                                .tr(TranslationKeys.practiceSelectionLoading),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(TranslationKeys.practiceSelectionSubtitle),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withAlpha((0.7 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ),

              // Difficulty Filter (fixed, above scrollable area)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      context.tr(TranslationKeys.practiceSelectionFilter),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: DifficultyFilter.values.map((filter) {
                            final isSelected = selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(
                                    _getDifficultyFilterLabel(context, filter)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() => selectedFilter = filter);
                                },
                                selectedColor:
                                    theme.colorScheme.primaryContainer,
                                checkmarkColor: theme.colorScheme.primary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable: Unlocked Modes Indicator + Practice Mode Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomScrollView(
                        slivers: [
                          // Daily Unlocked Modes Indicator (scrolls with content)
                          if (!_hasError)
                            SliverToBoxAdapter(
                              child: _buildUnlockedModesIndicator(theme),
                            ),

                          // Practice Mode Grid or empty state
                          if (filteredModes.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_off,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withAlpha((0.5 * 255).round()),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.tr(TranslationKeys
                                          .practiceSelectionNoModes),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final mode = filteredModes[index];
                                    final isRecommended =
                                        mode.modeType == recommendedMode;
                                    final isTierLocked =
                                        _isModeTierLocked(mode.modeType);
                                    final isUnlockLimitReached =
                                        _isModeUnlockLimitReached(
                                            mode.modeType);

                                    return PracticeModeCard(
                                      mode: mode,
                                      isRecommended: isRecommended,
                                      isFirstRecommended: isRecommended &&
                                          _isFirstRecommendation,
                                      isTierLocked: isTierLocked,
                                      isUnlockLimitReached:
                                          isUnlockLimitReached,
                                      onTap: () => _selectMode(mode.modeType),
                                      onLockedTap: isTierLocked
                                          ? () =>
                                              context.push(AppRoutes.pricing)
                                          : () =>
                                              UnlockLimitExceededDialog.show(
                                                context,
                                                unlockedModes:
                                                    _unlockedModesToday,
                                                unlockedCount:
                                                    _unlockedModesToday.length,
                                                limit: _getUnlockLimit(),
                                                tier: _userTier,
                                                verseReference: currentVerse
                                                        ?.verseReference ??
                                                    '',
                                              ),
                                    );
                                  },
                                  childCount: filteredModes.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisExtent: 260,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ).withAuthProtection();
  }

  /// Returns a dark-mode-safe text color for a given base color.
  Color _adaptiveTextColor(Color base, ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Color.lerp(base, Colors.white, 0.4)!
        : base;
  }

  /// Build the daily unlocked modes indicator widget
  Widget _buildUnlockedModesIndicator(ThemeData theme) {
    final unlockLimit = _getUnlockLimit();
    final unlockedCount = _unlockedModesToday.length;
    final isPremium = _userTier == 'premium';

    // Premium users don't need this indicator (all modes always unlocked)
    if (isPremium) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.masteryMaster,
              AppColors.masteryMaster,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.3 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium: All modes unlocked',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      );
    }

    // For non-premium users, show unlock progress
    final slotsRemaining = unlockLimit - unlockedCount;
    final progressColor =
        slotsRemaining > 0 ? AppColors.info : AppColors.warning;
    final progressValue = unlockLimit > 0 ? unlockedCount / unlockLimit : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progressColor.withAlpha((0.3 * 255).round()),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and count
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: progressColor.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  slotsRemaining > 0 ? Icons.lock_open : Icons.lock_clock,
                  color: progressColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlocked Modes Today',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$unlockedCount / $unlockLimit modes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress indicator
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progressValue,
                      backgroundColor:
                          progressColor.withAlpha((0.2 * 255).round()),
                      color: progressColor,
                      strokeWidth: 3,
                    ),
                    Text(
                      slotsRemaining > 0 ? '$slotsRemaining' : '✓',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Show unlocked modes if any
          if (unlockedCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _unlockedModesToday.map((modeSlug) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.success.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getModeName(modeSlug),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              _adaptiveTextColor(AppColors.successDark, theme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Message about remaining slots
          if (slotsRemaining > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slotsRemaining == unlockLimit
                          ? 'Choose ${unlockLimit == 1 ? 'a' : 'up to $unlockLimit'} mode${unlockLimit > 1 ? 's' : ''} to practice today'
                          : 'You can unlock $slotsRemaining more mode${slotsRemaining > 1 ? 's' : ''} today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _adaptiveTextColor(
                            AppColors.brandPrimaryDeep, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Daily limit reached message + upgrade button
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: AppColors.warningDark,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily limit reached. Upgrade for more modes!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _adaptiveTextColor(AppColors.warningDark, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.pricing),
                icon: const Icon(Icons.upgrade, size: 18),
                label: const Text('Upgrade Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
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
