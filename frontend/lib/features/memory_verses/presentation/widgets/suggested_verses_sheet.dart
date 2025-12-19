import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/suggested_verse_entity.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';

/// Bottom sheet for browsing and selecting suggested Bible verses.
///
/// Displays curated verses organized by category with filter chips.
/// Users can:
/// - Filter by category (Salvation, Comfort, Strength, etc.)
/// - See verse reference, preview, and category
/// - Add verses to their memory deck
/// - See "Already Added" badge for verses in their deck
class SuggestedVersesSheet extends StatefulWidget {
  final String language;
  final VoidCallback? onVerseAdded;

  const SuggestedVersesSheet({
    super.key,
    required this.language,
    this.onVerseAdded,
  });

  /// Shows the suggested verses bottom sheet.
  static void show(
    BuildContext context, {
    required String language,
    VoidCallback? onVerseAdded,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<MemoryVerseBloc>(),
        child: SuggestedVersesSheet(
          language: language,
          onVerseAdded: () {
            Navigator.pop(bottomSheetContext);
            onVerseAdded?.call();
          },
        ),
      ),
    );
  }

  @override
  State<SuggestedVersesSheet> createState() => _SuggestedVersesSheetState();
}

class _SuggestedVersesSheetState extends State<SuggestedVersesSheet> {
  SuggestedVerseCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadSuggestedVerses();
  }

  void _loadSuggestedVerses() {
    context.read<MemoryVerseBloc>().add(LoadSuggestedVersesEvent(
          category: _selectedCategory?.name,
          language: widget.language,
        ));
  }

  void _onCategorySelected(SuggestedVerseCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    context.read<MemoryVerseBloc>().add(LoadSuggestedVersesEvent(
          category: category?.name,
          language: widget.language,
        ));
  }

  void _onAddVerse(SuggestedVerseEntity verse) {
    context.read<MemoryVerseBloc>().add(AddSuggestedVerseEvent(
          verseReference: verse.localizedReference,
          verseText: verse.verseText,
          language: widget.language,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            _buildHeader(context, theme),

            // Category Filter Chips
            _buildCategoryFilters(context, theme),

            const Divider(height: 1),

            // Verse List
            Expanded(
              child: BlocConsumer<MemoryVerseBloc, MemoryVerseState>(
                listener: (context, state) {
                  if (state is VerseAdded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Reload verses to update "Already Added" status
                    _loadSuggestedVerses();
                    widget.onVerseAdded?.call();
                  } else if (state is MemoryVerseError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is SuggestedVersesLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is SuggestedVersesError) {
                    return _buildErrorState(context, theme, state.message);
                  }

                  if (state is SuggestedVersesLoaded) {
                    return _buildVerseList(
                      context,
                      theme,
                      state.verses,
                      scrollController,
                    );
                  }

                  // Show loading by default (initial state)
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(TranslationKeys.suggestedVersesTitle),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context, ThemeData theme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
        buildWhen: (previous, current) =>
            current is SuggestedVersesLoaded ||
            current is SuggestedVersesLoading,
        builder: (context, state) {
          final categories = state is SuggestedVersesLoaded
              ? state.categories
              : SuggestedVerseCategory.values.toList();

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // "All" chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(context.tr(TranslationKeys.categoryAll)),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _onCategorySelected(null),
                ),
              ),
              // Category chips
              ...categories.map((category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_getCategoryLabel(context, category)),
                      selected: _selectedCategory == category,
                      onSelected: (_) => _onCategorySelected(category),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerseList(
    BuildContext context,
    ThemeData theme,
    List<SuggestedVerseEntity> verses,
    ScrollController scrollController,
  ) {
    if (verses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.suggestedNoVersesFound),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: verses.length,
      itemBuilder: (context, index) {
        final verse = verses[index];
        return _SuggestedVerseCard(
          verse: verse,
          onAdd: () => _onAddVerse(verse),
        );
      },
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _loadSuggestedVerses,
            child: Text(context.tr(TranslationKeys.retry)),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(
      BuildContext context, SuggestedVerseCategory category) {
    switch (category) {
      case SuggestedVerseCategory.salvation:
        return context.tr(TranslationKeys.categorySalvation);
      case SuggestedVerseCategory.comfort:
        return context.tr(TranslationKeys.categoryComfort);
      case SuggestedVerseCategory.strength:
        return context.tr(TranslationKeys.categoryStrength);
      case SuggestedVerseCategory.wisdom:
        return context.tr(TranslationKeys.categoryWisdom);
      case SuggestedVerseCategory.promise:
        return context.tr(TranslationKeys.categoryPromise);
      case SuggestedVerseCategory.guidance:
        return context.tr(TranslationKeys.categoryGuidance);
      case SuggestedVerseCategory.faith:
        return context.tr(TranslationKeys.categoryFaith);
      case SuggestedVerseCategory.love:
        return context.tr(TranslationKeys.categoryLove);
    }
  }
}

/// Card widget for displaying a suggested verse.
class _SuggestedVerseCard extends StatelessWidget {
  final SuggestedVerseEntity verse;
  final VoidCallback onAdd;

  const _SuggestedVerseCard({
    required this.verse,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reference and Category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    verse.localizedReference,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                _CategoryBadge(category: verse.category),
              ],
            ),

            const SizedBox(height: 12),

            // Verse Text Preview
            Text(
              verse.versePreview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Add Button or Already Added Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (verse.isAlreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr(TranslationKeys.alreadyAdded),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr(TranslationKeys.addToMemoryDeck)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge widget for displaying verse category.
class _CategoryBadge extends StatelessWidget {
  final SuggestedVerseCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        _getCategoryLabel(context),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (category) {
      case SuggestedVerseCategory.salvation:
        return Colors.purple;
      case SuggestedVerseCategory.comfort:
        return Colors.blue;
      case SuggestedVerseCategory.strength:
        return Colors.orange;
      case SuggestedVerseCategory.wisdom:
        return Colors.teal;
      case SuggestedVerseCategory.promise:
        return Colors.amber;
      case SuggestedVerseCategory.guidance:
        return Colors.indigo;
      case SuggestedVerseCategory.faith:
        return Colors.green;
      case SuggestedVerseCategory.love:
        return Colors.red;
    }
  }

  String _getCategoryLabel(BuildContext context) {
    switch (category) {
      case SuggestedVerseCategory.salvation:
        return context.tr(TranslationKeys.categorySalvation);
      case SuggestedVerseCategory.comfort:
        return context.tr(TranslationKeys.categoryComfort);
      case SuggestedVerseCategory.strength:
        return context.tr(TranslationKeys.categoryStrength);
      case SuggestedVerseCategory.wisdom:
        return context.tr(TranslationKeys.categoryWisdom);
      case SuggestedVerseCategory.promise:
        return context.tr(TranslationKeys.categoryPromise);
      case SuggestedVerseCategory.guidance:
        return context.tr(TranslationKeys.categoryGuidance);
      case SuggestedVerseCategory.faith:
        return context.tr(TranslationKeys.categoryFaith);
      case SuggestedVerseCategory.love:
        return context.tr(TranslationKeys.categoryLove);
    }
  }
}
