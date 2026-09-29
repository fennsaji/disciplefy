import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/bible_data.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';

/// Dialog for adding a Bible verse to the memory deck by structured
/// selection, in the memory verses style: labels above filled fields.
///
/// Features:
/// - Cascading selectors for Book, then Chapter / Verse / To (optional)
/// - Support for verse ranges (e.g., John 3:16-17) and whole chapters
/// - Language segmented control (English / हिन्दी / മലയാളം)
/// - Fetches the verse text from the API via BLoC; the text stays editable
/// - Full-width "Add verse" with Cancel below
class AddManualVerseDialog extends StatefulWidget {
  final Function({
    required String verseReference,
    required String verseText,
    required String language,
  }) onSubmit;

  /// Optional default language to pre-select
  final VerseLanguage defaultLanguage;

  const AddManualVerseDialog({
    super.key,
    required this.onSubmit,
    this.defaultLanguage = VerseLanguage.english,
  });

  /// Shows the add manual verse dialog.
  static void show(
    BuildContext context, {
    required Function({
      required String verseReference,
      required String verseText,
      required String language,
    }) onSubmit,
    VerseLanguage defaultLanguage = VerseLanguage.english,
  }) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => BlocProvider.value(
        value: memoryVerseBloc,
        child: AddManualVerseDialog(
          onSubmit: onSubmit,
          defaultLanguage: defaultLanguage,
        ),
      ),
    );
  }

  @override
  State<AddManualVerseDialog> createState() => _AddManualVerseDialogState();
}

class _AddManualVerseDialogState extends State<AddManualVerseDialog> {
  final _textController = TextEditingController();

  // Selection state
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerseStart; // null means "All" (whole chapter)
  int? _selectedVerseEnd;
  late VerseLanguage _selectedLanguage;
  bool _selectWholeChapter = false;

  // UI state
  bool _isFetchingVerse = false;
  String? _errorMessage;
  String? _fetchedReference;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.defaultLanguage;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Get available chapters for selected book
  List<int> get _availableChapters {
    if (_selectedBook == null) return [];
    final book = BibleData.findBook(_selectedBook!);
    if (book == null) return [];
    return List.generate(book.chapterCount, (i) => i + 1);
  }

  /// Get available verses for selected chapter
  List<int> get _availableVerses {
    if (_selectedBook == null || _selectedChapter == null) return [];
    final book = BibleData.findBook(_selectedBook!);
    if (book == null) return [];
    final verseCount = book.getVerseCount(_selectedChapter!);
    return List.generate(verseCount, (i) => i + 1);
  }

  /// Get available end verses (for range selection)
  List<int> get _availableEndVerses {
    if (_selectedVerseStart == null) return [];
    return _availableVerses.where((v) => v > _selectedVerseStart!).toList();
  }

