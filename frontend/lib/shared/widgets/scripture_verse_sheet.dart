import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_fonts.dart';
import '../../core/constants/bible_books.dart';
import '../../core/constants/bible_translation_citation.dart';
import '../../core/extensions/translation_extension.dart';
import '../../core/i18n/translation_keys.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/language_preference_service.dart';
import '../../core/services/system_config_service.dart';
import '../../core/theme/reader_palette.dart';
import '../../core/utils/share_links.dart';
import '../../features/memory_verses/data/services/verse_cache_service.dart';
import '../../features/memory_verses/domain/entities/fetched_verse_entity.dart';
import '../../features/memory_verses/domain/usecases/fetch_verse_text.dart';
import '../../features/memory_verses/domain/usecases/add_verse_manually.dart';
import '../../features/settings/presentation/widgets/settings_group.dart'
    show SettingsButton, SettingsButtonKind, SettingsButtonRow;
import 'app_snackbar.dart';
import 'popup.dart' show PopupEyebrow, PopupPrimaryButton, kPopupRadius;
import 'sheet_scroll_view.dart';

/// A bottom sheet widget for displaying scripture verse text.
///
/// Shows the verse text when a scripture reference chip is tapped,
/// with options to copy the text.
class ScriptureVerseSheet extends StatefulWidget {
  /// The scripture reference (e.g., "John 3:16", "Matthew 5:1-12")
  final String reference;

  const ScriptureVerseSheet({
    super.key,
    required this.reference,
  });

  /// Shows the scripture verse bottom sheet.
  ///
  /// [context] - The build context to show the sheet in.
  /// [reference] - The scripture reference string to fetch and display.
  static void show(BuildContext context, {required String reference}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScriptureVerseSheet(reference: reference),
    );
  }

  /// Parses a scripture reference string into components.
  ///
  /// Supports formats in English, Hindi (Devanagari), and Malayalam:
  /// - "John 3:16" -> book: John, chapter: 3, verseStart: 16, verseEnd: null (single verse)
  /// - "John 3" -> book: John, chapter: 3, verseStart: 1, verseEnd: 999 (entire chapter)
  /// - "1 John 3:16" -> book: 1 John, chapter: 3, verseStart: 16, verseEnd: null
  /// - "Matthew 5:1-12" -> book: Matthew, chapter: 5, verseStart: 1, verseEnd: 12 (verse range)
  /// - "1 Corinthians 10:23-11:1" -> chapter: 10, verseStart: 23, endChapter: 11, verseEnd: 1
  /// - "यूहन्ना 3:16" -> book: यूहन्ना, chapter: 3, verseStart: 16, verseEnd: null
  /// - "भजन संहिता 23" -> book: भजन संहिता, chapter: 23, verseStart: 1, verseEnd: 999 (entire chapter)
  /// - "भजन संहिता 119:105" -> book: भजन संहिता, chapter: 119, verseStart: 105, verseEnd: null
  /// - "രോമർ 8:28" -> book: രോമർ, chapter: 8, verseStart: 28, verseEnd: null
  @visibleForTesting
  static ParsedScriptureReference? parseReference(String reference) {
    // Pattern: captures book name in English, Hindi, or Malayalam
    // - May start with number (1 John, 2 Timothy, etc.)
    // - Supports multi-word book names (भजन संहिता, Song of Solomon, etc.)
    // - Supports chapter-only, chapter:verse, same-chapter ranges and
    //   cross-chapter ranges ("10:23-11:1": group 5 = end chapter,
    //   group 6 = end verse; group 4 is the same-chapter end verse)
    // Unicode ranges: Devanagari (Hindi) ऀ-ॿ, Malayalam ഀ-ൿ
    final regex = RegExp(
      r'^(\d?\s?[A-Za-zऀ-ॿഀ-ൿ]+(?:\s+[A-Za-zऀ-ॿഀ-ൿ]+)*)\s+(\d+)(?::(\d+)(?:-(\d+)(?!\d|:\d)|-(\d+):(\d+))?)?$',
    );
    final match = regex.firstMatch(reference.trim());

    if (match == null) {
      return null;
    }

    final chapter = int.parse(match.group(2)!);
    final endChapterGroup = match.group(5);
    if (endChapterGroup != null) {
      final endChapter = int.parse(endChapterGroup);
      final endVerse = int.parse(match.group(6)!);
      final verseStart = int.parse(match.group(3)!);
      if (endChapter > chapter) {
        return ParsedScriptureReference(
          book: match.group(1)!.trim(),
          chapter: chapter,
          verseStart: verseStart,
          verseEnd: endVerse,
          endChapter: endChapter,
        );
      }
      if (endChapter == chapter) {
        // "John 3:16-3:18" is a same-chapter range.
        return ParsedScriptureReference(
          book: match.group(1)!.trim(),
          chapter: chapter,
          verseStart: verseStart,
          verseEnd: endVerse,
        );
      }
      return null; // End before start
    }

    // If verse is not specified (chapter-only), fetch entire chapter (verses 1-999)
    final verseStart = match.group(3) != null ? int.parse(match.group(3)!) : 1;
    final verseEnd = match.group(4) != null
        ? int.parse(match.group(4)!)
        : (match.group(3) == null
            ? 999
            : null); // If chapter-only, fetch whole chapter; if single verse, fetch only that verse

    return ParsedScriptureReference(
      book: match.group(1)!.trim(),
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
    );
  }

  @override
  State<ScriptureVerseSheet> createState() => _ScriptureVerseSheetState();
}

