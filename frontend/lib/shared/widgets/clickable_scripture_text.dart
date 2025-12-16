import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'scripture_verse_sheet.dart';

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
  /// Matches formats like:
  /// - English: "John 3:16", "1 John 3:16", "Song of Solomon 2:4"
  /// - Hindi: "यूहन्ना 3:16", "1 यूहन्ना 1:1", "उत्पत्ति 1:1"
  /// - Malayalam: "യോഹന്നാൻ 3:16", "മത്തായി 5:16"
  ///
  /// Note: English book names must be at least 3 characters (shortest is "Job")
  /// to avoid matching words like "In" before the actual reference.
  static final RegExp scripturePattern = RegExp(
    r'('
    r'(?:\d\s)?' // Optional number prefix like "1 " for numbered books
    r'(?:'
    r'[A-Z][a-z]{2,}(?:\s(?:of\s)?[A-Z][a-z]+)?' // English: Genesis, Song of Solomon
    r'|'
    r'[\u0900-\u097F]+' // Hindi (Devanagari script)
    r'|'
    r'[\u0D00-\u0D7F]+' // Malayalam script
    r')'
    r')'
    r'\s+(\d+):(\d+)(?:-(\d+))?',
  );

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

  List<InlineSpan> _buildTextSpans(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<InlineSpan> spans = [];

    // Style for scripture references
    final scriptureStyle = (widget.style ?? const TextStyle()).copyWith(
      color: isDark ? const Color(0xFFB8A9F0) : theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor:
          (isDark ? const Color(0xFFB8A9F0) : theme.colorScheme.primary)
              .withOpacity(0.5),
      decorationStyle: TextDecorationStyle.dotted,
    );

    // Find all matches
    final matches =
        ClickableScriptureText.scripturePattern.allMatches(widget.text);

    if (matches.isEmpty) {
      // No scripture references found, return plain text
      return [TextSpan(text: widget.text, style: widget.style)];
    }

    int currentIndex = 0;

    for (final match in matches) {
      // Add text before this match
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex, match.start),
          style: widget.style,
        ));
      }

      // Create the scripture reference
      final reference = match.group(0)!;

      // Create a tap recognizer for this reference
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _onScriptureTap(context, reference);
      _recognizers.add(recognizer);

      // Add the styled, tappable scripture reference
      spans.add(TextSpan(
        text: reference,
        style: scriptureStyle,
        recognizer: recognizer,
      ));

      currentIndex = match.end;
    }

    // Add any remaining text after the last match
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(currentIndex),
        style: widget.style,
      ));
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
