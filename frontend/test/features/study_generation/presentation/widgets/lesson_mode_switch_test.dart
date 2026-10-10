import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/lesson_mode_switch.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

void main() {
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
    await sl.reset();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDownAll(sl.reset);

  Widget app({
    StudyMode current = StudyMode.quick,
    ValueChanged<StudyMode>? onChanged,
    bool dark = false,
    String? language,
  }) =>
      welcomeApp(
        dark: dark,
        language: language,
        screen: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LessonModeSwitch(
              current: current,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );

  testWidgets('tapping Standard reports standard; selected segment is gold',
      (tester) async {
    StudyMode? picked;
    await tester.pumpWidget(app(onChanged: (m) => picked = m));
    await tester.pumpAndSettle();
    expect(find.text('Quick Read · 3 min'), findsOneWidget);
    expect(find.text('Standard · 8 min'), findsOneWidget);

    await tester.tap(find.textContaining('Standard'));
    expect(picked, StudyMode.standard);

    final quick = tester.widget<DecoratedBox>(
      find.byKey(const Key('lesson_mode_quick')),
    );
    final palette = ReaderPalette.of(
      tester.element(find.byKey(const Key('lesson_mode_quick'))),
    );
    expect((quick.decoration as BoxDecoration).color, palette.selectedFill);
    expect(
        tester.getSize(find.byKey(const Key('lesson_mode_quick'))).height, 32);
    expect(
        tester.getSize(find.byKey(const Key('lesson_mode_full'))).height, 32);
  });

  testWidgets('tapping the current segment does nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(onChanged: (_) => calls++));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quick Read ·'));
    expect(calls, 0);
  });

  testWidgets('standard selected: full segment is the gold one',
      (tester) async {
    await tester.pumpWidget(app(current: StudyMode.standard));
    await tester.pumpAndSettle();
    final full = tester.widget<DecoratedBox>(
      find.byKey(const Key('lesson_mode_full')),
    );
    final palette = ReaderPalette.of(
      tester.element(find.byKey(const Key('lesson_mode_full'))),
    );
    expect((full.decoration as BoxDecoration).color, palette.selectedFill);
  });

  for (final lang in ['en', 'hi', 'ml']) {
    for (final dark in [false, true]) {
      testWidgets('fits at 320px: $lang ${dark ? 'dark' : 'light'}',
          (tester) async {
        useSurface(tester, const Size(320, 400));
        await tester.pumpWidget(app(dark: dark, language: lang));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  }

  group('who sees the switch', () {
    test('a signed-in reader of a Quick Read lesson', () {
      expect(LessonModeSwitch.shownFor(mode: StudyMode.quick, isGuest: false),
          isTrue);
    });

    test('never a guest, in any mode', () {
      for (final mode in StudyMode.values) {
        expect(LessonModeSwitch.shownFor(mode: mode, isGuest: true), isFalse);
      }
    });

    test('not a signed-in reader of Standard or deeper', () {
      for (final mode in [
        StudyMode.standard,
        StudyMode.deep,
        StudyMode.lectio,
        StudyMode.sermon,
      ]) {
        expect(LessonModeSwitch.shownFor(mode: mode, isGuest: false), isFalse,
            reason: mode.name);
      }
    });
  });
}
