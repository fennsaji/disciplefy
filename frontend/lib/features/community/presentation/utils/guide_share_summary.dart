/// Longest summary a shared study guide post carries. The server caps the
/// stored summary at the same length.
const int kSharedGuideSummaryMaxLength = 280;

final RegExp _markdownLink = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final RegExp _markdownMarks = RegExp(r'[*_`#>~|]');
final RegExp _listMarker = RegExp(r'^\s*(?:[-+]|\d+[.)])\s+', multiLine: true);
final RegExp _whitespace = RegExp(r'\s+');

/// Sentence ends: Latin punctuation and the Devanagari danda.
final RegExp _sentenceEnd = RegExp(r'(?<=[.!?।])\s+');

/// Condenses a guide's summary section into the short plain-text preview a
/// shared guide post shows: markdown removed, the first [maxSentences]
/// sentences, at most [maxLength] characters (cut on a word boundary with an
/// ellipsis). Returns null when there is nothing to show.
String? condenseGuideSummary(
  String? raw, {
  int maxSentences = 2,
  int maxLength = kSharedGuideSummaryMaxLength,
}) {
  if (raw == null) return null;
  final plain = raw
      .replaceAllMapped(_markdownLink, (m) => m.group(1) ?? '')
      .replaceAll(_listMarker, '')
      .replaceAll(_markdownMarks, '')
      .replaceAll(_whitespace, ' ')
      .trim();
  if (plain.isEmpty) return null;

  final sentences = plain.split(_sentenceEnd);
  final picked = sentences.take(maxSentences).join(' ').trim();
  if (picked.length <= maxLength) return picked;

  final cut = picked.substring(0, maxLength - 1);
  final lastSpace = cut.lastIndexOf(' ');
  final head = lastSpace > maxLength ~/ 2 ? cut.substring(0, lastSpace) : cut;
  return '${head.trimRight()}…';
}
