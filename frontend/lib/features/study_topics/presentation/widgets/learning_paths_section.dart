import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../bloc/learning_paths_state.dart';
import 'learning_path_card.dart';

/// Displays learning paths grouped by category.
///
/// Each category row is always expanded and horizontally scrollable
/// (max 3 paths shown per category, with a load-more ghost card when
/// more paths exist). Initially 4 categories are shown; "Show More"
/// loads the next page of categories from the server.
class LearningPathsSection extends StatefulWidget {
  final void Function(LearningPath path) onPathTap;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onRetry;

  /// Content language code used for search API calls (e.g. 'en', 'hi', 'ml').
  final String language;

  /// Called when the user taps "Got it →" on the walkthrough tooltip rendered
  /// for the first path card. Pass null to skip the walkthrough step entirely.
  final VoidCallback? onNext;

  const LearningPathsSection({
    super.key,
    required this.onPathTap,
    this.onSeeAllTap,
    this.onRetry,
    this.language = 'en',
    this.onNext,
  });

  @override
  State<LearningPathsSection> createState() => _LearningPathsSectionState();
}

class _LearningPathsSectionState extends State<LearningPathsSection> {
  // -------------------------------------------------------------------------
  // Search + filter state
  // -------------------------------------------------------------------------

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedLevel; // null = all levels
  bool _featuredOnly = false;

  // Per-category horizontal scroll controllers for auto-load-more
  final Map<String, ScrollController> _scrollControllers = {};

