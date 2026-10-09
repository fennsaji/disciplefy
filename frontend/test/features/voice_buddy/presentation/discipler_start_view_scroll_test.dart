import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_start_view.dart';

import '../../../helpers/welcome_test_harness.dart';

void main() {
  tearDown(sl.reset);

  const dock = 90.0;
  const sizes = [Size(320, 568), Size(360, 640)];
  const scales = [1.3, 1.5];

  for (final size in sizes) {
    for (final scale in scales) {
      for (final lang in [
        AppLanguage.english,
        AppLanguage.hindi,
        AppLanguage.malayalam,
      ]) {
        for (final dark in [true, false]) {
          testWidgets(
              'scrolls, no overflow, buttons and last suggestion clear the '
              'dock (${size.width.toInt()}x${size.height.toInt()}, x$scale, '
              '${lang.name}, dark=$dark)', (tester) async {
            sl.registerSingleton<TranslationService>(
                FakeTranslationService(lang));
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(welcomeApp(
              dark: dark,
              screen: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: MediaQuery.of(context).padding +
                        const EdgeInsets.only(bottom: dock),
                  ),
                  child: Scaffold(
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
                ),
              ),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull);

            final scrollable = find.byType(Scrollable).first;
            double offset() =>
                tester.state<ScrollableState>(scrollable).position.pixels;
            expect(offset(), 0);
            await tester.drag(scrollable, const Offset(0, -3000));
            await tester.pump();
            expect(offset(), greaterThan(0));

            final limit = size.height - dock;
            final last = find.byIcon(Icons.north_east_rounded).last;
            expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(limit));

            // Both buttons can be scrolled fully into the area above the dock.
            for (final label in ['Start talking', 'Type']) {
              final f = find.ancestor(
                of: find.textContaining(label),
                matching: find.byType(FilledButton),
              );
              if (f.evaluate().isEmpty) continue; // translated label
              await Scrollable.ensureVisible(tester.element(f.first),
                  alignment: 0.4);
              await tester.pump();
              final r = tester.getRect(f.first);
              expect(r.top, greaterThanOrEqualTo(0));
              expect(r.bottom, lessThanOrEqualTo(limit));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
