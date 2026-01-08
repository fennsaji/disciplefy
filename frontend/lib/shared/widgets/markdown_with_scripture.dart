import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'scripture_verse_sheet.dart';
import '../../core/constants/bible_books.dart';

/// A widget that renders markdown content with clickable scripture references
/// Supports both block-level markdown (headings, lists) and inline markdown
/// while making scripture references tappable to view verses in a bottom sheet
class MarkdownWithScripture extends StatelessWidget {
  final String data;
  final TextStyle? textStyle;

  const MarkdownWithScripture({
    super.key,
    required this.data,
    this.textStyle,
  });

  /// Scripture reference pattern using canonical Bible book names from API
  /// Mirrors backend: supabase/functions/_shared/utils/bible-book-normalizer.ts
  /// Requires chapter number to avoid false matches (e.g., "Point 1")
  static final RegExp scripturePattern = BibleBooks.createScriptureRegex();

  /// Converts scripture references to markdown links
  String _convertScriptureReferencesToLinks(String text) {
    return text.replaceAllMapped(scripturePattern, (match) {
      final reference = match.group(0)!;
      // Use anchor link format which flutter_markdown handles better
      // We'll detect this pattern in onTapLink
      return '[$reference](#scripture:${Uri.encodeComponent(reference)})';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Process the data to convert scripture references to clickable markdown links
    final processedData = _convertScriptureReferencesToLinks(data);

    return MarkdownBody(
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ScriptureVerseSheet(
              reference: reference,
            ),
          );
        } else if (href != null) {
          // Handle regular links if any
          debugPrint('Regular link tapped: $href');
        }
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = textStyle ?? theme.textTheme.bodyLarge;

    return MarkdownStyleSheet(
      p: baseStyle?.copyWith(
        color: theme.colorScheme.onBackground,
        height: 1.6,
      ),
      h1: theme.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onBackground,
      ),
      h2: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onBackground,
      ),
      h3: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onBackground,
      ),
      h4: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onBackground,
      ),
      h5: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onBackground,
      ),
      h6: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onBackground,
      ),
      listBullet: baseStyle?.copyWith(
        color: theme.colorScheme.primary,
      ),
      listIndent: 24,
      blockquote: baseStyle?.copyWith(
        color: theme.colorScheme.onBackground.withOpacity(0.7),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      code: baseStyle?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      // Style for scripture reference links
      a: baseStyle?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
    );
  }
}
