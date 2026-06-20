/// API.Bible in-context citation helper.
///
/// Returns the translation abbreviation to show next to a verse reference:
/// English = King James Version (KJV); Hindi/Malayalam = Indian Revised Version
/// (IRV). Returns an empty string for unknown languages so callers can omit the
/// citation. Full copyright notices live in the Bible Attribution screen.
String bibleTranslationAbbr(String languageCode) {
  final code = languageCode.toLowerCase();
  if (code.startsWith('en')) return 'KJV';
  if (code.startsWith('hi') || code.startsWith('ml')) return 'IRV';
  return '';
}
