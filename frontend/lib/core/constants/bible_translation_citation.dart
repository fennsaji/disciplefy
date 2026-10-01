/// In-context Bible citation helper.
///
/// Returns the translation abbreviation to show next to a verse reference:
/// English = Berean Standard Bible (BSB); Hindi/Malayalam = Indian Revised Version
/// (IRV). Returns an empty string for unknown languages so callers can omit the
/// citation. Full copyright notices live in the Bible Attribution screen.
String bibleTranslationAbbr(String languageCode) {
  final code = languageCode.toLowerCase();
  if (code.startsWith('en')) return 'BSB';
  if (code.startsWith('hi') || code.startsWith('ml')) return 'IRV';
  return '';
}

/// Short licence line shown under verse text for translations that require
/// attribution (the CC BY-SA 4.0 Indian Revised Version for Hindi/Malayalam).
/// Returns null when none is needed (English BSB / KJV are public domain).
String? bibleTranslationNotice(String languageCode) {
  final code = languageCode.toLowerCase();
  if (code.startsWith('hi') || code.startsWith('ml')) {
    return 'IRV © Bridge Connectivity Solutions · CC BY-SA 4.0';
  }
  return null;
}
