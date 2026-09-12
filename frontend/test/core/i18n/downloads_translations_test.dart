import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';

/// Guards the download-sheet strings: every language must define the same
/// keys, and every placeholder must be one the call site actually supplies.
void main() {
  Map<String, dynamic> downloadsFor(AppLanguage lang) =>
      (AppTranslations.translations[lang]!['downloads']
          as Map<String, dynamic>);

  test('every language defines the same downloads keys', () {
    final en = downloadsFor(AppLanguage.english).keys.toSet();
    for (final lang in [AppLanguage.hindi, AppLanguage.malayalam]) {
      expect(downloadsFor(lang).keys.toSet(), en,
          reason: '${lang.code} download strings are out of step with English');
    }
  });

  test('placeholders match the arguments the call sites pass', () {
    const allowed = {
      'downloading_progress': {'done', 'total'},
      'partly_downloaded': {'done', 'missing'},
      'all_available_offline': {'total'},
      'download_more': {'count'},
      'download_count': {'count'},
      'download_count_with_cost': {'count', 'cost'},
      'guides_with_cost': {'count', 'cost'},
      'guides_selected': {'count'},
    };
    final re = RegExp(r'\{(\w+)\}');

    for (final lang in AppLanguage.values) {
      downloadsFor(lang).forEach((key, value) {
        final found =
            re.allMatches(value as String).map((m) => m.group(1)!).toSet();
        expect(found, allowed[key] ?? <String>{},
            reason: '${lang.code} "$key" uses unexpected placeholders');
      });
    }
  });
}
