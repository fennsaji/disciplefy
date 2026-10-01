import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/verse_cache_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/fetched_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/fetch_verse_text.dart';
import 'package:disciplefy_bible_study/shared/widgets/scripture_verse_sheet.dart';

class _Lang extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();
  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
  @override
  Future<AppLanguage> getStudyContentLanguage() async => AppLanguage.english;
}

class _Config extends Fake implements SystemConfigService {
  @override
  bool get isBibleContentEnabled => true;
}

class _NoCache extends Fake implements VerseCacheService {
  @override
  Future<CachedVerseData?> getCachedVerse({
    required String reference,
    required String language,
  }) async =>
      null;
  @override
  Future<void> cacheVerse({
    required String reference,
    required String language,
    required String text,
    required String localizedReference,
    List<Map<String, dynamic>>? verses,
  }) async {}
}

class _Fetch extends Fake implements FetchVerseText {
  _Fetch(this.verses);
  final List<VerseItem> verses;

  @override
  Future<Either<Failure, FetchedVerseEntity>> call({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    int? endChapter,
    required String language,
  }) async =>
      Right(FetchedVerseEntity(
        text: verses.map((v) => v.text).join(' '),
        localizedReference: 'ref',
        verses: verses,
      ));
}

Future<void> _open(WidgetTester tester, List<VerseItem> verses) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final lang = _Lang();
  GetIt.instance
    ..registerSingleton<TranslationService>(TranslationService(lang, prefs))
    ..registerSingleton<LanguagePreferenceService>(lang)
    ..registerSingleton<SystemConfigService>(_Config())
    ..registerSingleton<VerseCacheService>(_NoCache())
    ..registerSingleton<FetchVerseText>(_Fetch(verses));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => ScriptureVerseSheet.show(context,
              reference: '1 Corinthians 10:32-11:1'),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets('cross-chapter passage shows a marker at the chapter break',
      (tester) async {
    await _open(tester, const [
      VerseItem(number: 32, text: 'Give none offence.', chapter: 10),
      VerseItem(number: 33, text: 'Even as I.', chapter: 10),
      VerseItem(number: 1, text: 'Be ye followers.', chapter: 11),
    ]);
    expect(find.byKey(const Key('verse_sheet_chapter_11')), findsOneWidget);
    expect(find.byKey(const Key('verse_sheet_chapter_10')), findsNothing);
  });

  testWidgets('single-chapter passage shows no chapter marker', (tester) async {
    await _open(tester, const [
      VerseItem(number: 1, text: 'One.'),
      VerseItem(number: 2, text: 'Two.'),
    ]);
    expect(find.text('Two.'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>)
              .value
              .startsWith('verse_sheet_chapter_')),
      findsNothing,
    );
  });
}
