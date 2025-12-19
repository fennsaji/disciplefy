import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_mode_entity.dart';
import '../../domain/repositories/memory_verse_repository.dart';
import '../widgets/practice_mode_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load verse info and practice mode stats in parallel
  Future<void> _loadData() async {
    try {
      // Load both verse and mode stats in parallel
      await Future.wait([
        _loadVerse(),
        _loadPracticeModeStats(),
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
      debugPrint('Failed to load practice mode stats: $e');
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

              // Difficulty Filter
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

              // Practice Mode Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredModes.isEmpty
                        ? Center(
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
                                  context.tr(
                                      TranslationKeys.practiceSelectionNoModes),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.88,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredModes.length,
                            itemBuilder: (context, index) {
                              final mode = filteredModes[index];
                              final isRecommended =
                                  mode.modeType == recommendedMode;

                              return PracticeModeCard(
                                mode: mode,
                                isRecommended: isRecommended,
                                isFirstRecommended:
                                    isRecommended && _isFirstRecommendation,
                                onTap: () => _selectMode(mode.modeType),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ).withAuthProtection(),
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