  ScrollController _scrollControllerFor(String category) {
    return _scrollControllers.putIfAbsent(
      category,
      () => ScrollController(),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<LearningPathsBloc>().add(
            SearchLearningPaths(query: query, language: widget.language),
          );
    });
  }

  /// Apply level/featured filters to a flat list of paths.
  List<LearningPath> _applyFilters(List<LearningPath> paths) {
    return paths.where((p) {
      if (_featuredOnly && !p.isFeatured) return false;
      if (_selectedLevel != null && p.discipleLevel != _selectedLevel) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Build display categories, applying local filters.
  /// In search mode, groups searchResults by category; otherwise uses state categories.
  List<LearningPathCategory> _displayCategories(LearningPathsLoaded state) {
    final isSearchActive =
        state.searchQuery != null && state.searchQuery!.isNotEmpty;

    final List<LearningPathCategory> base;
    if (isSearchActive) {
      // Group flat search results by category
      final Map<String, List<LearningPath>> grouped = {};
      for (final p in state.searchResults ?? []) {
        grouped.putIfAbsent(p.category, () => []).add(p);
      }
      base = grouped.entries
          .map((e) => LearningPathCategory(
                name: e.key,
                paths: e.value,
                totalInCategory: e.value.length,
                nextPathOffset: e.value.length,
              ))
          .toList();
    } else {
      base = state.categories;
    }

    // Apply local filters per category; drop empty categories
    return base
        .map((cat) {
          final filtered = _applyFilters(cat.paths);
          if (filtered.isEmpty) return null;
          return LearningPathCategory(
            name: cat.name,
            paths: filtered,
            totalInCategory: cat.totalInCategory,
            hasMoreInCategory: isSearchActive ? false : cat.hasMoreInCategory,
            isCompleted: cat.isCompleted,
            nextPathOffset: cat.nextPathOffset,
          );
        })
        .whereType<LearningPathCategory>()
        .toList();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, state) {
        if (state is LearningPathsInitial) return const SizedBox.shrink();
        if (state is LearningPathsLoading) return _buildLoadingState(context);
        if (state is LearningPathsError) {
          return _buildErrorState(context, state);
        }
        if (state is LearningPathsEmpty) return _buildEmptyState(context);
        if (state is LearningPathsLoaded) {
          return _buildLoadedState(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // -------------------------------------------------------------------------
  // Section chrome (shared header)
  // -------------------------------------------------------------------------

  Widget _buildSection(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    final headerRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.route_outlined,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.learningPathsTitle),
                  style: AppFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  context.tr(TranslationKeys.learningPathsSubtitle),
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.onSeeAllTap != null)
            TextButton(
              onPressed: widget.onSeeAllTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Loading / Error / Empty states
  // -------------------------------------------------------------------------

  Widget _buildLoadingState(BuildContext context) {
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySkeletonRow(context, label: 'Foundations'),
          _buildCategorySkeletonRow(context, label: 'Growth'),
        ],
      ),
    );
  }

  Widget _buildCategorySkeletonRow(BuildContext context,
      {required String label}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                LearningPathCardSkeleton(),
                SizedBox(width: 12),
                LearningPathCardSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LearningPathsError state) {
    final theme = Theme.of(context);
    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Something went wrong. Please try again.',
                style: AppFonts.inter(
                    fontSize: 14, color: theme.colorScheme.error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                child: Text(
                  'Retry',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.route_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.learningPathsEmpty),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(TranslationKeys.learningPathsEmptyMessage),
              style: AppFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Loaded state — category rows
  // -------------------------------------------------------------------------

  Widget _buildLoadedState(BuildContext context, LearningPathsLoaded state) {
    if (!state.hasPaths) return _buildEmptyState(context);

    final isSearchActive =
        state.searchQuery != null && state.searchQuery!.isNotEmpty;
    final displayCats = _displayCategories(state);

    // Derive available discipline levels from all loaded paths
    final availableLevels = {
      ...state.categories.expand((c) => c.paths).map((p) => p.discipleLevel),
    }.toList()
      ..sort();

    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          _buildSearchBar(context),
          // ── Filter chips ────────────────────────────────────────────────
          if (availableLevels.isNotEmpty)
            _buildFilterChips(context, availableLevels),
          const SizedBox(height: 8),

          // ── Content ─────────────────────────────────────────────────────
          if (state.isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (displayCats.isEmpty)
            _buildNoResultsState(context, isSearchActive)
          else ...[
            for (int catIndex = 0; catIndex < displayCats.length; catIndex++)
              _buildCategoryRow(
                context,
                category: displayCats[catIndex],
                state: state,
                isFirstCategory: catIndex == 0,
              ),

            // Spinner while infinite-scroll loads more categories
            if (state.isFetchingMoreCategories && !isSearchActive)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppFonts.inter(
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintText: 'Search learning paths…',
          hintStyle: AppFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<String> levels) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          // Featured chip
          _FilterChip(
            label: '⭐ ${context.tr(TranslationKeys.learningPathsFeatured)}',
            selected: _featuredOnly,
            onSelected: (v) => setState(() => _featuredOnly = v),
            theme: theme,
          ),
          const SizedBox(width: 8),
          // Level chips
          for (final level in levels) ...[
            _FilterChip(
              label: context.tr('disciple_level.$level'),
              selected: _selectedLevel == level,
              onSelected: (v) =>
                  setState(() => _selectedLevel = v ? level : null),
              theme: theme,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, bool isSearchActive) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          isSearchActive
              ? 'No paths found for "${_searchController.text}"'
              : 'No paths match the selected filters',
          style: AppFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Category row
  // -------------------------------------------------------------------------

  Widget _buildCategoryRow(
    BuildContext context, {
    required LearningPathCategory category,
    required LearningPathsLoaded state,
    bool isFirstCategory = false,
  }) {
    final theme = Theme.of(context);
    final hasActive = category.paths.any((p) => p.isInProgress || p.isEnrolled);
    final isLoadingMore = state.loadingCategories.contains(category.name);
    final scrollController = _scrollControllerFor(category.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (hasActive) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  AppLocalizations.of(context)!
                      .translateLearningPathCategory(category.name),
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification &&
                  category.hasMoreInCategory &&
                  !isLoadingMore) {
                final pos = scrollController.position;
                if (pos.pixels >= pos.maxScrollExtent - 80) {
                  context.read<LearningPathsBloc>().add(
                        LoadMorePathsForCategory(
                          category: category.name,
                          language: widget.language,
                        ),
                      );
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < category.paths.length; i++) ...[
                    if (isFirstCategory && i == 0 && widget.onNext != null)
                      WalkthroughTooltip(
                        showcaseKey: ShowcaseKeys.topicsPathCard,
                        title: AppLocalizations.of(context)!
                            .walkthroughLearningPathsTitle,
                        description: AppLocalizations.of(context)!
                            .walkthroughLearningPathsDesc,
                        screen: WalkthroughScreen.learningPaths,
                        stepNumber: 2,
                        totalSteps: 2,
                        onNext: widget.onNext!,
                        child: LearningPathCard(
                          path: category.paths[i],
                          onTap: () => widget.onPathTap(category.paths[i]),
                        ),
                      )
                    else if (isFirstCategory && i == 0)
                      LearningPathCard(
                        path: category.paths[i],
                        onTap: () => widget.onPathTap(category.paths[i]),
                      )
                    else
                      LearningPathCard(
                        path: category.paths[i],
                        onTap: () => widget.onPathTap(category.paths[i]),
                      ),
                    const SizedBox(width: 12),
                  ],

                  // Inline loading spinner while fetching more
                  if (isLoadingMore)
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widget — themed filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final ThemeData theme;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
