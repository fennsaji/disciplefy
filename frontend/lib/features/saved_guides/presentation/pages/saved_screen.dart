import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/services/reading_progress_store.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/empty_state_widget.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/guide_list_item.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/library_continue_card.dart';

/// "Your library": Saved and Recent study guides.
///
/// Title with search, underline tabs, a photo "Continue" card resuming the
/// most recently read guide, then a two-column grid of tinted guide cards.
/// Keeps pagination, pull-to-refresh, save/unsave and the tab query param.
class SavedScreen extends StatefulWidget {
  final int? initialTabIndex;
  final String? navigationSource;

  /// Reading progress for the Continue card; injectable for tests.
  final ReadingProgressStore? progressStore;

  const SavedScreen({
    super.key,
    this.initialTabIndex,
    this.navigationSource,
    this.progressStore,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _savedScrollController;
  late ScrollController _recentScrollController;
  late final ReadingProgressStore _progressStore;
  final TextEditingController _searchController = TextEditingController();
  UnifiedSavedGuidesBloc? _bloc;

  Map<String, ReadingProgress> _progress = const {};
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _savedScrollController = ScrollController();
    _recentScrollController = ScrollController();
    _progressStore = widget.progressStore ?? ReadingProgressStore();

    // Setup scroll listeners for pagination
    _savedScrollController.addListener(_onSavedScroll);
    _recentScrollController.addListener(_onRecentScroll);
    _loadProgress();
  }

  @override
  void dispose() {
    _savedScrollController.removeListener(_onSavedScroll);
    _recentScrollController.removeListener(_onRecentScroll);

    _tabController.dispose();
    _savedScrollController.dispose();
    _recentScrollController.dispose();
    _searchController.dispose();
    _bloc = null;
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final all = await _progressStore.getAll();
    if (mounted) setState(() => _progress = all);
  }

  void _onTabChanged(int tabIndex) {
    _bloc?.add(TabChangedEvent(tabIndex: tabIndex));
  }

  void _onSavedScroll() {
    if (_savedScrollController.position.pixels >=
        _savedScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreSaved();
    }
  }

  void _onRecentScroll() {
    if (_recentScrollController.position.pixels >=
        _recentScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreRecent();
    }
  }

  void _loadMoreSaved() {
    final bloc = _bloc;
    if (bloc != null) {
      final state = bloc.state;
      if (state is SavedGuidesApiLoaded &&
          !state.isLoadingSaved &&
          state.hasMoreSaved) {
        bloc.add(
          LoadSavedGuidesFromApi(offset: state.savedGuides.length),
        );
      }
    }
  }

  void _loadMoreRecent() {
    final bloc = _bloc;
    if (bloc != null) {
      final state = bloc.state;
      if (state is SavedGuidesApiLoaded &&
          !state.isLoadingRecent &&
          state.hasMoreRecent) {
        bloc.add(
          LoadRecentGuidesFromApi(offset: state.recentGuides.length),
        );
      }
    }
  }

  void _setSearching(bool searching) {
    setState(() {
      _searching = searching;
      if (!searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) {
          final bloc = sl<UnifiedSavedGuidesBloc>();
          _bloc = bloc; // Store reference

          // Setup tab listener after BloC is available
          _tabController.addListener(() {
            _onTabChanged(_tabController.index);
          });

          // Load initial tab data based on the initial tab index
          final initialTab = _tabController.index;
          if (initialTab == 0) {
            bloc.add(const LoadSavedGuidesFromApi(refresh: true));
          } else {
            bloc.add(const LoadRecentGuidesFromApi(refresh: true));
          }
          return bloc;
        },
        child: _SavedScreenContent(
          tabController: _tabController,
          savedScrollController: _savedScrollController,
          recentScrollController: _recentScrollController,
          navigationSource: widget.navigationSource,
          progress: _progress,
          onRefreshProgress: _loadProgress,
          searching: _searching,
          query: _query,
          searchController: _searchController,
          onSearchToggled: _setSearching,
          onQueryChanged: (q) => setState(() => _query = q),
        ),
      );
}

class _SavedScreenContent extends StatelessWidget {
  final TabController tabController;
  final ScrollController savedScrollController;
  final ScrollController recentScrollController;
  final String? navigationSource;
  final Map<String, ReadingProgress> progress;
  final Future<void> Function() onRefreshProgress;
  final bool searching;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchToggled;
  final ValueChanged<String> onQueryChanged;

  const _SavedScreenContent({
    required this.tabController,
    required this.savedScrollController,
    required this.recentScrollController,
    required this.progress,
    required this.onRefreshProgress,
    required this.searching,
    required this.query,
    required this.searchController,
    required this.onSearchToggled,
    required this.onQueryChanged,
    this.navigationSource,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (searching) {
          onSearchToggled(false);
          return;
        }
        // Handle Android back button - use smart back navigation
        _handleBackNavigation(context);
      },
      child: Scaffold(
        backgroundColor: palette.page,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, palette),
              _buildTabs(context, palette),
              const SizedBox(height: 8),
              Expanded(
                child: BlocConsumer<UnifiedSavedGuidesBloc, SavedGuidesState>(
                  listener: (context, state) {
                    if (state is SavedGuidesError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              context.tr(TranslationKeys.commonErrorTryAgain)),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (state is SavedGuidesActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is SavedGuidesTabLoading) {
                      return _buildLoadingIndicator(context);
                    }

                    if (state is SavedGuidesAuthRequired) {
                      return _buildAuthRequiredState(context, state);
                    }

                    if (state is SavedGuidesApiLoaded) {
                      return TabBarView(
                        controller: tabController,
                        children: [
                          _buildSavedTab(context, state),
                          _buildRecentTab(context, state),
                        ],
                      );
                    }

                    if (state is SavedGuidesError) {
                      return _buildErrorState(context,
                          context.tr(TranslationKeys.commonErrorTryAgain));
                    }

                    return _buildLoadingIndicator(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header: back, "Your library" / search field, search toggle
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, ReaderPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _handleBackNavigation(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: palette.text),
          ),
          Expanded(
            child: searching
                ? TextField(
                    key: const Key('library_search_field'),
                    controller: searchController,
                    autofocus: true,
                    onChanged: onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: AppFonts.inter(fontSize: 16, color: palette.text),
                    cursorColor: palette.accentIcon,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          context.tr(TranslationKeys.savedGuidesSearchHint),
                      hintStyle:
                          AppFonts.inter(fontSize: 16, color: palette.dim),
                      filled: true,
                      fillColor: palette.raised,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                // Shrinks rather than cutting a long (Malayalam) title.
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr(TranslationKeys.savedGuidesLibraryTitle),
                      maxLines: 1,
                      style: AppFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.2,
                      ),
                    ),
                  ),
          ),
          IconButton(
            key: const Key('library_search_toggle'),
            onPressed: () => onSearchToggled(!searching),
            tooltip: context.tr(searching
                ? TranslationKeys.savedGuidesCloseSearch
                : TranslationKeys.savedGuidesSearch),
            icon: Icon(
              searching ? Icons.close_rounded : Icons.search_rounded,
              size: 26,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, ReaderPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.only(right: 24),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelColor: palette.text,
        unselectedLabelColor: palette.muted,
        labelStyle: AppFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            AppFonts.inter(fontSize: 17, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(width: 3, color: palette.gold),
          insets: const EdgeInsets.symmetric(horizontal: 10),
        ),
        tabs: [
          Tab(text: context.tr(TranslationKeys.savedGuidesSaved)),
          Tab(text: context.tr(TranslationKeys.savedGuidesRecent)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------

  Widget _buildLoadingIndicator(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(TranslationKeys.savedGuidesLoading),
            style: AppFonts.inter(fontSize: 14, color: palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _statusAction(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Key? key,
  }) {
    final palette = ReaderPalette.of(context);
    return FilledButton.icon(
      key: key,
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon, size: 18),
      label: Text(
        label,
        style: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: palette.ctaFill,
        foregroundColor: palette.ctaInk,
        minimumSize: const Size(160, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) =>
      EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: context.tr(TranslationKeys.savedGuidesErrorTitle),
        subtitle: message,
        action: _statusAction(
          context,
          key: const Key('library_retry'),
          label: context.tr(TranslationKeys.savedGuidesRetry),
          icon: Icons.refresh_rounded,
          onPressed: () {
            final bloc = context.read<UnifiedSavedGuidesBloc>();
            if (tabController.index == 0) {
              bloc.add(const LoadSavedGuidesFromApi(refresh: true));
            } else {
              bloc.add(const LoadRecentGuidesFromApi(refresh: true));
            }
          },
        ),
      );

  Widget _buildAuthRequiredState(
          BuildContext context, SavedGuidesAuthRequired state) =>
      EmptyStateWidget(
        icon: state.isForSavedGuides
            ? Icons.bookmark_border_rounded
            : Icons.history_rounded,
        title: context.tr(TranslationKeys.savedGuidesAuthRequired),
        subtitle: state.message,
        action: _statusAction(
          context,
          key: const Key('library_sign_in'),
          label: context.tr(TranslationKeys.recentGuidesSignIn),
          onPressed: () => context.go(AppRoutes.login),
        ),
      );

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _buildSavedTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.savedGuides.isEmpty && !state.isLoadingSaved) {
      return EmptyStateWidget(
        icon: Icons.bookmark_border_rounded,
        title: context.tr(TranslationKeys.savedGuidesEmptyTitle),
        subtitle: context.tr(TranslationKeys.savedGuidesEmptyMessage),
      );
    }

    return _LibraryTab(
      guides: state.savedGuides,
      isLoadingMore: state.isLoadingSaved,
      progress: progress,
      query: query,
      controller: savedScrollController,
      onRefresh: () async {
        context.read<UnifiedSavedGuidesBloc>().add(
              const LoadSavedGuidesFromApi(refresh: true),
            );
        await onRefreshProgress();
      },
      cardBuilder: (guide, index) => GuideListItem(
        key: ValueKey('saved_${guide.id}'),
        guide: guide,
        tintIndex: index,
        onTap: () => _openGuide(context, guide),
        onRemove: () => _toggleSaveStatus(context, guide, false),
        showRemoveOption: true,
      ),
      onOpen: (guide) => _openGuide(context, guide),
    );
  }

  Widget _buildRecentTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.recentGuides.isEmpty && !state.isLoadingRecent) {
      return EmptyStateWidget(
        icon: Icons.history_rounded,
        title: context.tr(TranslationKeys.savedGuidesRecentEmptyTitle),
        subtitle: context.tr(TranslationKeys.savedGuidesRecentEmptyMessage),
      );
    }

    return _LibraryTab(
      guides: state.recentGuides,
      isLoadingMore: state.isLoadingRecent,
      progress: progress,
      query: query,
      controller: recentScrollController,
      onRefresh: () async {
        context.read<UnifiedSavedGuidesBloc>().add(
              const LoadRecentGuidesFromApi(refresh: true),
            );
        await onRefreshProgress();
      },
      cardBuilder: (guide, index) => GuideListItem(
        key: ValueKey('recent_${guide.id}'),
        guide: guide,
        tintIndex: index,
        onTap: () => _openGuide(context, guide),
        onSave: guide.isSaved
            ? null
            : () => _toggleSaveStatus(context, guide, true),
      ),
      onOpen: (guide) => _openGuide(context, guide),
    );
  }

  void _openGuide(BuildContext context, SavedGuideEntity guide) {
    // Determine source based on current tab
    final source = tabController.index == 0 ? 'saved' : 'recent';

    // Navigate to study guide screen with source parameter
    context.go('/study-guide?source=$source', extra: guide.toRouteExtra());
  }

  void _toggleSaveStatus(
      BuildContext context, SavedGuideEntity guide, bool save) {
    context.read<UnifiedSavedGuidesBloc>().add(
          ToggleGuideApiEvent(
            guideId: guide.id,
            save: save,
          ),
        );
  }

  /// Handles smart back navigation based on navigation source
  void _handleBackNavigation(BuildContext context) {
    // Check if we came from Generate Study screen
    if (navigationSource == 'generate' ||
        navigationSource == 'generate-study') {
      // Go back to Generate Study screen
      context.go(AppRoutes.generateStudy);
      return;
    }

    // Check if there's a navigation stack to pop
    if (context.canPop()) {
      // Default pop behavior if there's a navigation stack
      context.pop();
      return;
    }

    // Fallback to home if no stack
    context.go(AppRoutes.generateStudy);
  }
}

/// True when [guide] matches the library search [query] (case-insensitive,
/// on its title, reference and topic).
bool libraryGuideMatches(SavedGuideEntity guide, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    guide.displayTitle,
    guide.title,
    guide.verseReference ?? '',
    guide.topicName ?? '',
  ].any((field) => field.toLowerCase().contains(q));
}

/// One library tab: Continue card, then the guides as a two-column grid of
/// content-sized cards (equal heights within a row), with pull-to-refresh
/// and a load-more spinner.
class _LibraryTab extends StatelessWidget {
  final List<SavedGuideEntity> guides;
  final bool isLoadingMore;
  final Map<String, ReadingProgress> progress;
  final String query;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final Widget Function(SavedGuideEntity guide, int index) cardBuilder;
  final ValueChanged<SavedGuideEntity> onOpen;

  const _LibraryTab({
    required this.guides,
    required this.isLoadingMore,
    required this.progress,
    required this.query,
    required this.controller,
    required this.onRefresh,
    required this.cardBuilder,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final searching = query.trim().isNotEmpty;

    // The Continue card leads the list; its guide is not repeated below.
    final continueGuide =
        searching ? null : pickContinueGuide(guides, progress);
    final gridGuides = searching
        ? guides.where((g) => libraryGuideMatches(g, query)).toList()
        : guides.where((g) => g.id != continueGuide?.id).toList();
    final rowCount = (gridGuides.length + 1) ~/ 2;

    return RefreshIndicator(
      color: palette.accentIcon,
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (continueGuide != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              sliver: SliverToBoxAdapter(
                child: LibraryContinueCard(
                  guide: continueGuide,
                  progress: progress[continueGuide.id],
                  onTap: () => onOpen(continueGuide),
                ),
              ),
            ),
          if (searching && gridGuides.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Text(
                  context.tr(
                      TranslationKeys.savedGuidesNoResults, {'query': query}),
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(fontSize: 14, color: palette.muted),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, continueGuide == null ? 8 : 0, 16,
                24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, row) {
                  final first = row * 2;
                  final second = first + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    // Content-sized cards; the taller one sets the row height.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: cardBuilder(gridGuides[first], first)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: second < gridGuides.length
                                ? cardBuilder(gridGuides[second], second)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: rowCount,
              ),
            ),
          ),
          if (isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(palette.accentIcon),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