  /// Fetch verse text via BLoC
  void _fetchVerseText() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      return;
    }

    setState(() {
      _isFetchingVerse = true;
      _errorMessage = null;
    });

    context.read<MemoryVerseBloc>().add(FetchVerseTextRequested(
          book: _selectedBook!,
          chapter: _selectedChapter!,
          verseStart: _selectedVerseStart!,
          verseEnd: _selectedVerseEnd,
          language: _selectedLanguage.code,
        ));
  }

  void _handleSubmit() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      setState(() =>
          _errorMessage = context.tr(TranslationKeys.addVerseSelectRequired));
      return;
    }

    final trimmedText = _textController.text.trim();
    if (trimmedText.isEmpty) {
      setState(() =>
          _errorMessage = context.tr(TranslationKeys.addVerseTextRequired));
      return;
    }

    // Build reference string
    String reference;
    if (_selectWholeChapter) {
      // Whole chapter: "Psalms 23" or "Psalms 23:1-6"
      final book = BibleData.findBook(_selectedBook!);
      final lastVerse =
          book?.getVerseCount(_selectedChapter!) ?? _selectedVerseEnd;
      reference = '$_selectedBook $_selectedChapter:1-$lastVerse';
    } else if (_selectedVerseEnd != null &&
        _selectedVerseEnd! > _selectedVerseStart!) {
      reference =
          '$_selectedBook $_selectedChapter:$_selectedVerseStart-$_selectedVerseEnd';
    } else {
      reference = '$_selectedBook $_selectedChapter:$_selectedVerseStart';
    }

    widget.onSubmit(
      verseReference: _fetchedReference ?? reference,
      verseText: trimmedText,
      language: _selectedLanguage.code,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return BlocListener<MemoryVerseBloc, MemoryVerseState>(
      listener: (context, state) {
        if (state is VerseTextFetched) {
          setState(() {
            _textController.text = state.fetchedVerse.text;
            _fetchedReference = state.fetchedVerse.localizedReference;
            _isFetchingVerse = false;
          });
        } else if (state is FetchVerseTextError) {
          setState(() {
            _errorMessage = context.tr(TranslationKeys.commonErrorTryAgain);
            _isFetchingVerse = false;
          });
        }
      },
      child: Dialog(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: palette.hairline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          // Dialog already pads for the keyboard; the content scrolls so
          // the focused field and actions stay reachable above it.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr(TranslationKeys.addVerseTitle),
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(TranslationKeys.memoryScreensAddVerseSubtitle),
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _FieldLabel(context.tr(TranslationKeys.addVerseBook)),
                _buildBookDropdown(),
                const SizedBox(height: 16),
                _buildChapterVerseRow(),
                const SizedBox(height: 16),
                _FieldLabel(context.tr(TranslationKeys.addVerseLanguage)),
                _buildLanguageSelector(),
                const SizedBox(height: 16),
                _buildFetchButton(),
                const SizedBox(height: 16),
                _buildReferenceDisplay(),
                _FieldLabel(context.tr(TranslationKeys.addVerseText)),
                _buildVerseTextField(),
                const SizedBox(height: 20),
                ..._buildDialogActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Filled field style: raised fill, 14 radius, no outline until focused.
  InputDecoration _fieldDecoration({String? hint, String? errorText}) {
    final palette = ReaderPalette.of(context);
    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 1.5),
        );
    return InputDecoration(
      filled: true,
      fillColor: palette.raised,
      hintText: hint,
      hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
      errorText: errorText,
      errorMaxLines: 3,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(),
      enabledBorder: border(),
      disabledBorder: border(),
      focusedBorder: border(palette.accentIcon),
      errorBorder: border(context.appError),
      focusedErrorBorder: border(context.appError),
    );
  }

  TextStyle get _fieldTextStyle => AppFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ReaderPalette.of(context).text,
      );

  Widget _chevron() => Icon(Icons.keyboard_arrow_down_rounded,
      size: 22, color: ReaderPalette.of(context).muted);

  /// Dims a selector until the step before it is chosen.
  Widget _dimUnless(bool enabled, Widget child) => AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: child,
      );

  Widget _buildBookDropdown() {
    final palette = ReaderPalette.of(context);
    return DropdownButtonFormField<String>(
      value: _selectedBook,
      decoration: _fieldDecoration(),
      hint: Text(
        context.tr(TranslationKeys.memoryScreensChooseBook),
        style: AppFonts.inter(fontSize: 15, color: palette.dim),
      ),
      icon: _chevron(),
      style: _fieldTextStyle,
      dropdownColor: palette.card,
      borderRadius: BorderRadius.circular(14),
      isExpanded: true,
      menuMaxHeight: 320,
      items: BibleData.bookNames.map((name) {
        return DropdownMenuItem(
          value: name,
          child: Text(
            _getLocalizedBookName(name),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBook = value;
          _selectedChapter = null;
          _selectedVerseStart = null;
          _selectedVerseEnd = null;
          _textController.clear();
          _fetchedReference = null;
        });
      },
    );
  }

  /// Get localized book name from translations
  String _getLocalizedBookName(String englishName) {
    return context.tr('bible_books.$englishName');
  }

  /// Chapter / Verse / To: labels on one row (bottom-aligned so a wrapped
  /// label never pushes its selector down), selectors on the next.
  Widget _buildChapterVerseRow() {
    final showEnd = !_selectWholeChapter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child:
                    _FieldLabel(context.tr(TranslationKeys.addVerseChapter))),
            const SizedBox(width: 10),
            Expanded(
                child: _FieldLabel(context.tr(TranslationKeys.addVerseVerse))),
            if (showEnd) ...[
              const SizedBox(width: 10),
              Expanded(
                  child: _FieldLabel(context.tr(TranslationKeys.addVerseTo))),
            ],
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dimUnless(_selectedBook != null, _buildChapterDropdown()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dimUnless(
                  _selectedChapter != null, _buildVerseStartDropdown()),
            ),
            if (showEnd) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _dimUnless(
                    _selectedVerseStart != null, _buildEndVerseDropdown()),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChapterDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedChapter,
      decoration: _fieldDecoration(),
      hint: _dash(),
      disabledHint: _dash(),
      icon: _chevron(),
      style: _fieldTextStyle,
      dropdownColor: ReaderPalette.of(context).card,
      borderRadius: BorderRadius.circular(14),
      isExpanded: true,
      menuMaxHeight: 300,
      items: _availableChapters.map((ch) {
        return DropdownMenuItem(
          value: ch,
          child: Text('$ch'),
        );
      }).toList(),
      onChanged: _selectedBook == null
          ? null
          : (value) {
              setState(() {
                _selectedChapter = value;
                _selectedVerseStart = null;
                _selectedVerseEnd = null;
                _textController.clear();
                _fetchedReference = null;
              });
            },
    );
  }

  Widget _dash() => Text(
        '–',
        style:
            AppFonts.inter(fontSize: 15, color: ReaderPalette.of(context).dim),
      );

  Widget _buildVerseStartDropdown() {
    return DropdownButtonFormField<int?>(
      value: _selectWholeChapter ? -1 : _selectedVerseStart,
      decoration: _fieldDecoration(),
      hint: _dash(),
      disabledHint: _dash(),
      icon: _chevron(),
      style: _fieldTextStyle,
      dropdownColor: ReaderPalette.of(context).card,
      borderRadius: BorderRadius.circular(14),
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        // "All" option for whole chapter
        DropdownMenuItem<int?>(
          value: -1,
          child: Text(context.tr(TranslationKeys.addVerseAll)),
        ),
        ..._availableVerses.map((v) {
          return DropdownMenuItem<int?>(
            value: v,
            child: Text('$v'),
          );
        }),
      ],
      onChanged: _selectedChapter == null
          ? null
          : (value) {
              setState(() {
                if (value == -1) {
                  _selectWholeChapter = true;
                  _selectedVerseStart = 1;
                  // Set end to last verse of chapter
                  final book = BibleData.findBook(_selectedBook!);
                  if (book != null) {
                    _selectedVerseEnd = book.getVerseCount(_selectedChapter!);
                  }
                } else {
                  _selectWholeChapter = false;
                  _selectedVerseStart = value;
                  _selectedVerseEnd = null;
                }
                _textController.clear();
                _fetchedReference = null;
              });
            },
    );
  }

  Widget _buildEndVerseDropdown() {
    return DropdownButtonFormField<int?>(
      value: _selectedVerseEnd,
      decoration: _fieldDecoration(),
      hint: _dash(),
      disabledHint: _dash(),
      icon: _chevron(),
      style: _fieldTextStyle,
      dropdownColor: ReaderPalette.of(context).card,
      borderRadius: BorderRadius.circular(14),
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        const DropdownMenuItem<int?>(
          child: Text('-'),
        ),
        ..._availableEndVerses.map((v) {
          return DropdownMenuItem<int?>(
            value: v,
            child: Text('$v'),
          );
        }),
      ],
      onChanged: _selectedVerseStart == null
          ? null
          : (value) {
              setState(() {
                _selectedVerseEnd = value;
                _textController.clear();
                _fetchedReference = null;
              });
            },
    );
  }

  Widget _buildLanguageSelector() {
    return MemorySegmentedControl<VerseLanguage>(
      segments: [
        for (final language in VerseLanguage.values)
          MemorySegment(value: language, label: language.displayName),
      ],
      selected: _selectedLanguage,
      onChanged: (value) {
        if (value == _selectedLanguage) return;
        setState(() {
          _selectedLanguage = value;
          _textController.clear();
          _fetchedReference = null;
        });
      },
    );
  }

  Widget _buildFetchButton() {
    final canFetch = _selectedBook != null &&
        _selectedChapter != null &&
        _selectedVerseStart != null &&
        !_isFetchingVerse;
    final palette = ReaderPalette.of(context);
    if (_isFetchingVerse) {
      // Spinner + "Fetching..." while the request runs.
      return Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.tr(TranslationKeys.addVerseFetching),
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: MemoryActionPill(
        label: context.tr(TranslationKeys.addVerseFetch),
        icon: Icons.download_rounded,
        height: 48,
        onPressed: canFetch ? _fetchVerseText : null,
      ),
    );
  }

  Widget _buildReferenceDisplay() {
    if (_fetchedReference == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 16, color: ReaderPalette.of(context).gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _fetchedReference!,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReaderPalette.of(context).gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseTextField() {
    final palette = ReaderPalette.of(context);
    return TextField(
      controller: _textController,
      decoration: _fieldDecoration(
        hint: context.tr(TranslationKeys.addVerseTextHint),
        errorText: _errorMessage,
      ),
      style: AppFonts.inter(fontSize: 15, color: palette.text, height: 1.5),
      cursorColor: palette.accentIcon,
      minLines: 4,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) {
        if (_errorMessage != null) {
          setState(() => _errorMessage = null);
        }
      },
    );
  }

  List<Widget> _buildDialogActions() {
    final palette = ReaderPalette.of(context);
    return [
      MemoryPrimaryPill(
        label: context.tr(TranslationKeys.addVerseTitle),
        icon: Icons.add_rounded,
        onPressed: _handleSubmit,
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          foregroundColor: palette.muted,
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
        ),
        child: Text(
          context.tr(TranslationKeys.addVerseCancel),
          textAlign: TextAlign.center,
          style: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ];
  }
}

/// Muted Inter 12.5 label that sits above a field.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: ReaderPalette.of(context).muted,
          ),
        ),
      );
}
