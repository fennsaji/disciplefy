import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_start_view.dart';

import '../../../helpers/welcome_test_harness.dart';

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDown(sl.reset);

  Widget start({bool dark = true, String? language}) => welcomeApp(
        dark: dark,
        language: language,
        screen: Scaffold(
          body: DisciplerStartView(
            quota: null,
            languageName: 'English',
            onSettings: () {},
            onLanguageTap: () {},
            onStartTalking: () {},
            onType: () {},
            onSuggestion: (_) {},
          ),
        ),
      );

  bool hasGlow(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .any((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);

  testWidgets('short description, 40px actions and a glowing first question',
      (tester) async {
    // Wide enough that the test font (every glyph a full em) keeps
    // "Start talking" on one line, as Inter does at 390pt.
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(start());
    await tester.pump();

    expect(
        find.text('Your Bible companion — by voice or text'), findsOneWidget);
    final talk = find.ancestor(
        of: find.text('Start talking'), matching: find.byType(FilledButton));
    expect(tester.getSize(talk).height, 40);
    expect(hasGlow(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no glow on light', (tester) async {
    await tester.pumpWidget(start(dark: false));
    await tester.pump();
    expect(hasGlow(tester), isFalse);
  });

  for (final language in ['hi', 'ml']) {
    testWidgets('$language at 320pt lays out without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(start(language: language));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
