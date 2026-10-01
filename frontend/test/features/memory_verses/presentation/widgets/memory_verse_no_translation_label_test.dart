import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_flip_card.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _Config extends Fake implements SystemConfigService {
  @override
  bool get isBibleContentEnabled => true;
}

MemoryVerseEntity _dailyVerse(String reference, String language) =>
    MemoryVerseEntity(
      id: 'v1',
      verseReference: reference,
      verseText: 'The LORD is my shepherd; I shall not want.',
      language: language,
      sourceType: 'daily_verse',
      sourceId: 'd1',
      easeFactor: 2.5,
      intervalDays: 3,
      repetitions: 1,
      totalReviews: 2,
      nextReviewDate: DateTime(2026, 10, 2),
      addedDate: DateTime(2026, 9, 2),
      createdAt: DateTime(2026, 9, 2),
    );

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    sl.registerSingleton<SystemConfigService>(_Config());
  });

  tearDown(() async => sl.reset());

  for (final (reference, language) in [
    ('Psalm 23:1', 'en'),
    ('भजन संहिता 23:1', 'hi'),
    ('സങ്കീർത്തനങ്ങൾ 23:1', 'ml'),
  ]) {
    testWidgets('daily verse flip card shows no translation label ($language)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            height: 560,
            child: VerseFlipCard(
              verse: _dailyVerse(reference, language),
              isFlipped: true,
              onFlip: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(reference), findsOneWidget);
      expect(find.textContaining('BSB'), findsNothing);
      expect(find.textContaining('IRV'), findsNothing);
      expect(find.textContaining('KJV'), findsNothing);
    });
  }

  test('no memory verse screen or practice mode adds a translation label', () {
    // Practice answers, scoring and spoken text are built from verseText /
    // verseReference only; guard against a label being appended anywhere.
    final labelPattern = RegExp(
        r"bibleTranslationAbbr|bible_translation_citation|'\((BSB|IRV|KJV|SV)\)'|· (BSB|IRV|KJV)");
    final offenders = Directory('lib/features/memory_verses')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => labelPattern.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
