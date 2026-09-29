import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plain text of every laid-out paragraph on screen that is cut off: it hit
/// its `maxLines` (and so shows an ellipsis or clips) or is painted narrower
/// than its single-line intrinsic width while not allowed to wrap.
///
/// Paragraphs whose text contains any of [allow] are skipped (user content
/// that is meant to ellipsize, e.g. a guide title), as are paragraphs inside
/// any widget found by [ignoreUnder] (e.g. a miniature illustration).
List<String> truncatedTexts(
  WidgetTester tester, {
  Set<String> allow = const {},
  List<Finder> ignoreUnder = const [],
}) {
  final ignored = <RenderParagraph>{
    for (final scope in ignoreUnder)
      ...tester.renderObjectList<RenderParagraph>(
          find.descendant(of: scope, matching: find.byType(RichText))),
  };
  final cut = <String>[];
  for (final paragraph
      in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    if (ignored.contains(paragraph)) continue;
    if (!paragraph.hasSize || paragraph.size.isEmpty) continue;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    if (allow.any(text.contains)) continue;
    final clipsSingleLine = !paragraph.softWrap &&
        paragraph.size.width + 0.5 <
            paragraph.getMaxIntrinsicWidth(double.infinity);
    if (paragraph.didExceedMaxLines || clipsSingleLine) cut.add(text);
  }
  return cut;
}

/// Fails when any on-screen text is cut off (see [truncatedTexts]).
void expectNoTruncatedText(
  WidgetTester tester, {
  Set<String> allow = const {},
  List<Finder> ignoreUnder = const [],
}) {
  final cut = truncatedTexts(tester, allow: allow, ignoreUnder: ignoreUnder);
  expect(cut, isEmpty, reason: 'Cut-off text: $cut');
}

/// Registers the bundled Inter and Poppins so text is measured with the real
/// Latin metrics instead of the square test glyphs (~1.8x wider). Hindi and
/// Malayalam glyphs are not in these fonts and still fall back to the square
/// test font, which is wider than any real Indic font — a stress test.
///
/// Call from `setUpAll`.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await load('Poppins', [
    'Poppins-Regular.ttf',
    'Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf',
    'Poppins-Bold.ttf',
  ]);
}
