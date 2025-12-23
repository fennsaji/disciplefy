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
  /// **Design Note**: Uses a whitelist approach with explicit book names to avoid
  /// false positives like "Section 3:16" or "Room 1:30". This is intentionally
  /// stricter than [InputValidationService.isValidScripture] which uses a generic
  /// Unicode pattern for input validation (more lenient to accept user input).
  ///
  /// Multi-word book names (भजन संहिता, प्रेरितों के काम) are listed explicitly
  /// before single-word patterns to ensure correct matching.
  static final RegExp scripturePattern = RegExp(
    r'('
    r'(?:\d\s?)?' // Optional number prefix like "1 " or "1" for numbered books
    r'(?:'
    // English: Genesis, Song of Solomon, 1 John
    r'[A-Z][a-z]{2,}(?:\s(?:of\s)?[A-Z][a-z]+)?'
    r'|'
    // Hindi multi-word book names (must be listed before single-word pattern)
    r'भजन संहिता|प्रेरितों के काम|श्रेष्ठगीत'
    r'|'
    // Hindi single-word book names - common Bible books
    r'(?:उत्पत्ति|निर्गमन|लैव्यव्यवस्था|गिनती|व्यवस्थाविवरण|'
    r'यहोशू|न्यायियों|रूत|शमूएल|राजा|इतिहास|एज्रा|नहेम्याह|एस्तेर|अय्यूब|'
    r'भजन|नीतिवचन|सभोपदेशक|यशायाह|यिर्मयाह|विलापगीत|यहेजकेल|दानिय्येल|'
    r'होशे|योएल|आमोस|ओबद्याह|योना|मीका|नहूम|हबक्कूक|सपन्याह|हाग्गै|जकर्याह|मलाकी|'
    r'मत्ती|मरकुस|लूका|यूहन्ना|प्रेरितों|रोमियों|कुरिन्थियों|गलातियों|इफिसियों|'
    r'फिलिप्पियों|कुलुस्सियों|थिस्सलुनीकियों|तीमुथियुस|तीतुस|फिलेमोन|इब्रानियों|'
    r'याकूब|पतरस|यहूदा|प्रकाशितवाक्य)'
    r'|'
    // Malayalam multi-word book names
    r'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ|ഉത്തമഗീതം'
    r'|'
    // Malayalam single-word book names - common Bible books
    r'(?:ഉല്പത്തി|പുറപ്പാട്|ലേവ്യപുസ്തകം|സംഖ്യ|ആവർത്തനം|'
    r'യോശുവ|ന്യായാധിപന്മാർ|രൂത്ത്|ശമൂവേൽ|രാജാക്കന്മാർ|ദിനവൃത്താന്തം|'
    r'എസ്രാ|നെഹെമ്യാവ്|എസ്ഥേർ|ഇയ്യോബ്|സങ്കീർത്തനങ്ങൾ|സദൃശ്യവാക്യങ്ങൾ|'
    r'സഭാപ്രസംഗി|യെശയ്യാവ്|യിരെമ്യാവ്|വിലാപങ്ങൾ|യെഹെസ്കേൽ|ദാനിയേൽ|'
    r'ഹോശേയ|യോവേൽ|ആമോസ്|ഓബദ്യാവ്|യോനാ|മീഖാ|നഹൂം|ഹബക്കൂക്ക്|സെഫന്യാവ്|'
    r'ഹഗ്ഗായി|സെഖര്യാവ്|മലാഖി|മത്തായി|മർക്കൊസ്|ലൂക്കൊസ്|യോഹന്നാൻ|'
    r'റോമർ|കൊരിന്ത്യർ|ഗലാത്യർ|എഫെസ്യർ|ഫിലിപ്പിയർ|കൊലൊസ്സ്യർ|'
    r'തെസ്സലൊനീക്യർ|തിമൊഥെയൊസ്|തീത്തൊസ്|ഫിലേമോൻ|എബ്രായർ|യാക്കോബ്|'
    r'പത്രൊസ്|യൂദാ|വെളിപ്പാട്)'
    r')'
    r')'
    r'\s+(\d+)(?::(\d+)(?:-(\d+))?)?', // Matches "Book 23" or "Book 23:1" or "Book 23:1-6"
    unicode: true,
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

  /// Parse markdown formatting and build text spans with both markdown styling
  /// and clickable scripture references.
  List<InlineSpan> _buildTextSpans(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

    // Use tertiary color for dark mode (lighter purple), primary for light mode
    final scriptureColor =
        isDark ? theme.colorScheme.tertiary : theme.colorScheme.primary;

    // Parse markdown and scripture in the text
    return _parseMarkdownAndScripture(
      widget.text,
      context,
      baseStyle,
      scriptureColor,
    );
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

        final scriptureStyle = (baseStyle ?? const TextStyle()).copyWith(
          color: scriptureColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: scriptureColor.withOpacity(0.5),
          decorationStyle: TextDecorationStyle.dotted,
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
