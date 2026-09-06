// Pure text-manipulation helpers for the `@mention` composer feature.
//
// Kept free of Flutter/BuildContext dependencies so they're trivially unit
// testable; `showMentionSheet` in `mention_sheet.dart` is the widget-facing
// counterpart that calls into these.

/// Result of inserting a mention handle into some text: the new text and
/// where the cursor should land afterward.
class MentionInsertion {
  final String text;
  final int cursor;
  const MentionInsertion(this.text, this.cursor);
}

/// True when the character just typed at [cursor] in [text] is an `'@'` that
/// starts a fresh mention — i.e. it's at the very start of the text, or the
/// character before it is whitespace.
bool shouldOpenMentionSheet(String text, int cursor) {
  if (cursor < 1 || cursor > text.length || text[cursor - 1] != '@') {
    return false;
  }
  return cursor == 1 || text[cursor - 2].trim().isEmpty;
}

/// Inserts [handle] (e.g. `'@Discipler'`) into [text] at [cursor].
///
/// If there's a trailing partial mention token (`@word`) immediately before
/// the cursor, it is replaced by [handle]. Otherwise [handle] is inserted at
/// the cursor position, padded with spaces.
MentionInsertion insertMention(String text, int cursor, String handle) {
  final before = text.substring(0, cursor);
  final after = text.substring(cursor);
  final m = RegExp(r'(^|\s)@[\w.]*$').firstMatch(before);
  final head = m == null
      ? '$before '
      : before.substring(0, m.start) + (m.group(1) ?? '');
  final next = '$head$handle $after';
  return MentionInsertion(next, head.length + handle.length + 1);
}