class _ScriptureVerseSheetState extends State<ScriptureVerseSheet> {
  bool _isLoading = true;
  bool _isAddingToMemory = false;
  String? _verseText;
  String? _localizedReference;
  String? _errorMessage;
  String? _langCode; // language of the fetched verse, for in-context citation
  List<VerseItem>? _verses; // null = single verse, list = range

  bool _fetchStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here, not in initState: the kill-switch and parse-error paths
    // read translations synchronously, which needs inherited widgets.
    if (!_fetchStarted) {
      _fetchStarted = true;
      _fetchVerseText();
    }
  }

  Future<void> _fetchVerseText() async {
    // Guard: when the bible_content_enabled kill-switch is off, skip fetching
    // and show an "unavailable" message instead of verse text.
    if (!GetIt.instance<SystemConfigService>().isBibleContentEnabled) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            context.tr(TranslationKeys.verseSheetContentUnavailable);
      });
      return;
    }

    final fetchVerseText = GetIt.instance<FetchVerseText>();
    final languageService = GetIt.instance<LanguagePreferenceService>();
    final verseCache = GetIt.instance<VerseCacheService>();

    // Parse the reference
    final parsed = ScriptureVerseSheet.parseReference(widget.reference);
    if (parsed == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            '${context.tr(TranslationKeys.verseSheetCouldNotParse)}: ${widget.reference}';
      });
      return;
    }

    // Get current language — prefer study content language (set in Study Topics)
    // over app language, so verse displays in the same language as the study content
    final appLanguage = await languageService.getStudyContentLanguage();
    // The sheet may be dismissed while any await below is pending.
    if (!mounted) return;
    final langCode = appLanguage.code;
    _langCode = langCode;

    // Check cache first
    final cached = await verseCache.getCachedVerse(
      reference: widget.reference,
      language: langCode,
    );
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _isLoading = false;
        _verseText = cached.text;
        _localizedReference = cached.localizedReference;
        _verses = cached.verses
            ?.map((v) => VerseItem(
                number: v['number'] as int, text: v['text'] as String))
            .toList();
      });
      return;
    }

    // Normalize book name to canonical form (e.g., "Psalm" -> "Psalms")
    final normalizedBook = BibleBooks.normalizeBookName(parsed.book);

    // Fetch the verse text
    final result = await fetchVerseText(
      book: normalizedBook,
      chapter: parsed.chapter,
      verseStart: parsed.verseStart,
      verseEnd: parsed.verseEnd,
      endChapter: parsed.endChapter,
      language: langCode,
    );

    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = context.tr(TranslationKeys.verseSheetCouldNotLoad);
        });
      },
      (fetchedVerse) {
        // Save to cache for future opens
        verseCache.cacheVerse(
          reference: widget.reference,
          language: langCode,
          text: fetchedVerse.text,
          localizedReference: fetchedVerse.localizedReference,
          verses: fetchedVerse.verses
              ?.map((v) => {'number': v.number, 'text': v.text})
              .toList(),
        );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _verseText = fetchedVerse.text;
          _localizedReference = fetchedVerse.localizedReference;
          _verses = fetchedVerse.verses;
        });
      },
    );
  }

  /// Reference with the API.Bible translation abbreviation appended, e.g.
  /// "John 3:16 (KJV)". Links to the full copyright page via the citation badge.
  String _citedReference() {
    final ref = _localizedReference ?? widget.reference;
    final abbr = _langCode == null ? '' : bibleTranslationAbbr(_langCode!);
    return abbr.isEmpty ? ref : '$ref ($abbr)';
  }

  void _copyToClipboard() {
    if (_verseText != null && _localizedReference != null) {
      final abbr = _langCode == null ? '' : bibleTranslationAbbr(_langCode!);
      final cited =
          abbr.isEmpty ? _localizedReference : '$_localizedReference ($abbr)';
      // No per-verse page to link to from here, so this points at the
      // "get the app" page rather than the daily-verse card.
      final textToCopy = ShareLinks.verseMessage(
        citedReference: cited!,
        verseText: _verseText!,
        link: ShareLinks.download,
      );
      Clipboard.setData(ClipboardData(text: textToCopy));
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.verseSheetCopied),
        tone: AppSnackTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      // Max height so long passages scroll inside the sheet.
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85, // Max 85% of screen height
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar - fixed at top
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: palette.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Scrollable content area
            Flexible(
              child: SheetScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reference header: gold eyebrow over a Poppins title
                    PopupEyebrow(
                      context.tr(TranslationKeys.guideFeedbackVerseEyebrow),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _citedReference(),
                      style: AppFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Content area
                    if (_isLoading)
                      _buildLoadingState(palette)
                    else if (_errorMessage != null)
                      _buildErrorState(palette)
                    else
                      _buildVerseContent(palette),

                    const SizedBox(height: 20),

                    // Action buttons (only show when verse is loaded)
                    if (!_isLoading && _verseText != null)
                      _buildActionButtons(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ReaderPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: palette.accentIcon,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.verseSheetLoading),
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ReaderPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? context.tr(TranslationKeys.commonErrorTryAgain),
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _verseStyle(ReaderPalette palette) => AppFonts.inter(
        fontSize: 17,
        height: 1.7,
        letterSpacing: 0.2,
        color: palette.text,
      );

  Widget _buildVerseContent(ReaderPalette palette) {
    final hasMultipleVerses = _verses != null && _verses!.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opening quote mark
          Text(
            '"',
            style: AppFonts.poppins(
              fontSize: 36,
              color: palette.gold.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              height: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (hasMultipleVerses)
            ..._verses!.map((verse) => _buildVerseRow(verse, palette))
          else
            Text(_verseText ?? '', style: _verseStyle(palette)),
        ],
      ),
    );
  }

  Widget _buildVerseRow(VerseItem verse, ReaderPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verse number
          SizedBox(
            width: 28,
            child: Text(
              '${verse.number}',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.gold,
                height: 2.2,
              ),
            ),
          ),
          // Verse text
          Expanded(
            child: Text(verse.text, style: _verseStyle(palette)),
          ),
        ],
      ),
    );
  }

  void _generateStudyGuide() async {
    final languageService = GetIt.instance<LanguagePreferenceService>();
    final appLanguage = await languageService.getStudyContentLanguage();

    if (mounted) {
      Navigator.pop(context);
      final topic = _localizedReference ?? widget.reference;
      context.push(
        '${AppRoutes.studyGuideV2}?input=${Uri.encodeComponent(topic)}&type=topic&language=${appLanguage.code}',
      );
    }
  }

  Future<void> _addToMemoryVerses() async {
    if (_verseText == null || _isAddingToMemory) return;

    setState(() => _isAddingToMemory = true);

    final addVerseManually = GetIt.instance<AddVerseManually>();
    final languageService = GetIt.instance<LanguagePreferenceService>();
    final appLanguage = await languageService.getStudyContentLanguage();

    final result = await addVerseManually(
      verseReference: _localizedReference ?? widget.reference,
      verseText: _verseText!,
      language: appLanguage.code,
    );

    if (mounted) {
      setState(() => _isAddingToMemory = false);
      result.fold(
        (failure) {
          showAppSnackBar(
            context,
            '${context.tr(TranslationKeys.verseSheetFailedToAdd)}: ${failure.message}',
            tone: AppSnackTone.error,
          );
        },
        (_) {
          // Resolve the message before the sheet's context goes away.
          final message = context.tr(TranslationKeys.verseSheetAddedToMemory);
          final messengerContext =
              Navigator.of(context, rootNavigator: true).context;
          Navigator.pop(context);
          showAppSnackBar(messengerContext, message,
              tone: AppSnackTone.success);
        },
      );
    }
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Study: the main action
        PopupPrimaryButton(
          key: const Key('verse_sheet_study'),
          icon: Icons.auto_stories_rounded,
          label: context.tr(TranslationKeys.verseSheetStudy),
          onPressed: _generateStudyGuide,
        ),
        const SizedBox(height: 10),
        // Memory and Copy side by side, stacked when the labels don't fit.
        SettingsButtonRow(
          buttons: [
            SettingsButton(
              key: const Key('verse_sheet_memory'),
              icon: Icons.psychology_outlined,
              label: context.tr(TranslationKeys.verseSheetMemory),
              kind: SettingsButtonKind.neutral,
              loading: _isAddingToMemory,
              onPressed: _addToMemoryVerses,
            ),
            SettingsButton(
              key: const Key('verse_sheet_copy'),
              icon: Icons.copy_rounded,
              label: context.tr(TranslationKeys.verseSheetCopy),
              kind: SettingsButtonKind.neutral,
              onPressed: _copyToClipboard,
            ),
          ],
        ),
      ],
    );
  }
}

/// Internal class to hold parsed reference components.
/// Components of a scripture reference parsed by
/// [ScriptureVerseSheet.parseReference].
@visibleForTesting
class ParsedScriptureReference {
  final String book;
  final int chapter;
  final int verseStart;

  /// End verse; lies in [endChapter] when that is set.
  final int? verseEnd;

  /// End chapter of a cross-chapter range (e.g. 11 in "10:23-11:1").
  final int? endChapter;

  const ParsedScriptureReference({
    required this.book,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
    this.endChapter,
  });
}
