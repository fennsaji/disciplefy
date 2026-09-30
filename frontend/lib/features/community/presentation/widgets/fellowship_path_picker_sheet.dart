import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/disciple_level.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart'
    show discipleLevelLabel;
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_paths_section.dart'
    show PathFilterChip, kPathLevelOrder;
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// Bottom sheet a mentor uses to choose the learning path the whole
/// fellowship studies together.
///
/// Reads [LearningPathsBloc] from the context (the caller provides one and
/// loads it with [LoadFlatLearningPaths]). Paths are searched on the server
/// (debounced), filtered by discipleship level on the client, and listed in
/// discipleship order — seeker, follower, disciple, leader — each level under
/// its own heading with its path count.
///
/// Tapping a path closes the sheet, then calls [onPathSelected].
class FellowshipPathPickerSheet extends StatefulWidget {
  /// Fellowship the path is chosen for; passed on reloads so each path
  /// still says whether this fellowship already completed it.
  final String fellowshipId;

  /// Shown as the gold eyebrow above the title; hidden when null or empty.
  final String? fellowshipName;

  /// The fellowship's current path, tagged "Current" in the list.
  final String? currentPathId;

  /// Content language for loading and searching paths.
  final String language;

  /// Called with the chosen path after the sheet has closed.
  final ValueChanged<LearningPath> onPathSelected;

  const FellowshipPathPickerSheet({
    super.key,
    required this.fellowshipId,
    required this.onPathSelected,
    this.fellowshipName,
    this.currentPathId,
    this.language = 'en',
  });

  @override
  State<FellowshipPathPickerSheet> createState() =>
      _FellowshipPathPickerSheetState();
}

