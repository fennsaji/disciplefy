import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_header_cards.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(
      () => sl.registerSingleton<TranslationService>(FakeTranslationService()));
  tearDown(() async => sl.reset());

  for (final width in [320.0, 360.0, 390.0]) {
    for (final lang in ['en', 'hi', 'ml']) {
      testWidgets('${width.toInt()} $lang: streak and leaderboard words whole',
          (tester) async {
        useSurface(tester, Size(width, 400));
        await tester.pumpWidget(welcomeApp(
          language: lang,
          dark: true,
          screen: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: TopicsStatRow(streak: 3),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final key in const [
          'topics_streak_tile',
          'topics_leaderboard_tile'
        ]) {
          final paragraphs = tester.renderObjectList<RenderParagraph>(
              find.descendant(
                  of: find.byKey(Key(key)), matching: find.byType(RichText)));
          for (final p in paragraphs) {
            final text = p.text.toPlainText();
            if (text.trim().isEmpty || text.codeUnits.length == 1) continue;
            for (final word in text.split(RegExp(r'\s+'))) {
              if (word.isEmpty) continue;
              final tp = TextPainter(
                text: TextSpan(text: word, style: p.text.style),
                textDirection: TextDirection.ltr,
                textScaler: p.textScaler,
              )..layout();
              expect(tp.width, lessThanOrEqualTo(p.size.width + 0.5),
                  reason: '"$word" in "$text" breaks mid-word');
              tp.dispose();
            }
          }
        }
        // Text stays at the 12pt floor: the leaderboard label is not shrunk.
        final board = tester.getSize(find.descendant(
            of: find.byKey(const Key('topics_leaderboard_tile')),
            matching: find.byType(FittedBox)));
        final label = tester.renderObject<RenderParagraph>(find
            .descendant(
                of: find.byKey(const Key('topics_leaderboard_tile')),
                matching: find.byType(RichText))
            .last);
        expect(label.size.width, lessThanOrEqualTo(board.width + 0.5));
        expect(label.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(board.width + 0.5));
      });
    }
  }
}
