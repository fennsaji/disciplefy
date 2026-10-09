import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'scripture_verse_sheet.dart';
import '../../core/constants/app_fonts.dart';
import '../../core/constants/bible_books.dart';
import '../../core/theme/reader_palette.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/lru_memo.dart';

/// A widget that renders markdown content with clickable scripture references
/// Supports both block-level markdown (headings, lists) and inline markdown
/// while making scripture references tappable to view verses in a bottom sheet
class MarkdownWithScripture extends StatelessWidget {
  final String data;
  final TextStyle? textStyle;

  /// Creates a markdown renderer with clickable scripture references.
  ///
  /// The [data] parameter is required and contains the markdown text to render.
  /// Scripture references in the format "Book Chapter:Verse" (e.g., "John 3:16")
  /// are automatically converted to clickable links that open a bottom sheet
  /// showing the verse content.
  ///
  /// The optional [textStyle] parameter allows customizing the base text style
  /// for the rendered markdown. If not provided, defaults to theme.textTheme.bodyLarge.
  ///
  /// The [key] parameter is the standard widget key for identifying this widget
  /// in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// MarkdownWithScripture(
  ///   data: 'Read **John 3:16** for more details',
  ///   textStyle: TextStyle(fontSize: 16),
  /// )
  /// ```
  const MarkdownWithScripture({
    super.key,
    required this.data,
    this.textStyle,
  });

  /// Scripture reference pattern using canonical Bible book names from API
  /// Mirrors backend: supabase/functions/_shared/utils/bible-book-normalizer.ts
  /// Requires chapter number to avoid false matches (e.g., "Point 1")
  static final RegExp scripturePattern = BibleBooks.createScriptureRegex();

  /// Number of times markdown text was preprocessed (bullets + scripture
  /// links) rather than served from the memo. Counted in debug builds only.
  @visibleForTesting
  static int debugPreprocessCount = 0;

  /// Preprocessed markdown per source text. The scripture pattern is a large
  /// alternation over every book name in three languages, so running it over
  /// a long section on every rebuild (and every time a lazily built item
  /// scrolls back on screen) is the costly part of this widget.
  static final LruMemo<String, String> _preprocessed = LruMemo(
    capacity: 256,
    compute: (text) {
      assert(() {
        debugPreprocessCount++;
        return true;
      }());
      return _convertScriptureReferencesToLinks(
          _convertBulletsToMarkdown(text));
    },
  );

  static final RegExp _bulletLine = RegExp(r'^(\s*)•\s+(.+)$');

  /// Converts scripture references to markdown links
  static String _convertScriptureReferencesToLinks(String text) {
    return text.replaceAllMapped(scripturePattern, (match) {
      final reference = match.group(0)!;
      // Use anchor link format which flutter_markdown handles better
      // We'll detect this pattern in onTapLink
      return '[$reference](#scripture:${Uri.encodeComponent(reference)})';
    });
  }

  /// Converts bullet character (•) to markdown bullet syntax (-)
  /// flutter_markdown only recognizes -, *, or + as bullet markers
  static String _convertBulletsToMarkdown(String text) {
    // Split by lines to process each line
    final lines = text.split('\n');
    final convertedLines = lines.map((line) {
      // Match lines starting with • (with optional whitespace before)
      final bulletMatch = _bulletLine.firstMatch(line);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1) ?? '';
        final content = bulletMatch.group(2) ?? '';
        // Convert to markdown bullet format
        return '$indent- $content';
      }
      return line;
    }).toList();

    return convertedLines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    // Process the data: convert bullets to markdown format, then convert scripture references to links
    final processedData = _preprocessed(data);

    // Create a unique key based on content and theme to force rebuilds when colors change
    final linkColor = ReaderPalette.of(context).accentIcon;
    final uniqueKey = ValueKey('${data.hashCode}-${linkColor.toARGB32()}');

    return MarkdownBody(
      key: uniqueKey,
      data: processedData,
      selectable: true,
      extensionSet:
          md.ExtensionSet.gitHubFlavored, // Enable full markdown support
      styleSheet: _buildStyleSheet(context),
      onTapLink: (text, href, title) {
        // Handle scripture reference clicks
        if (href != null && href.startsWith('#scripture:')) {
          final encodedRef = href.replaceFirst('#scripture:', '');
          final reference = Uri.decodeComponent(encodedRef);
          ScriptureVerseSheet.show(context, reference: reference);
        } else if (href != null) {
          // Handle regular links if any
          Logger.debug('Regular link tapped: $href');
        }
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ReaderPalette.of(context);
    final baseStyle = textStyle ?? theme.textTheme.bodyLarge;
    final linkColor = palette.accentIcon;

    TextStyle heading(double size, FontWeight weight) => AppFonts.poppins(
          fontSize: size,
          fontWeight: weight,
          color: palette.text,
          height: 1.3,
        );

    return MarkdownStyleSheet(
      p: baseStyle?.copyWith(
        color: palette.text,
        height: 1.6,
      ),
      h1: heading(24, FontWeight.w700),
      h2: heading(20, FontWeight.w700),
      h3: heading(18, FontWeight.w600),
      h4: heading(18, FontWeight.w600),
      h5: heading(16, FontWeight.w500),
      h6: heading(14, FontWeight.w500),
      listBullet: baseStyle?.copyWith(
        color: palette.accentIcon,
      ),
      listIndent: 24,
      blockquote: baseStyle?.copyWith(
        color: palette.muted,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: palette.accentIcon,
            width: 4,
          ),
        ),
      ),
      code: baseStyle?.copyWith(
        fontFamily: 'monospace',
        color: palette.text,
        backgroundColor: palette.raised,
      ),
      // Style for scripture reference links
      a: baseStyle?.copyWith(
        color: linkColor,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(
          alpha: palette.isDark ? 0.6 : 0.5,
        ),
      ),
    );
  }
}
