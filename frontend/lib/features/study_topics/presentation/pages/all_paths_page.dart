import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/tap_guard.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
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
  return (
    path: path,
    lesson: (path.topicsCompleted + 1).clamp(1, path.topicsCount),
  );
}

/// Every learning path, filtered client-side by category chips ("All",
/// then the categories in their curated order). The user's current path is
/// pinned first with a gold "Current" tag and "Lesson N of M".
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
  Timer? _debounce;
  String? _language;
  String? _category;
  bool _searchOpen = false;

  /// Ignores a double tap; never held across the awaited push.
  final TapGuard _navGuard = TapGuard();

  /// The full flat list, kept while a search replaces the bloc's results.
  List<LearningPath> _all = const [];

  LearningPathsBloc get _bloc => context.read<LearningPathsBloc>();

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _language = widget.language;
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _navGuard.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _load() async {
    final language = await _resolveLanguage();
    if (!mounted) return;
    _bloc.add(LoadFlatLearningPaths(language: language));
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final language = await _resolveLanguage();
      if (!mounted) return;
      _bloc.add(SearchLearningPaths(query: query.trim(), language: language));
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

  Future<void> _openPath(LearningPath path) =>
      guestPathGate(context, path, () => _pushPath(path));

  Future<void> _pushPath(LearningPath path) async {
    if (!_navGuard.tryAcquire()) return;
    final changed = await context
        .push<bool>('/learning-path/${path.id}?source=studyTopics');
    if (!mounted || changed != true) return;
    _load();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.studyTopics);
    }
  }

  /// Categories in the order they first appear (the paths come in curated
  /// order, categories with them).
  List<String> _categories() {
    final seen = <String>{};
    return [
      for (final p in _all)
        if (p.category.trim().isNotEmpty && seen.add(p.category)) p.category,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
          builder: (context, state) {
            // The flat load lands as a "search" with an empty query; a
            // real search later replaces those results, so keep the list.
            if (state is LearningPathsLoaded &&
                state.categories.isEmpty &&
                (state.searchQuery?.isEmpty ?? true) &&
                !state.isSearching &&
                state.searchResults != null) {
              _all = state.searchResults!;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                if (_searchOpen) _buildSearchField(context),
                _buildChips(context),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = ReaderPalette.of(context);
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
                  if (_all.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          TranslationKeys.allPathsCount, {'n': _all.length}),
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

  Widget _buildChips(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _categories();
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          CategoryChip(
            key: const Key('all_paths_chip_all'),
            label: context.tr(TranslationKeys.allPathsAll),
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            CategoryChip(
              key: Key('all_paths_chip_$c'),
              label: l10n.translateLearningPathCategory(c),
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, LearningPathsState state) {
    final palette = ReaderPalette.of(context);
    final searching = _searchController.text.trim().isNotEmpty;

    if (state is LearningPathsError && _all.isEmpty) {
      return _Message(
        icon: Icons.error_outline,
        text: context.tr(TranslationKeys.commonErrorTryAgain),
        actionLabel: context.tr(TranslationKeys.topicsHubRetry),
        onAction: _load,
      );
    }
    final loading = _all.isEmpty &&
        (state is LearningPathsInitial || state is LearningPathsLoading);
    final busy = searching && state is LearningPathsLoaded && state.isSearching;
    if (loading || busy) {
      return const Center(child: CircularProgressIndicator());
    }

    final source = searching && state is LearningPathsLoaded
        ? (state.searchResults ?? const <LearningPath>[])
        : _all;
    final filtered = _category == null
        ? source
        : source.where((p) => p.category == _category).toList();

    final home = sl.isRegistered<HomeBloc>() ? sl<HomeBloc>().state : null;
    final current = currentPathIn(_all, home: home);
    final pinned =
        current != null && filtered.any((p) => p.id == current.path.id);
    final rows = [
      if (pinned) current.path,
      for (final p in filtered)
        if (!pinned || p.id != current.path.id) p,
    ];

    if (rows.isEmpty) {
      return _Message(
        icon: Icons.route_outlined,
        text: searching
            ? context.tr(TranslationKeys.topicsHubNoSearchResults,
                {'query': _searchController.text.trim()})
            : context.tr(TranslationKeys.learningPathsEmpty),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        key: const Key('all_paths_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, 16 + MediaQuery.paddingOf(context).bottom),
        itemCount: rows.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, thickness: 1, color: palette.hairline),
        itemBuilder: (context, index) {
          final path = rows[index];
          final isCurrent = pinned && index == 0;
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
        shape: const StadiumBorder(),
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
                    color: selected ? palette.onSelected : palette.muted,
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
