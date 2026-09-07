// Pure text helpers for rendering community content as plain text.
//
// Kept free of Flutter/BuildContext dependencies so they're trivially unit
// testable.

/// `**bold**` → `bold`
final _bold = RegExp(r'\*\*(?!\s)([^*\n]+?)(?<!\s)\*\*');

/// `*italic*` → `italic`
final _italicStar = RegExp(r'\*(?!\s)([^*\n]+?)(?<!\s)\*');

/// `_italic_` → `italic`, but only when the underscores sit on a word
/// boundary, so `snake_case_names` survive untouched.
final _italicUnderscore =
    RegExp(r'(?<![A-Za-z0-9_])_(?!\s)([^_\n]+?)(?<!\s)_(?![A-Za-z0-9_])');

/// Strips leftover markdown emphasis markers so text renders cleanly in a
/// plain [Text] widget.
///
/// Discipler answers are meant to be plain prose (the LLM prompt says so), but
/// text already stored can still carry emphasis markers. This removes them for
/// display:
///
/// - `**bold**` → `bold`
/// - `*italic*` → `italic`
/// - `_italic_` → `italic`
///
/// Other asterisks and underscores are left alone — a lone `*`, a bullet
/// character with no closing marker, and `snake_case` words are unchanged.
String stripEmphasisMarkers(String text) => text
    .replaceAllMapped(_bold, (m) => m.group(1)!)
    .replaceAllMapped(_italicStar, (m) => m.group(1)!)
    .replaceAllMapped(_italicUnderscore, (m) => m.group(1)!);
