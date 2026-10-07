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
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';

/// Every learning path in one category, opened from "See all" on the
/// Study Topics tab.
///
/// Reads the category from [LearningPathsBloc] (the tab's own instance when
/// opened from the tab) and pages in the rest of it with
/// [LoadMorePathsForCategory] as the list is scrolled. Paths can be narrowed
/// by a title search over the loaded paths. Rows show lessons and days, no
/// level or XP.
class LearningPathCategoryPage extends StatefulWidget {
  /// Category name as stored on the paths (untranslated).
  final String category;

  /// Content language; resolved from preferences when null.
  final String? language;

  const LearningPathCategoryPage({
    super.key,
    required this.category,
    this.language,
  });

  @override
  State<LearningPathCategoryPage> createState() =>
      _LearningPathCategoryPageState();
}

class _LearningPathCategoryPageState extends State<LearningPathCategoryPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _language;
  bool _searchOpen = false;
  bool _isNavigating = false;

  LearningPathsBloc get _bloc => context.read<LearningPathsBloc>();

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() => setState(() {}));
    _ensureLoaded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      Logger.debug('[PATH_CATEGORY] Falling back to en: $e');
      _language = 'en';
    }
    return _language!;
  }

  /// Opened by a direct link: the bloc is fresh, so load the listing.
  Future<void> _ensureLoaded() async {
    final language = await _resolveLanguage();
    if (!mounted) return;
    final state = _bloc.state;
    if (state is LearningPathsInitial ||
        state is LearningPathsError ||
        state is LearningPathsEmpty) {
      _bloc.add(LoadLearningPaths(language: language));
    } else if (state is LearningPathsLoaded) {
      _afterLoaded(state);
    }
  }

  LearningPathCategory? _categoryIn(LearningPathsLoaded state) =>
      state.categories.where((c) => c.name == widget.category).firstOrNull;

  /// Keeps loading until this category is present and fills the screen.
  void _afterLoaded(LearningPathsLoaded state) {
    final language = _language;
    if (language == null) return;
    final category = _categoryIn(state);
    if (category == null) {
      // Not on the loaded category pages yet: fetch the next page.
      if (state.hasMoreCategories && !state.isFetchingMoreCategories) {
        _bloc.add(LoadMoreCategories(language: language));
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent < 200) {
        _loadMore();
      }
    });
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  void _loadMore() {
    final state = _bloc.state;
    final language = _language;
    if (state is! LearningPathsLoaded || language == null) return;
    final category = _categoryIn(state);
    if (category == null ||
        !category.hasMoreInCategory ||
        state.loadingCategories.contains(category.name)) {
      return;
    }
    _bloc.add(LoadMorePathsForCategory(
      category: category.name,
      language: language,
    ));
  }

  List<LearningPath> _filtered(List<LearningPath> paths) {
    final query = _searchController.text.trim().toLowerCase();
    return paths.where((p) {
      if (query.isNotEmpty &&
          !p.title.toLowerCase().contains(query) &&
          !p.description.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Same navigation as the Topics tab: push the detail page and refetch
  /// only when it reports that progress changed.
  Future<void> _openPath(LearningPath path) =>
      guestPathGate(context, path, () => _pushPath(path));

  Future<void> _pushPath(LearningPath path) async {
    if (_isNavigating) return;
    _isNavigating = true;
    final bloc = _bloc;
    final progressChanged = await context
        .push<bool>('/learning-path/${path.id}?source=studyTopics');
    _isNavigating = false;
    if (!mounted || progressChanged != true) return;
    final language = await _resolveLanguage();
    bloc
      ..add(LoadLearningPaths(forceRefresh: true, language: language))
      ..add(LoadPersonalizedPaths(language: language, forceRefresh: true));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.studyTopics);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<LearningPathsBloc, LearningPathsState>(
          listener: (context, state) {
            if (state is LearningPathsLoaded) _afterLoaded(state);
          },
          buildWhen: (previous, current) =>
              current is! LearningPathsResetting &&
              current is! LearningPathsResetSuccess &&
              current is! LearningPathsResetError,
          builder: (context, state) {
            final category =
                state is LearningPathsLoaded ? _categoryIn(state) : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, category),
                if (_searchOpen) _buildSearchField(context),
                Expanded(child: _buildBody(context, state, category)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LearningPathCategory? category) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final subtitle = category == null ? null : _subtitle(context, category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const Key('path_category_back'),
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
                      l10n.translateLearningPathCategory(widget.category),
                      style: AppFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          AppFonts.inter(fontSize: 13.5, color: palette.gold),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('path_category_search_toggle'),
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            color: palette.muted,
            tooltip: _searchOpen
                ? MaterialLocalizations.of(context).closeButtonTooltip
                : MaterialLocalizations.of(context).searchFieldLabel,
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _searchController.clear();
            }),
          ),
        ],
      ),
    );
  }

  /// "7 paths".
  String _subtitle(BuildContext context, LearningPathCategory category) {
    final count = category.totalInCategory > 0
        ? category.totalInCategory
        : category.paths.length;
    return context.tr(
      count == 1
          ? TranslationKeys.topicsHubPathsCountOne
          : TranslationKeys.topicsHubPathsCount,
      {'count': count},
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
        key: const Key('path_category_search_field'),
        controller: _searchController,
        autofocus: true,
        style: AppFonts.inter(fontSize: 15, color: palette.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: AppLocalizations.of(context)!.searchPathsHint,
          hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
          prefixIcon: Icon(Icons.search, size: 21, color: palette.muted),
          filled: true,
          fillColor: palette.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.accentIcon),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LearningPathsState state,
    LearningPathCategory? category,
  ) {
    final palette = ReaderPalette.of(context);
    final bottom = 16 + MediaQuery.paddingOf(context).bottom;

    if (state is LearningPathsError) {
      return _Message(
        icon: Icons.error_outline,
        text: context.tr(TranslationKeys.commonErrorTryAgain),
        actionLabel: context.tr(TranslationKeys.topicsHubRetry),
        onAction: () async {
          final language = await _resolveLanguage();
          _bloc.add(LoadLearningPaths(language: language, forceRefresh: true));
        },
      );
    }
    if (state is LearningPathsEmpty) {
      return _Message(
        icon: Icons.route_outlined,
        text: context.tr(TranslationKeys.learningPathsEmpty),
      );
    }
    if (state is! LearningPathsLoaded || category == null) {
      final loading = state is! LearningPathsLoaded ||
          state.hasMoreCategories ||
          state.isFetchingMoreCategories;
      return loading
          ? const Center(child: CircularProgressIndicator())
          : _Message(
              icon: Icons.route_outlined,
              text: context.tr(TranslationKeys.learningPathsEmpty),
            );
    }

    final paths = _filtered(category.paths);
    final isLoadingMore = state.loadingCategories.contains(category.name);

    return RefreshIndicator(
      onRefresh: () async {
        final language = await _resolveLanguage();
        _bloc.add(RefreshLearningPaths(language: language));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        key: const Key('path_category_list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
        itemCount: paths.isEmpty ? 1 : paths.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(height: 1, thickness: 1, color: palette.hairline),
        itemBuilder: (context, index) {
          if (paths.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.tr(TranslationKeys.topicsHubNoFilterResults),
                textAlign: TextAlign.center,
                style: AppFonts.inter(fontSize: 14, color: palette.muted),
              ),
            );
          }
          if (index >= paths.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final path = paths[index];
          return PathListRow(
            key: Key('path_category_row_${path.id}'),
            path: path,
            onTap: () => _openPath(path),
          );
        },
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
