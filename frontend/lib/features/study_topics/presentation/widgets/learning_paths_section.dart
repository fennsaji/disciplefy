import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Disciple levels always offered as filter chips, in journey order.
/// Levels found in the data but not listed here are appended after them.
const List<String> kPathLevelOrder = [
  'seeker',
  'follower',
  'disciple',
  'leader'
];

/// Displays learning paths grouped by category.
///
/// Each category has a gold header with "See all" and lists the paths it
/// has loaded as rows; the rest of a category is on its "See all" page.
/// More categories are loaded by the screen's infinite scroll.
class LearningPathsSection extends StatefulWidget {
  final void Function(LearningPath path) onPathTap;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onRetry;

  /// Opens the full list of one category ("See all" on a category header).
  final void Function(String category)? onCategorySeeAll;

  /// Content language code used for search API calls (e.g. 'en', 'hi', 'ml').
  final String language;

  /// Called when the user taps "Got it →" on the walkthrough tooltip rendered
  /// for the first path card. Pass null to skip the walkthrough step entirely.
  final VoidCallback? onNext;

  /// Whether the level / featured filter chips show under the search bar.
  /// The Topics tab hides them (no level jargon there).
  final bool showFilters;

  const LearningPathsSection({
    super.key,
    required this.onPathTap,
    this.onSeeAllTap,
    this.onRetry,
    this.onCategorySeeAll,
    this.language = 'en',
    this.onNext,
    this.showFilters = true,
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
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
  /// When offline, only paths with at least one downloaded topic are shown.
  List<LearningPathCategory> _displayCategories(LearningPathsLoaded state) {
    final isSearchActive =
        state.searchQuery != null && state.searchQuery!.isNotEmpty;
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;

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
          var filtered = _applyFilters(cat.paths);

          // Offline: only show paths with at least one downloaded guide
          if (isOffline) {
            final downloadService = sl<LearningPathDownloadService>();
            filtered = filtered.where((p) {
              final model = downloadService.getDownload(p.id);
              return model != null &&
                  model.topics.any((t) => t.status == TopicDownloadStatus.done);
            }).toList();
          }

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
      // A progress reset emits LearningPathsResetting / LearningPathsResetSuccess
      // / LearningPathsResetError as siblings of LearningPathsLoaded on the same
      // bloc — ignore them here so the currently displayed categories don't
      // flash away to the full-width error panel mid-reset or on a failed
      // reset (nothing changed server-side, so there's nothing to report).
      // The follow-up LoadLearningPaths(forceRefresh: true) emits
      // LearningPathsLoading / LearningPathsLoaded normally, which this
      // builder still reacts to.
      buildWhen: (previous, current) =>
          current is! LearningPathsResetting &&
          current is! LearningPathsResetSuccess &&
          current is! LearningPathsResetError,
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
    final palette = ReaderPalette.of(context);

    final headerRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr(TranslationKeys.learningPathsTitle),
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(TranslationKeys.learningPathsSubtitle),
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                ),
              ],
            ),
          ),
          if (widget.onSeeAllTap != null)
            TextButton(
              onPressed: widget.onSeeAllTap,
              child: Text(
                context.tr(TranslationKeys.topicsHubSeeAll),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.accentIcon,
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const SizedBox(height: 14),
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
          _buildCategorySkeletonRow(context),
          _buildCategorySkeletonRow(context),
        ],
      ),
    );
  }

  Widget _buildCategorySkeletonRow(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 110,
              height: 12,
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
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
    final palette = ReaderPalette.of(context);
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;
    final color = isOffline ? palette.muted : theme.colorScheme.error;
    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOffline
              ? palette.raised
              : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isOffline ? Icons.wifi_off : Icons.error_outline,
                    color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isOffline
                        ? context.tr(TranslationKeys.topicsHubOfflineMessage)
                        : context.tr(TranslationKeys.commonErrorTryAgain),
                    style: AppFonts.inter(fontSize: 14, color: color),
                  ),
                ),
              ],
            ),
            if (!isOffline && widget.onRetry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onRetry,
                  child: Text(
                    context.tr(TranslationKeys.topicsHubRetry),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.accentIcon,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return _buildSection(
      context,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          children: [
            Icon(Icons.route_outlined, size: 44, color: palette.dim),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.learningPathsEmpty),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(TranslationKeys.learningPathsEmptyMessage),
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
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

    // Fixed journey levels first, then any other level present in the data.
    final loadedLevels = {
      ...state.categories.expand((c) => c.paths).map((p) => p.discipleLevel),
    }.where((l) => l.isNotEmpty && !kPathLevelOrder.contains(l)).toList()
      ..sort();
    final availableLevels = [...kPathLevelOrder, ...loadedLevels];

    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          _buildSearchBar(context, state),
          // ── Filter chips ────────────────────────────────────────────────
          if (widget.showFilters) _buildFilterChips(context, availableLevels),
          const SizedBox(height: 18),

          // ── Content ─────────────────────────────────────────────────────
          if (state.isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (displayCats.isEmpty)
            _buildNoResultsState(
              context,
              isSearchActive,
              searchFailed: state.searchFailed,
            )
          else ...[
            for (int catIndex = 0; catIndex < displayCats.length; catIndex++)
              _buildCategoryRow(
                context,
                category: displayCats[catIndex],
                state: state,
                isFirstCategory: catIndex == 0,
                showSeeAll: !isSearchActive,
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

  /// "Search N paths" when every category is loaded (so N is exact),
  /// otherwise the generic search hint.
  String _searchHint(BuildContext context, LearningPathsLoaded state) {
    if (state.hasMoreCategories) {
      return AppLocalizations.of(context)!.searchPathsHint;
    }
    final total =
        state.categories.fold<int>(0, (sum, c) => sum + c.totalInCategory);
    if (total <= 0) return AppLocalizations.of(context)!.searchPathsHint;
    return context.tr(TranslationKeys.topicsHubSearchPaths, {'count': total});
  }

  Widget _buildSearchBar(BuildContext context, LearningPathsLoaded state) {
    final palette = ReaderPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.hairline),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        key: const Key('learning_paths_search_field'),
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppFonts.inter(fontSize: 15, color: palette.text),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          hintText: _searchHint(context, state),
          hintStyle: AppFonts.inter(fontSize: 14, color: palette.dim),
          // Long translations wrap rather than cut off.
          hintMaxLines: 2,
          prefixIcon: Icon(Icons.search, size: 21, color: palette.muted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18, color: palette.muted),
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: palette.card,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.accentIcon),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<String> levels) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          PathFilterChip(
            key: const Key('learning_paths_chip_all'),
            label: context.tr(TranslationKeys.topicsHubAllLevels),
            selected: !_featuredOnly && _selectedLevel == null,
            onSelected: (_) => setState(() {
              _featuredOnly = false;
              _selectedLevel = null;
            }),
          ),
          const SizedBox(width: 8),
          PathFilterChip(
            key: const Key('learning_paths_chip_featured'),
            label: context.tr(TranslationKeys.learningPathsFeatured),
            selected: _featuredOnly,
            onSelected: (v) => setState(() => _featuredOnly = v),
          ),
          for (final level in levels) ...[
            const SizedBox(width: 8),
            PathFilterChip(
              key: Key('learning_paths_chip_$level'),
              label: discipleLevelLabel(context, level),
              selected: _selectedLevel == level,
              onSelected: (v) =>
                  setState(() => _selectedLevel = v ? level : null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState(
    BuildContext context,
    bool isSearchActive, {
    bool searchFailed = false,
  }) {
    final palette = ReaderPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          // A failed request must not claim nothing matched.
          searchFailed
              ? context.tr(TranslationKeys.studyTopicsSomethingWentWrong)
              : isSearchActive
                  ? context.tr(TranslationKeys.topicsHubNoSearchResults,
                      {'query': _searchController.text})
                  : context.tr(TranslationKeys.topicsHubNoFilterResults),
          style: AppFonts.inter(fontSize: 14, color: palette.muted),
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
    bool showSeeAll = true,
  }) {
    final palette = ReaderPalette.of(context);
    final hasActive = category.paths.any((p) => p.isInProgress || p.isEnrolled);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header: gold tracked name + "See all"
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                if (hasActive) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette.accentIcon,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      AppLocalizations.of(context)!
                          .translateLearningPathCategory(category.name),
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
                if (showSeeAll && widget.onCategorySeeAll != null)
                  TextButton(
                    key: Key('learning_paths_see_all_${category.name}'),
                    onPressed: () => widget.onCategorySeeAll!(category.name),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.gold,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(TranslationKeys.topicsSeeAll),
                          style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.gold,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: palette.gold),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < category.paths.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: palette.hairline),
                  if (isFirstCategory && i == 0 && widget.onNext != null)
                    WalkthroughTooltip(
                      showcaseKey: ShowcaseKeys.topicsPathCard,
                      title: AppLocalizations.of(context)!
                          .walkthroughLearningPathsTitle,
                      description: AppLocalizations.of(context)!
                          .walkthroughLearningPathsDesc,
                      screen: WalkthroughScreen.learningPaths,
                      stepNumber: 1,
                      totalSteps: 1,
                      onNext: widget.onNext!,
                      child: PathListRow(
                        path: category.paths[i],
                        onTap: () => widget.onPathTap(category.paths[i]),
                      ),
                    )
                  else
                    PathListRow(
                      path: category.paths[i],
                      onTap: () => widget.onPathTap(category.paths[i]),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip (also used by the category page)
// ─────────────────────────────────────────────────────────────────────────────

/// Pill-shaped level/featured filter. Selected: CTA fill; otherwise raised.
class PathFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const PathFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.ctaFill : palette.raised,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onSelected(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? palette.ctaInk : palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
