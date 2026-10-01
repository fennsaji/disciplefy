import 'dart:async';

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
}

/// Fetch that only resolves when the test completes [completer].
class _PendingFetch extends Fake implements FetchVerseText {
  final completer = Completer<Either<Failure, FetchedVerseEntity>>();

  @override
  Future<Either<Failure, FetchedVerseEntity>> call({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    int? endChapter,
    required String language,
  }) =>
      completer.future;
}

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets('dismissing the sheet before the fetch resolves does not throw',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lang = _Lang();
    final fetch = _PendingFetch();
    GetIt.instance
      ..registerSingleton<TranslationService>(TranslationService(lang, prefs))
      ..registerSingleton<LanguagePreferenceService>(lang)
      ..registerSingleton<SystemConfigService>(_Config())
      ..registerSingleton<VerseCacheService>(_NoCache())
      ..registerSingleton<FetchVerseText>(fetch);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                ScriptureVerseSheet.show(context, reference: 'John 3:16'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ScriptureVerseSheet), findsOneWidget);

    Navigator.of(tester.element(find.byType(ScriptureVerseSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ScriptureVerseSheet), findsNothing);

    fetch.completer.complete(const Left(ServerFailure()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
