import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/tap_guard.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_current_path_card.dart';

/// The user's current path in [paths] and the lesson they are on: Home's
/// enrolled path when [home] knows it, else the furthest-along unfinished
/// enrolled path. Null when they have none.
({LearningPath path, int lesson})? currentPathIn(
  List<LearningPath> paths, {
  HomeState? home,
}) {
  final summary = home == null ? null : topicsPathSummary(home, null);
  if (summary != null) {
    final path = paths.where((p) => p.id == summary.pathId).firstOrNull;
    if (path != null) {
      return (
        path: path,
        lesson: summary.next?.number ?? summary.lessonTotal,
      );
    }
  }
  final enrolled = paths
      .where((p) => p.isEnrolled && !p.isCompleted && p.topicsCount > 0)
      .toList()
    ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
  if (enrolled.isEmpty) return null;
  final path = enrolled.first;
  return (path: path, lesson: path.currentLessonNumber);
}

/// Every learning path, listed by the server a page at a time: the first
/// page shows at once and the next loads as the list nears its end. Category
/// chips ("All", then every category in the server's order) come from their
/// own light request; a chip lists its category from the server and a search
/// asks the server. The user's current path is pinned first with a gold
/// "Current" tag and "Lesson N of M".
///
/// Open to guests: a locked row shows its lock and opens the account sheet.
class AllPathsPage extends StatefulWidget {
  /// Category chip selected on open; "All" when null.
  final String? initialCategory;

  /// Content language; resolved from preferences when null.
  final String? language;

  const AllPathsPage({super.key, this.initialCategory, this.language});

  @override
  State<AllPathsPage> createState() => _AllPathsPageState();
}

