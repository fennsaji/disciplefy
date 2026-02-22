import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'scripture_verse_sheet.dart';
import '../../core/constants/bible_books.dart';

/// A widget that renders text with clickable scripture references.
///
/// Parses the input text for Bible verse references (e.g., "John 3:16",
/// "1 John 3:16-17", "Genesis 1:1") and makes them tappable. When tapped,
/// displays the [ScriptureVerseSheet] bottom sheet with the verse text.
class ClickableScriptureText extends StatefulWidget {
  /// The text content to parse and render.
  final String text;

  /// The base text style to apply.
  final TextStyle? style;

  /// Whether to use [SelectableText.rich] instead of [RichText].
  /// Defaults to true for study guide content.
  final bool selectable;

  /// Text alignment for the rendered text.
  final TextAlign textAlign;

  /// Maximum lines to display before truncating.
  final int? maxLines;

  /// How overflowing text should be handled.
  final TextOverflow? overflow;

  const ClickableScriptureText({
    super.key,
    required this.text,
    this.style,
    this.selectable = true,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  /// Regex pattern to match scripture references in English, Hindi, and Malayalam.
  ///
  /// Uses [BibleBooks.createScriptureRegex()] as the single source of truth,
  /// matching all canonical names and alternates maintained in [BibleBooks].
  /// This stays in sync with [MarkdownWithScripture] and the backend normalizer.
  static final RegExp scripturePattern = BibleBooks.createScriptureRegex();

  @override
  State<ClickableScriptureText> createState() => _ClickableScriptureTextState();
}

class _ClickableScriptureTextState extends State<ClickableScriptureText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ClickableScriptureText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Clear old recognizers when text changes
      for (final recognizer in _recognizers) {
        recognizer.dispose();
      }
      _recognizers.clear();
    }
  }

  /// Parse markdown formatting and build text spans with both markdown styling
  /// and clickable scripture references.
  ///
  /// Handles block-level markdown (headings, bullets) and inline markdown (bold, italic).
  List<InlineSpan> _buildTextSpans(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

    // Full-opacity primary so links match the AppBar title brightness exactly.
    final scriptureColor = theme.colorScheme.primary;

    // Split text into lines to handle block-level markdown
    final lines = widget.text.split('\n');
    final List<InlineSpan> allSpans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Skip empty lines
      if (trimmedLine.isEmpty) {
        if (i > 0) {
          allSpans.add(const TextSpan(text: '\n'));
        }
        continue;
      }

      // Check if this is a heading (bold text on its own line)
      final headingMatch = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(trimmedLine);
      if (headingMatch != null) {
        // Heading style
        final headingStyle = (baseStyle ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
          fontSize: (baseStyle?.fontSize ?? 16) * 1.15,
        );

        if (i > 0) allSpans.add(const TextSpan(text: '\n\n'));

        allSpans.addAll(_parseMarkdownAndScripture(
          headingMatch.group(1)!,
          context,
          headingStyle,
          scriptureColor,
        ));

        allSpans.add(const TextSpan(text: '\n'));
        continue;
      }

      // Check if this is a bullet point (•, -, or * at start)
      final bulletMatch = RegExp(r'^([•\-\*])\s+(.+)$').firstMatch(trimmedLine);
      if (bulletMatch != null) {
        // Bullet point style with indentation
        if (i > 0) allSpans.add(const TextSpan(text: '\n'));

        final bulletChar =
            bulletMatch.group(1) == '•' ? '•' : '•'; // Normalize to •
        final bulletContent = bulletMatch.group(2)!;

        // Add bullet with indentation
        allSpans.add(TextSpan(
          text: '  $bulletChar  ',
          style: baseStyle?.copyWith(fontWeight: FontWeight.bold),
        ));

        // Parse the content after the bullet
        allSpans.addAll(_parseMarkdownAndScripture(
          bulletContent,
          context,
          baseStyle,
          scriptureColor,
        ));

        continue;
      }

      // Regular line - parse inline markdown
      if (i > 0) allSpans.add(const TextSpan(text: '\n'));

      allSpans.addAll(_parseMarkdownAndScripture(
        line,
        context,
        baseStyle,
        scriptureColor,
      ));
    }

    return allSpans;
  }

  /// Recursively parse markdown formatting and scripture references
  List<InlineSpan> _parseMarkdownAndScripture(
    String text,
    BuildContext context,
    TextStyle? baseStyle,
    Color scriptureColor,
  ) {
    final List<InlineSpan> spans = [];

    // Markdown patterns (ordered by precedence)
    final patterns = [
      // Bold + Italic: ***text*** or **_text_** or _**text**_
      RegExp(r'\*\*\*(.+?)\*\*\*'),
      RegExp(r'\*\*_(.+?)_\*\*'),
      RegExp(r'_\*\*(.+?)\*\*_'),
      // Bold: **text** or __text__
      RegExp(r'\*\*(.+?)\*\*'),
      RegExp(r'__(.+?)__'),
      // Italic: *text* or _text_
      RegExp(r'\*(.+?)\*'),
      RegExp(r'_(.+?)_'),
      // Code: `code`
      RegExp(r'`([^`]+)`'),
    ];

    int currentIndex = 0;

    // Find the earliest markdown or scripture pattern
    while (currentIndex < text.length) {
      int? earliestStart;
      Match? earliestMatch;
      String? patternType;

      // Check all markdown patterns
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text.substring(currentIndex));
        if (match != null) {
          final absoluteStart = currentIndex + match.start;
          if (earliestStart == null || absoluteStart < earliestStart) {
            earliestStart = absoluteStart;
            earliestMatch = match;
            patternType = 'markdown';
          }
        }
      }

      // Check scripture pattern
      final scriptureMatch = ClickableScriptureText.scripturePattern
          .firstMatch(text.substring(currentIndex));
      if (scriptureMatch != null) {
        final absoluteStart = currentIndex + scriptureMatch.start;
        if (earliestStart == null || absoluteStart < earliestStart) {
          earliestStart = absoluteStart;
          earliestMatch = scriptureMatch;
          patternType = 'scripture';
        }
      }

      // No more patterns found
      if (earliestMatch == null || earliestStart == null) {
        // Add remaining text
        if (currentIndex < text.length) {
          spans.add(TextSpan(
            text: text.substring(currentIndex),
            style: baseStyle,
          ));
        }
        break;
      }

      // Add text before the match
      if (earliestStart > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, earliestStart),
          style: baseStyle,
        ));
      }

      if (patternType == 'scripture') {
        // Handle scripture reference
        final reference = earliestMatch.group(0)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _onScriptureTap(context, reference);
        _recognizers.add(recognizer);

        final dark = Theme.of(context).brightness == Brightness.dark;
        final scriptureStyle = (baseStyle ?? const TextStyle()).copyWith(
          color: scriptureColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: dark
              ? scriptureColor.withOpacity(0.6)
              : scriptureColor.withOpacity(0.5),
          decorationStyle:
              dark ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
        );

        spans.add(TextSpan(
          text: reference,
          style: scriptureStyle,
          recognizer: recognizer,
        ));
      } else {
        // Handle markdown formatting
        final fullMatch = earliestMatch.group(0)!;
        final innerText = earliestMatch.group(1)!;

        TextStyle styledText = baseStyle ?? const TextStyle();

        // Determine markdown type and apply styling
        if (fullMatch.startsWith('***') ||
            fullMatch.startsWith('**_') ||
            fullMatch.startsWith('_**')) {
          // Bold + Italic
          styledText = styledText.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          );
        } else if (fullMatch.startsWith('**') || fullMatch.startsWith('__')) {
          // Bold
          styledText = styledText.copyWith(fontWeight: FontWeight.bold);
        } else if (fullMatch.startsWith('*') || fullMatch.startsWith('_')) {
          // Italic
          styledText = styledText.copyWith(fontStyle: FontStyle.italic);
        } else if (fullMatch.startsWith('`')) {
          // Code
          styledText = styledText.copyWith(
            fontFamily: 'monospace',
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            fontSize: (styledText.fontSize ?? 14) * 0.9,
          );
        }

        // Recursively parse the inner text for nested formatting
        final innerSpans = _parseMarkdownAndScripture(
          innerText,
          context,
          styledText,
          scriptureColor,
        );

        spans.addAll(innerSpans);
      }

      currentIndex = earliestStart + earliestMatch.group(0)!.length;
    }

    return spans;
  }

  void _onScriptureTap(BuildContext context, String reference) {
    ScriptureVerseSheet.show(context, reference: reference);
  }

  @override
  Widget build(BuildContext context) {
    // Clear and rebuild recognizers on each build
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = _buildTextSpans(context);

    if (widget.selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
