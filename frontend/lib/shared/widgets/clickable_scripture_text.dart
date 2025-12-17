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
  /// Uses a whitelist approach for Hindi Bible book names to avoid false positives.
  /// Multi-word book names (भजन संहिता, प्रेरितों के काम) are listed explicitly.
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