class _AllPathsPageState extends State<AllPathsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String? _language;
  bool _searchOpen = false;

  /// Ignores a double tap; never held across the awaited push.
  final TapGuard _navGuard = TapGuard();

  /// Content-language changes made elsewhere (Settings) while this page
  /// stays mounted in the Topics branch.
  StreamSubscription<AppLanguage>? _languageSub;

  /// Last page asked for by scrolling and when, so a page is not asked for
  /// again on every scroll tick or rebuild.
  String? _lastPageKey;
  DateTime? _lastPageAt;
  static const Duration _pageRetryAfter = Duration(seconds: 3);

  /// Starts loading the next page this far from the end of the list.
  static const double _loadMoreExtent = 600;

  AllPathsBloc get _bloc => context.read<AllPathsBloc>();

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_maybeLoadMore);
    if (sl.isRegistered<LanguagePreferenceService>()) {
      _languageSub = sl<LanguagePreferenceService>()
          .studyContentLanguageChanges
          .listen(_onLanguageChanged);
    }
    _open();
  }

  @override
  void dispose() {
    _languageSub?.cancel();
    _navGuard.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final language = await _resolveLanguage();
    if (!mounted) return;
    _bloc.add(
        AllPathsOpened(language: language, category: widget.initialCategory));
  }

  /// Lists the paths again in the new content language.
  void _onLanguageChanged(AppLanguage language) {
    if (!mounted || language.code == _language) return;
    _language = language.code;
    _lastPageKey = null;
    _bloc.add(AllPathsLanguageChanged(language.code));
  }

  Future<String> _resolveLanguage() async {
    final known = _language;
    if (known != null) return known;
    try {
      final lang =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      _language = lang.code;
    } catch (e) {
      Logger.warning('[ALL_PATHS] Content language unavailable, using en',
          context: {'error': e.runtimeType.toString()});
      _language = 'en';
    }
    return _language!;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _bloc.add(AllPathsSearchChanged(_searchController.text.trim()));
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen && _searchController.text.isNotEmpty) {
        _searchController.clear();
        _onSearchChanged('');
      }
    });
  }

  /// A chip lists its category; a search covers every path, so it is
  /// cleared.
  void _selectCategory(String? category) {
    _debounce?.cancel();
    if (_searchController.text.isNotEmpty) _searchController.clear();
    _bloc.add(AllPathsCategorySelected(category));
  }

  /// Whether the page [key] was just asked for (and so is not asked again).
  bool _recentlyAsked(String key) {
    final now = DateTime.now();
    final at = _lastPageAt;
    if (key == _lastPageKey &&
        at != null &&
        now.difference(at) < _pageRetryAfter) {
      return true;
    }
    _lastPageKey = key;
    _lastPageAt = now;
    return false;
  }

  /// Asks for the next page when the list is near its end, or too short to
  /// scroll. A failed page waits for the footer's Retry.
  void _maybeLoadMore() {
    if (!mounted || !_scrollController.hasClients) return;
    final state = _bloc.state;
    if (state.status != AllPathsStatus.loaded ||
        !state.hasMore ||
        state.loadingMore ||
        state.moreFailed ||
        state.refreshing) {
      return;
    }
    if (_scrollController.position.extentAfter > _loadMoreExtent) return;
    final key =
        '${state.language}|${state.category}|${state.query}|${state.nextOffset}';
    if (_recentlyAsked(key)) return;
    _bloc.add(const AllPathsMoreRequested());
  }

  Future<void> _refresh() {
    final done = Completer<void>();
    _lastPageKey = null;
    _bloc.add(AllPathsRefreshed(done: done));
    return done.future;
  }

  Future<void> _openPath(LearningPath path) =>
      guestPathGate(context, path, () => _pushPath(path));

  Future<void> _pushPath(LearningPath path) async {
    if (!_navGuard.tryAcquire()) return;
    final changed = await context.push<bool>(
        '/learning-path/${path.id}?source=studyTopics',
        extra: path);
    if (!mounted || changed != true) return;
    _refresh();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.studyTopics);
    }
  }

  /// Every category from the server; if that failed, those of the loaded
  /// paths. The selected one is always listed.
  List<String> _categories(AllPathsState state) {
    final seen = <String>{};
    final names = state.categories.isNotEmpty
        ? [for (final c in state.categories) c.name]
        : [for (final p in state.paths) p.category];
    return [
      for (final c in [...names, if (state.category != null) state.category!])
        if (c.trim().isNotEmpty && seen.add(c)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<AllPathsBloc, AllPathsState>(
          listenWhen: (previous, current) =>
              previous.paths.length != current.paths.length ||
              previous.status != current.status ||
              previous.hasMore != current.hasMore,
          // A first page too short to scroll asks for the next at once.
          listener: (context, state) => WidgetsBinding.instance
              .addPostFrameCallback((_) => _maybeLoadMore()),
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, state),
              if (_searchOpen) _buildSearchField(context),
              _buildChips(context, state),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AllPathsState state) {
    final palette = ReaderPalette.of(context);
    final total = state.allTotal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const Key('all_paths_back'),
            icon: const Icon(Icons.arrow_back),
            color: palette.text,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _goBack,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.tr(TranslationKeys.allPathsTitle),
                      style: AppFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (total != null && total > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.allPathsCount, {'n': total}),
                      style: AppFonts.inter(fontSize: 13, color: palette.gold),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('all_paths_search_toggle'),
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            color: palette.muted,
            tooltip: _searchOpen
                ? MaterialLocalizations.of(context).closeButtonTooltip
                : MaterialLocalizations.of(context).searchFieldLabel,
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.hairline),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        key: const Key('all_paths_search_field'),
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: AppFonts.inter(fontSize: 15, color: palette.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: AppLocalizations.of(context)!.searchPathsHint,
          hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
          prefixIcon: Icon(Icons.search, size: 21, color: palette.muted),
          filled: true,
          fillColor: palette.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.accentIcon),
          ),
        ),
      ),
    );
  }

  Widget _buildChips(BuildContext context, AllPathsState state) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _categories(state);
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          CategoryChip(
            key: const Key('all_paths_chip_all'),
            label: context.tr(TranslationKeys.allPathsAll),
            selected: state.category == null,
            onTap: () => _selectCategory(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            CategoryChip(
              key: Key('all_paths_chip_$c'),
              label: l10n.translateLearningPathCategory(c),
              selected: state.category == c,
              onTap: () => _selectCategory(c),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AllPathsState state) {
    if (state.status == AllPathsStatus.error) {
      return _Message(
        icon: Icons.error_outline,
        text: context.tr(TranslationKeys.commonErrorTryAgain),
        actionLabel: context.tr(TranslationKeys.topicsHubRetry),
        onAction: () {
          _lastPageKey = null;
          _bloc.add(const AllPathsRetried());
        },
      );
    }
    if (state.status == AllPathsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final paths = state.paths;
    final home = sl.isRegistered<HomeBloc>() ? sl<HomeBloc>().state : null;
    final current = currentPathIn(paths, home: home);
    final rows = [
      if (current != null) current.path,
      for (final p in paths)
        if (current == null || p.id != current.path.id) p,
    ];

    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: _Message(
                icon: Icons.route_outlined,
                text: state.searching
                    ? context.tr(TranslationKeys.topicsHubNoSearchResults,
                        {'query': state.query})
                    : context.tr(TranslationKeys.learningPathsEmpty),
              ),
            ),
          ),
        ),
      );
    }

    final showFooter = state.loadingMore || state.moreFailed;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        key: const Key('all_paths_list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, 16 + MediaQuery.paddingOf(context).bottom),
        itemCount: rows.length + (showFooter ? 1 : 0),
        // Rows are spaced, not ruled, as in the design.
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index == rows.length) return _buildFooter(context, state);
          final path = rows[index];
          final isCurrent = current != null && index == 0;
          return PathListRow(
            key: Key('all_paths_row_${path.id}'),
            path: path,
            isCurrent: isCurrent,
            currentLesson: isCurrent ? current.lesson : null,
            onTap: () => _openPath(path),
          );
        },
      ),
    );
  }

  /// A small spinner while the next page loads; Retry when it failed.
  Widget _buildFooter(BuildContext context, AllPathsState state) {
    final palette = ReaderPalette.of(context);
    if (state.moreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              context.tr(TranslationKeys.commonErrorTryAgain),
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 13, color: palette.muted),
            ),
            TextButton(
              key: const Key('all_paths_more_retry'),
              onPressed: () =>
                  _bloc.add(const AllPathsMoreRequested(retry: true)),
              child: Text(
                context.tr(TranslationKeys.topicsHubRetry),
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
    }
    return const Padding(
      key: Key('all_paths_more_loading'),
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// 32px category chip: gold when selected, raised otherwise.
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.selectedFill : palette.raised,
        shape: StadiumBorder(
          side:
              selected ? BorderSide.none : BorderSide(color: palette.hairline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // Muted on the raised fill is only 4.5:1 on light.
                    color: selected ? palette.onSelected : palette.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: palette.dim),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
