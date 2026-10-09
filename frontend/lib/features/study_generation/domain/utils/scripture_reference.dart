/// Book (letters and combining marks, so Hindi and Malayalam work; may be
/// several words like "भजन संहिता" or "Song of Solomon", with an optional
/// 1–3 prefix) followed by a chapter and an optional verse or verse range.
final RegExp _scriptureReference = RegExp(
  r'^[1-3]?\s*[\p{L}\p{M}]+(?:\s+[\p{L}\p{M}]+)*\s+\d+(?::\d+(?:-\d+)?)?$',
  unicode: true,
);

/// Whether [text] has the shape of a scripture reference ("John 3:16",
/// "Psalm 23", "यूहन्ना 3:16"). The check the Generate tab runs before it
/// sends an input as type scripture.
bool isScriptureReference(String text) =>
    _scriptureReference.hasMatch(text.trim());
