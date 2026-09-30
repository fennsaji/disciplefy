import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/suggested_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/memory_add_error_message.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// "Add a verse" sheet: source tiles (daily verse / suggested / custom) over
/// the curated suggested verses, filtered by category.
///
/// Users can:
/// - Filter by category (Salvation, Comfort, Strength, etc.)
/// - Switch the verse language
/// - Add verses to their memory deck
/// - See "Already added" for verses in their deck
///
/// The daily and custom tiles appear only when [onAddFromDaily] /
/// [onAddManually] are given; they close the sheet and hand over.
class SuggestedVersesSheet extends StatefulWidget {
  final String language;
  final VoidCallback? onVerseAdded;
  final VoidCallback? onAddFromDaily;
  final VoidCallback? onAddManually;

  const SuggestedVersesSheet({
    super.key,
    required this.language,
    this.onVerseAdded,
    this.onAddFromDaily,
    this.onAddManually,
  });

  /// Shows the add-verse sheet.
  static void show(
    BuildContext context, {
    required String language,
    VoidCallback? onVerseAdded,
    VoidCallback? onAddFromDaily,
    VoidCallback? onAddManually,
  }) {
    final palette = ReaderPalette.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<MemoryVerseBloc>(),
        child: SuggestedVersesSheet(
          language: language,
          onVerseAdded: () {
            Navigator.pop(bottomSheetContext);
            onVerseAdded?.call();
          },
          onAddFromDaily: onAddFromDaily == null
              ? null
              : () {
                  Navigator.pop(bottomSheetContext);
                  onAddFromDaily();
                },
          onAddManually: onAddManually == null
              ? null
              : () {
                  Navigator.pop(bottomSheetContext);
                  onAddManually();
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
  late String _currentLanguage;

  /// Supported language codes and their display names
  static const Map<String, String> _supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'ml': 'മലയാളം',
  };

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.language;
    _loadSuggestedVerses();
  }

  void _loadSuggestedVerses() {
    context.read<MemoryVerseBloc>().add(LoadSuggestedVersesEvent(
          category: _selectedCategory?.name,
          language: _currentLanguage,
        ));
  }

  void _onLanguageChanged(String language) {
    setState(() {
      _currentLanguage = language;
    });
    _loadSuggestedVerses();
  }

  void _onCategorySelected(SuggestedVerseCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    context.read<MemoryVerseBloc>().add(LoadSuggestedVersesEvent(
          category: category?.name,
          language: _currentLanguage,
        ));
  }

  void _onAddVerse(SuggestedVerseEntity verse) {
    context.read<MemoryVerseBloc>().add(AddSuggestedVerseEvent(
          verseReference: verse.localizedReference,
          verseText: verse.verseText,
          language: _currentLanguage,
        ));
  }

  bool get _showSourceTiles =>
      widget.onAddFromDaily != null || widget.onAddManually != null;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ColoredBox(
          color: palette.page,
          child: Column(
            children: [
              _buildHeader(context),
              if (_showSourceTiles)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      kMemoryGutter, 4, kMemoryGutter, 12),
                  child: _buildSourceTiles(context),
                ),
              _buildCategoryFilters(context),
              const SizedBox(height: 4),
              Expanded(
                child: BlocConsumer<MemoryVerseBloc, MemoryVerseState>(
                  // Only listen for events relevant to this sheet
                  listenWhen: (previous, current) =>
                      current is VerseAdded ||
                      current is MemoryVerseError ||
                      current is OperationQueued,
                  listener: (context, state) {
                    if (state is VerseAdded) {
                      showAppSnackBar(context, state.message,
                          tone: AppSnackTone.success);
                      // Reload verses to update "Already Added" status
                      _loadSuggestedVerses();
                      widget.onVerseAdded?.call();
                    } else if (state is OperationQueued) {
                      showAppSnackBar(
                        context,
                        context.tr(TranslationKeys.memoryAddFeedbackQueued),
                        tone: AppSnackTone.warning,
                      );
                    } else if (state is MemoryVerseError) {
                      final key = memoryAddErrorKey(state.code);
                      showAppSnackBar(
                        context,
                        context.tr(key ?? TranslationKeys.commonErrorTryAgain),
                        tone: state.code == 'VERSE_ALREADY_EXISTS'
                            ? AppSnackTone.neutral
                            : AppSnackTone.error,
                      );
                      // The verse was already in the deck: refresh the
                      // "Already added" flags that were stale.
                      if (state.code == 'VERSE_ALREADY_EXISTS') {
                        _loadSuggestedVerses();
                      }
                    }
                  },
                  // Only rebuild when suggested-verses-specific state changes
                  buildWhen: (previous, current) =>
                      current is SuggestedVersesLoading ||
                      current is SuggestedVersesLoaded ||
                      current is SuggestedVersesError,
                  builder: (context, state) {
                    if (state is SuggestedVersesError) {
                      return LedgerMessage(
                        icon: Icons.error_outline_rounded,
                        title: context.tr(TranslationKeys.commonErrorTryAgain),
                        actionLabel: context.tr(TranslationKeys.retry),
                        onAction: _loadSuggestedVerses,
                        isError: true,
                      );
                    }

                    if (state is SuggestedVersesLoaded) {
                      return _buildVerseList(
                        context,
                        state.verses,
                        scrollController,
                      );
                    }

                    // Loading and initial state
                    return const LedgerLoading();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: localizations.closeButtonTooltip,
            icon: Icon(Icons.close_rounded, color: palette.text, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr(_showSourceTiles
                        ? TranslationKeys.addMemoryVerseTitle
                        : TranslationKeys.suggestedVersesTitle),
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildLanguageSwitcher(context),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitcher(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopupMenuButton<String>(
      initialValue: _currentLanguage,
      onSelected: _onLanguageChanged,
      color: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _supportedLanguages[_currentLanguage] ?? 'English',
              style: AppFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: palette.muted, size: 20),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return _supportedLanguages.entries.map((entry) {
          return PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                if (entry.key == _currentLanguage)
                  Icon(Icons.check, size: 18, color: palette.accentIcon)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  entry.value,
                  style: AppFonts.inter(fontSize: 14, color: palette.text),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  /// Side-by-side tiles when each gets enough width for its words; on
  /// narrow screens (320pt, long Malayalam words) they stack as full-width
  /// rows so no title or hint is cut off.
  Widget _buildSourceTiles(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final tiles = <_SourceTile>[
      if (widget.onAddFromDaily != null)
        _SourceTile(
          icon: Icons.wb_sunny_outlined,
          iconColor: palette.gold,
          title: context.tr(TranslationKeys.memoryScreensTileDaily),
          hint: context.tr(TranslationKeys.memoryScreensTileDailyHint),
          onTap: widget.onAddFromDaily,
        ),
      _SourceTile(
        icon: Icons.auto_awesome_outlined,
        iconColor: palette.accentIcon,
        title: context.tr(TranslationKeys.memoryScreensTileSuggested),
        hint: context.tr(TranslationKeys.memoryScreensTileSuggestedHint),
        selected: true,
      ),
      if (widget.onAddManually != null)
        _SourceTile(
          icon: Icons.edit_outlined,
          iconColor: palette.gold,
          title: context.tr(TranslationKeys.memoryScreensTileCustom),
          hint: context.tr(TranslationKeys.memoryScreensTileCustomHint),
          onTap: widget.onAddManually,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - 10 * (tiles.length - 1)) / tiles.length;
        final side = tiles.every((tile) => tile.fitsIn(context, tileWidth));
        if (!side) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                tiles[i].asRow(),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
      buildWhen: (previous, current) =>
          current is SuggestedVersesLoaded || current is SuggestedVersesLoading,
      builder: (context, state) {
        final categories = state is SuggestedVersesLoaded
            ? state.categories
            : SuggestedVerseCategory.values.toList();

        return MemoryChipBar(
          chips: [
            MemoryChoiceChip(
              label: context.tr(TranslationKeys.categoryAll),
              selected: _selectedCategory == null,
              onTap: () => _onCategorySelected(null),
            ),
            for (final category in categories)
              MemoryChoiceChip(
                label: _getCategoryLabel(context, category),
                selected: _selectedCategory == category,
                onTap: () => _onCategorySelected(category),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVerseList(
    BuildContext context,
    List<SuggestedVerseEntity> verses,
    ScrollController scrollController,
  ) {
    if (verses.isEmpty) {
      return LedgerMessage(
        icon: Icons.search_off_rounded,
        title: context.tr(TranslationKeys.suggestedNoVersesFound),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(kMemoryGutter, 4, kMemoryGutter, 24),
      itemCount: verses.length,
      itemBuilder: (context, index) {
        final verse = verses[index];
        return _SuggestedVerseRow(
          verse: verse,
          categoryLabel: _getCategoryLabel(context, verse.category),
          onAdd: () => _onAddVerse(verse),
        );
      },
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

/// One of the three "where from" tiles at the top of the sheet: a column
/// tile, or a full-width row when [row] is set (narrow screens).
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String hint;
  final VoidCallback? onTap;
  final bool selected;
  final bool row;

  const _SourceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.hint,
    this.onTap,
    this.selected = false,
    this.row = false,
  });

  static const double _padding = 12;

  static TextStyle _titleStyle(ReaderPalette palette) => AppFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: palette.text,
        height: 1.25,
      );

  static TextStyle _hintStyle(ReaderPalette palette) => AppFonts.inter(
        fontSize: 12.5,
        color: palette.muted,
        height: 1.3,
      );

  _SourceTile asRow() => _SourceTile(
        icon: icon,
        iconColor: iconColor,
        title: title,
        hint: hint,
        onTap: onTap,
        selected: selected,
        row: true,
      );

  /// Whether every word of the title and hint fits the tile's text width
  /// within two lines, i.e. nothing would be broken mid-word or cut.
  bool fitsIn(BuildContext context, double tileWidth) {
    final palette = ReaderPalette.of(context);
    final textWidth = tileWidth - _padding * 2 - 2;
    if (textWidth <= 0) return false;
    final ambient = DefaultTextStyle.of(context).style;
    bool fits(String text, TextStyle ownStyle) {
      final style = ambient.merge(ownStyle);
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      for (final word in text.split(RegExp(r'\s+'))) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          maxLines: 1,
          textScaler: scaler,
          textDirection: direction,
        )..layout();
        if (painter.width > textWidth) return false;
      }
      final whole = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 2,
        textScaler: scaler,
        textDirection: direction,
      )..layout(maxWidth: textWidth);
      return !whole.didExceedMaxLines;
    }

    return fits(title, _titleStyle(palette)) && fits(hint, _hintStyle(palette));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: selected ? ReaderPalette.selectedFill : palette.hairline,
        width: selected ? 1.5 : 1,
      ),
    );
    final fill = selected
        ? Color.alphaBlend(
            ReaderPalette.selectedFill
                .withValues(alpha: palette.isDark ? 0.18 : 0.07),
            palette.card,
          )
        : palette.card;
    final texts = [
      Text(title, style: _titleStyle(palette)),
      const SizedBox(height: 2),
      Text(hint, style: _hintStyle(palette)),
    ];
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: row
                ? const EdgeInsets.symmetric(horizontal: _padding, vertical: 12)
                : const EdgeInsets.fromLTRB(_padding, 14, _padding, 12),
            child: row
                ? Row(
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: texts,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      const SizedBox(height: 16),
                      ...texts,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A suggested verse: reference with its category tag, verse text, then
/// "Add to memory deck" or "Already added".
class _SuggestedVerseRow extends StatelessWidget {
  final SuggestedVerseEntity verse;
  final String categoryLabel;
  final VoidCallback onAdd;

  const _SuggestedVerseRow({
    required this.verse,
    required this.categoryLabel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  verse.localizedReference,
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: MemoryTag(
                  label: categoryLabel,
                  tone: MemoryTone.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verse.versePreview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.inter(
              fontSize: 14.5,
              color: palette.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (verse.isAlreadyAdded)
            Row(
              children: [
                Icon(Icons.check_rounded, size: 17, color: context.appSuccess),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.tr(TranslationKeys.alreadyAdded),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appSuccess,
                    ),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MemoryPrimaryPill(
                label: context.tr(TranslationKeys.addToMemoryDeck),
                icon: Icons.add,
                height: 44,
                onPressed: onAdd,
              ),
            ),
        ],
      ),
    );
  }
}
