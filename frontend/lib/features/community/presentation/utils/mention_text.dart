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

/// Remembers which account each inserted `@Handle` referred to, so the
/// composer can tell the backend exactly who was tagged.
///
/// Handles are display names with the spaces replaced, which are neither
/// unique nor stable, so the id is captured at insertion time rather than
/// resolved from the text afterwards. Only handles still present in the text
/// when the message is sent are reported — deleting a mention un-tags the
/// person.
class MentionTracker {
  final Map<String, String> _idsByHandle = {};

  /// Records that [handle] was inserted for [userId].
  void remember(String handle, String? userId) {
    if (userId != null && userId.isNotEmpty) {
      _idsByHandle[handle] = userId;
    }
  }

  /// The ids of everyone still tagged in [text].
  List<String> idsIn(String text) => _idsByHandle.entries
      .where((e) => text.contains(e.key))
      .map((e) => e.value)
      .toSet()
      .toList();

  /// Forgets every recorded mention (after a successful send).
  void clear() => _idsByHandle.clear();
}