class _FellowshipPathPickerSheetState extends State<FellowshipPathPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// Selected level chip; null means every level.
  String? _level;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload(String query) {
    final bloc = context.read<LearningPathsBloc>();
    if (query.isEmpty) {
      bloc.add(LoadFlatLearningPaths(
        language: widget.language,
        fellowshipId: widget.fellowshipId,
      ));
    } else {
      bloc.add(SearchLearningPaths(query: query, language: widget.language));
    }
  }

  /// Dispatches the search (or the full listing when cleared) after 400 ms.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _reload(value.trim());
    });
  }

  /// The paths in discipleship order: seeker, follower, disciple, leader, and
  /// within a level the curated display order (New Believer Essentials first).
  ///
  /// The listing arrives ordered for the mentor personally — their own
  /// in-progress and enrolled paths, then featured ones — which put a path the
  /// mentor had started ahead of where a group should begin. A group picks from
  /// the curriculum as designed, so the personal order is only the tiebreak.
  List<LearningPath> _byDiscipleLevel(List<LearningPath> paths) {
    final sorted = [...paths];
    sorted.sort((a, b) {
      final byLevel = discipleLevelRank(a.discipleLevel)
          .compareTo(discipleLevelRank(b.discipleLevel));
      if (byLevel != 0) return byLevel;
      // Paths without an order (older cached data) go after ordered ones.
      final byOrder =
          (a.displayOrder ?? 1 << 30).compareTo(b.displayOrder ?? 1 << 30);
      if (byOrder != 0) return byOrder;
      return paths.indexOf(a).compareTo(paths.indexOf(b));
    });
    return sorted;
  }

  List<LearningPath> _filtered(List<LearningPath> paths) {
    final level = _level;
    final visible = level == null
        ? paths
        : paths
            .where((p) =>
                discipleLevelRank(p.discipleLevel) == discipleLevelRank(level))
            .toList();
    return _byDiscipleLevel(visible);
  }

  void _maybeLoadMore(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return;
    }
    final metrics = notification.metrics;
    if (metrics.pixels < metrics.maxScrollExtent - 160) return;

    final bloc = context.read<LearningPathsBloc>();
    final state = bloc.state;
    // Only load more categories when not in search mode.
    if (state is LearningPathsLoaded &&
        state.searchQuery == null &&
        state.hasMoreCategories &&
        !state.isFetchingMoreCategories) {
      bloc.add(LoadMoreCategories(language: widget.language));
    }
  }

  void _select(LearningPath path) {
    Navigator.of(context).pop();
    widget.onPathSelected(path);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, sheetController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
                  builder: (context, state) =>
                      NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      _maybeLoadMore(n);
                      return false;
                    },
                    // Header, search and level chips scroll with the list so
                    // long hi/ml headings never squeeze it out on small
                    // screens; the whole scrollable drags the sheet.
                    child: CustomScrollView(
                      controller: sheetController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(context)),
                        SliverToBoxAdapter(child: _buildSearch(context)),
                        SliverToBoxAdapter(child: _buildLevelChips(context)),
                        ..._buildBody(context, state),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final name = widget.fellowshipName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) ...[
            CommunitySectionLabel(name),
            const SizedBox(height: 6),
          ],
          Semantics(
            header: true,
            child: Text(
              l10n.lessonsChoosePathTitle,
              style: AppFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.text,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.lessonsChoosePathSubtitle,
            style: AppFonts.inter(
              fontSize: 14,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final hasText = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const Key('path_picker_search'),
        controller: _searchController,
        onChanged: (v) {
          _onSearchChanged(v);
          setState(() {}); // refresh the clear button
        },
        style: AppFonts.inter(fontSize: 15, color: palette.text),
        decoration: communityInputDecoration(
          context,
          pill: true,
          hintText: l10n.searchPathsHint,
          prefixIcon: Icon(Icons.search, color: palette.muted),
          suffixIcon: hasText
              ? IconButton(
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: Icon(Icons.close, size: 18, color: palette.muted),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLevelChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          PathFilterChip(
            key: const Key('path_picker_level_all'),
            label: context.tr(TranslationKeys.topicsHubAllLevels),
            selected: _level == null,
            onSelected: (_) => setState(() => _level = null),
          ),
          for (final level in kPathLevelOrder) ...[
            const SizedBox(width: 8),
            PathFilterChip(
              key: Key('path_picker_level_$level'),
              label: discipleLevelLabel(context, level),
              selected: _level == level,
              onSelected: (v) => setState(() => _level = v ? level : null),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, LearningPathsState state) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);
    final spinner = fill(Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CircularProgressIndicator(color: palette.accentIcon),
      ),
    ));

    if (state is LearningPathsLoading || state is LearningPathsInitial) {
      return [spinner];
    }
    if (state is LearningPathsError) {
      return [
        fill(_PathPickerMessage(
          icon: Icons.error_outline_rounded,
          message: state.message,
          actionLabel: context.tr(TranslationKeys.topicsHubRetry),
          onAction: () => _reload(_searchController.text.trim()),
        )),
      ];
    }
    if (state is LearningPathsEmpty) {
      return [
        fill(_PathPickerMessage(
          icon: Icons.search_off_rounded,
          message: l10n.searchNoResults,
        )),
      ];
    }
    if (state is! LearningPathsLoaded) return const [];

    final List<LearningPath> source;
    final bool hasFooter;
    if (state.searchQuery != null) {
      if (state.isSearching) return [spinner];
      // A failed request must not claim nothing matched.
      if (state.searchFailed) {
        return [
          fill(_PathPickerMessage(
            icon: Icons.error_outline_rounded,
            message: context.tr(TranslationKeys.studyTopicsSomethingWentWrong),
            actionLabel: context.tr(TranslationKeys.topicsHubRetry),
            onAction: () => _reload(_searchController.text.trim()),
          )),
        ];
      }
      // This is the sheet's normal listing too, not only an actual search:
      // LoadFlatLearningPaths emits every path as `searchResults` with an
      // empty query, so `categories` — and therefore `allPaths` — is empty.
      source = state.searchResults ?? const [];
      hasFooter = false;
    } else {
      source = state.allPaths;
      hasFooter = state.hasMoreCategories || state.isFetchingMoreCategories;
    }

    final paths = _filtered(source);
    if (paths.isEmpty) {
      if (hasFooter) return [spinner];
      final String message;
      if (source.isNotEmpty) {
        message = context.tr(TranslationKeys.topicsHubNoFilterResults);
      } else if ((state.searchQuery ?? '').isNotEmpty ||
          _searchController.text.trim().isNotEmpty) {
        message = l10n.searchNoResults;
      } else {
        message = context.tr(TranslationKeys.communityFellowshipNoPaths);
      }
      return [
        fill(_PathPickerMessage(
          icon: Icons.search_off_rounded,
          message: message,
        )),
      ];
    }

    final entries = _entries(paths);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            if (entry is _LevelEntry) {
              return _LevelHeading(
                level: entry.level,
                count: entry.count,
                first: index == 0,
              );
            }
            final row = entry as _PathEntry;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FellowshipPathPickerRow(
                  path: row.path,
                  isCurrent: row.path.id == widget.currentPathId,
                  onTap: () => _select(row.path),
                ),
                if (row.divider) Divider(height: 1, color: palette.hairline),
              ],
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(
              top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
          child: state.isFetchingMoreCategories
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accentIcon,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ];
  }

  /// A heading at each level change (with that level's path count), then its
  /// paths separated by hairlines.
  List<Object> _entries(List<LearningPath> sorted) {
    final counts = <int, int>{};
    for (final p in sorted) {
      final rank = discipleLevelRank(p.discipleLevel);
      counts[rank] = (counts[rank] ?? 0) + 1;
    }
    final entries = <Object>[];
    for (var i = 0; i < sorted.length; i++) {
      final path = sorted[i];
      final rank = discipleLevelRank(path.discipleLevel);
      if (i == 0 || discipleLevelRank(sorted[i - 1].discipleLevel) != rank) {
        entries.add(_LevelEntry(path.discipleLevel, counts[rank]!));
      }
      final lastInLevel = i == sorted.length - 1 ||
          discipleLevelRank(sorted[i + 1].discipleLevel) != rank;
      entries.add(_PathEntry(path, divider: !lastInLevel));
    }
    return entries;
  }
}

