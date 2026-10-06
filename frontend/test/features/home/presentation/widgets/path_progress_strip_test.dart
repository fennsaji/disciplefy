import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDownAll(sl.reset);

  test('tiers', () {
    expect(stripTierFor(8), StripTier.dots);
    expect(stripTierFor(10), StripTier.dots);
    expect(stripTierFor(11), StripTier.segments);
    expect(stripTierFor(20), StripTier.segments);
    expect(stripTierFor(21), StripTier.smooth);
  });

  testWidgets('8 lessons: 8 dots, 3 checked, Today, no dates', (tester) async {
    await tester.pumpWidget(welcomeApp(
        screen: const PathProgressStrip(total: 8, completed: 3, current: 4)));
    for (var n = 1; n <= 8; n++) {
      expect(find.byKey(Key('strip_dot_$n')), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsNothing);
  });

  testWidgets('16 lessons: 16 segments', (tester) async {
    await tester.pumpWidget(welcomeApp(
        screen: const PathProgressStrip(total: 16, completed: 3, current: 4)));
    for (var n = 1; n <= 16; n++) {
      expect(find.byKey(Key('strip_segment_$n')), findsOneWidget);
    }
    expect(find.byKey(const Key('strip_dot_1')), findsNothing);
  });

  testWidgets('29 lessons: smooth bar with ticks at milestones',
      (tester) async {
    await tester.pumpWidget(welcomeApp(
        screen: const PathProgressStrip(
            total: 29,
            completed: 11,
            current: 12,
            milestones: [5, 17, 22, 27])));
    for (final m in [5, 17, 22, 27]) {
      expect(find.byKey(Key('strip_tick_$m')), findsOneWidget);
    }
    expect(find.byKey(const Key('strip_dot_1')), findsNothing);
    expect(find.byKey(const Key('strip_today')), findsOneWidget);
  });

  testWidgets('tap on the strip calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(welcomeApp(
        screen: PathProgressStrip(
            total: 8, completed: 3, current: 4, onTap: () => taps++)));
    await tester.tap(find.byKey(const Key('strip_dot_5')));
    expect(taps, 1);
  });

  for (final language in ['en', 'hi', 'ml']) {
    for (final total in [10, 16, 29]) {
      for (final dark in [false, true]) {
        testWidgets('fits 320px: $language, $total lessons, dark=$dark',
            (tester) async {
          useSurface(tester, const Size(320, 200));
          await tester.pumpWidget(welcomeApp(
            screen: Padding(
              padding: const EdgeInsets.all(16),
              child: PathProgressStrip(
                  total: total,
                  completed: total - 1,
                  current: total,
                  milestones: const [5, 9]),
            ),
            language: language,
            dark: dark,
          ));
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  group('edge cases', () {
    final cases = <String, PathProgressStrip>{
      'total 0': const PathProgressStrip(total: 0, completed: 0, current: 0),
      'total 1': const PathProgressStrip(total: 1, completed: 0, current: 1),
      'completed > total':
          const PathProgressStrip(total: 8, completed: 12, current: 8),
      'current beyond total':
          const PathProgressStrip(total: 12, completed: 3, current: 40),
      'finished 10':
          const PathProgressStrip(total: 10, completed: 10, current: 10),
      'finished 16':
          const PathProgressStrip(total: 16, completed: 16, current: 16),
      'finished 29': const PathProgressStrip(
          total: 29, completed: 29, current: 29, milestones: [5, 17]),
      'bad milestones 8': const PathProgressStrip(
          total: 8, completed: 2, current: 3, milestones: [0, -1, 9, 4, 4]),
      'bad milestones 16': const PathProgressStrip(
          total: 16, completed: 2, current: 3, milestones: [0, -1, 17, 4, 4]),
      'bad milestones 29': const PathProgressStrip(
          total: 29, completed: 2, current: 3, milestones: [0, -1, 30, 4, 4]),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key}: no exception, no overflow', (tester) async {
        useSurface(tester, const Size(320, 200));
        await tester.pumpWidget(welcomeApp(
            screen: Padding(
                padding: const EdgeInsets.all(16), child: entry.value)));
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('smooth ticks only for in-range milestones, once',
        (tester) async {
      await tester.pumpWidget(welcomeApp(
          screen: const PathProgressStrip(
              total: 29,
              completed: 2,
              current: 3,
              milestones: [0, -1, 30, 4, 4, 29])));
      expect(find.byKey(const Key('strip_tick_4')), findsOneWidget);
      expect(find.byKey(const Key('strip_tick_29')), findsOneWidget);
      expect(find.byKey(const Key('strip_tick_0')), findsNothing);
      expect(find.byKey(const Key('strip_tick_-1')), findsNothing);
      expect(find.byKey(const Key('strip_tick_30')), findsNothing);
    });

    testWidgets('finished 8: all checked, none beyond total', (tester) async {
      await tester.pumpWidget(welcomeApp(
          screen:
              const PathProgressStrip(total: 8, completed: 12, current: 99)));
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(8));
      expect(find.byKey(const Key('strip_dot_9')), findsNothing);
    });
  });
}
