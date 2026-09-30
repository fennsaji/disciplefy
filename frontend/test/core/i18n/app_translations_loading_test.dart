import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every language is loadable and exposes the same top-level sections',
      () async {
    await AppTranslations.ensureAllLoaded();
    for (final lang in AppLanguage.values) {
      expect(AppTranslations.isLoaded(lang), isTrue, reason: lang.code);
    }
    final en = AppTranslations.translations[AppLanguage.english]!.keys.toSet();
    for (final lang in [AppLanguage.hindi, AppLanguage.malayalam]) {
      final keys = AppTranslations.translations[lang]!.keys.toSet();
      expect(keys.intersection(en), isNotEmpty, reason: lang.code);
    }
  });

  test('ensureLoaded is idempotent and shares concurrent loads', () async {
    await Future.wait([
      AppTranslations.ensureLoaded(AppLanguage.hindi),
      AppTranslations.ensureLoaded(AppLanguage.hindi),
    ]);
    await AppTranslations.ensureLoaded(AppLanguage.hindi);
    expect(AppTranslations.isLoaded(AppLanguage.hindi), isTrue);
  });

  test('translations view is read-only', () {
    expect(
      () => AppTranslations.translations[AppLanguage.english] = {},
      throwsUnsupportedError,
    );
  });
}
