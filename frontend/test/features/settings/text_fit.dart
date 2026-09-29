import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails if any laid-out text on screen was cut short by its `maxLines`
/// (the "Cl…" / "Show An…" kind of truncation). [allowed] lists user
/// content (names, emails) that may ellipsize by design.
void expectNoTruncatedText(WidgetTester tester,
    {Set<String> allowed = const {}}) {
  final truncated = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph &&
        renderObject.hasSize &&
        renderObject.didExceedMaxLines &&
        !allowed.contains(renderObject.text.toPlainText())) {
      truncated.add(renderObject.text.toPlainText());
    }
  }
  expect(truncated, isEmpty, reason: 'Truncated text: $truncated');
}

/// Asserts [label] is on screen and every copy of it is shown in full.
void expectFullLabel(WidgetTester tester, String label) {
  final finder = find.text(label);
  expect(finder, findsWidgets, reason: 'Label "$label" not found');
  final paragraphs = find.descendant(
      of: finder, matching: find.byType(RichText), matchRoot: true);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: 'Label "$label" is truncated');
  }
}
