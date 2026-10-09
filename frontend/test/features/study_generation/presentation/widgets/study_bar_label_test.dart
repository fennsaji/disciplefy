import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_bar_label.dart';

import '../../../../helpers/text_fit.dart';

/// The reader's bottom bar as laid out in StudyGuideScreenV2: 16px sides, a
/// 10px gap, two 40px pills; Listen is an outlined icon button, Ask
/// Discipler a 20px glyph and 8px gap inside 12px padding.
Widget _bar(String listen, String ask, double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.headphones_rounded, size: 18),
                        label: StudyBarLabel(listen, key: const Key('listen')),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: StudyBarIconLabel(
                          key: const Key('ask'),
                          icon: const SizedBox(
                              key: Key('glyph'), width: 20, height: 20),
                          iconWidth: 20,
                          text: ask,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  String label(Map<String, dynamic> m, String path) {
    dynamic v = m;
    for (final k in path.split('.')) {
      v = (v as Map<String, dynamic>)[k];
    }
    return v as String;
  }

  final languages = {
    'en': englishTranslations,
    'hi': hindiTranslations,
    'ml': malayalamTranslations,
  };

  for (final lang in languages.keys) {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$lang ${width.toInt()}px ${scale}x: same size, not cut',
            (tester) async {
          tester.view.physicalSize = Size(width, 400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final m = languages[lang]!;
          await tester.pumpWidget(_bar(label(m, 'study_guide.tts.listen'),
              label(m, 'study_guide.ask_ai'), scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final listen = tester.widget<Text>(find.descendant(
              of: find.byKey(const Key('listen')),
              matching: find.byType(Text)));
          final ask = tester.widget<Text>(find.descendant(
              of: find.byKey(const Key('ask')), matching: find.byType(Text)));
          expect(listen.style!.fontSize, ask.style!.fontSize);
          expect(ask.style!.fontSize, greaterThanOrEqualTo(12));
          // Nothing scales either label down.
          expect(
              find.ancestor(
                  of: find.byKey(const Key('ask')),
                  matching: find.byType(FittedBox)),
              findsNothing);
          // The glyph only gives way where the words would not fit.
          if (scale == 1.0 && (lang != 'ml' || width > 320)) {
            expect(find.byKey(const Key('glyph')), findsOneWidget);
          }
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