class _LevelEntry {
  final String level;
  final int count;
  const _LevelEntry(this.level, this.count);
}

class _PathEntry {
  final LearningPath path;
  final bool divider;
  const _PathEntry(this.path, {required this.divider});
}

/// Gold level label with the level's path count on the right.
class _LevelHeading extends StatelessWidget {
  final String level;
  final int count;
  final bool first;

  const _LevelHeading({
    required this.level,
    required this.count,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final countLabel = context.tr(
      count == 1
          ? TranslationKeys.topicsHubPathsCountOne
          : TranslationKeys.topicsHubPathsCount,
      {'count': count},
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? 12 : 24, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CommunitySectionLabel(discipleLevelLabel(context, level)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              countLabel,
              textAlign: TextAlign.end,
              style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// One path in the picker: level-gradient icon tile with the path's own
/// icon, title, two-line description, topics · XP · days, and "Current" /
/// "Completed" tags for this fellowship.
class FellowshipPathPickerRow extends StatelessWidget {
  final LearningPath path;
  final bool isCurrent;
  final VoidCallback onTap;

  const FellowshipPathPickerRow({
    super.key,
    required this.path,
    required this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final meta = [
      '${path.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}',
      if (path.totalXp > 0)
        '${path.totalXp} ${context.tr(TranslationKeys.learningPathsXp)}',
      if (path.estimatedDays > 0)
        '${path.estimatedDays} ${context.tr(TranslationKeys.learningPathsDays)}',
    ].join(' · ');
    final successInk =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;

    return Semantics(
      selected: isCurrent,
      child: InkWell(
        key: Key('path_picker_row_${path.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: PathLevelStyle.gradientFor(path.discipleLevel),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  iconForPath(path.iconName, category: path.category),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.title,
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    if (path.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        path.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: palette.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      meta,
                      style: AppFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: palette.dim,
                      ),
                    ),
                    if (isCurrent || path.fellowshipCompleted) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (isCurrent)
                            _Tag(
                              label: l10n.lessonsCurrentPathTag,
                              ink: palette.accentIcon,
                            ),
                          if (path.fellowshipCompleted)
                            _Tag(
                              label: context
                                  .tr(TranslationKeys.learningPathsCompleted),
                              ink: successInk,
                              fill: AppColors.success,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 22, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted stadium tag ("Current", "Completed").
class _Tag extends StatelessWidget {
  final String label;
  final Color ink;

  /// Tint behind the label; defaults to [ink].
  final Color? fill;

  const _Tag({required this.label, required this.ink, this.fill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: (fill ?? ink).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

/// Loading error, empty listing, no search / filter results — icon,
/// message and an optional retry.
class _PathPickerMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PathPickerMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            32, 32, 32, 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.raised,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: palette.muted),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.text,
                  side: BorderSide(color: palette.outline),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(44, 44),
                ),
                child: Text(actionLabel!, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
