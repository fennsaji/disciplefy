import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/lesson_complete_page.dart';

Widget _app({bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Scaffold(body: LessonCompleteCelebration()),
      ),
    );

double _scale(WidgetTester t) => t
    .widget<Transform>(find.byKey(const Key('lesson_complete_check_scale')))
    .transform
    .storage[0];

void main() {
  final check = find.byKey(const Key('lesson_complete_check'));
  final piece0 = find.byKey(const Key('lesson_complete_confetti_0'));

  testWidgets('animates: pops, confetti bursts out, then fades away',
      (t) async {
    await t.pumpWidget(_app());
    final centre = t.getCenter(check);
    expect((t.getCenter(piece0) - centre).distance, lessThan(2));
    await t.pump(const Duration(milliseconds: 50));
    expect(_scale(t), lessThan(1));
    final start = t.getCenter(piece0);
    // Burst done, before the fade.
    await t.pump(const Duration(milliseconds: 1250));
    final burst = t.getCenter(piece0);
    expect((burst - centre).distance, greaterThan(100));
    expect(burst, isNot(start));
    await t.pumpAndSettle();
    expect(_scale(t), closeTo(1, 0.001));
    expect(piece0, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion shows the check at once, no confetti', (t) async {
    await t.pumpWidget(_app(reduce: true));
    expect(_scale(t), closeTo(1, 0.001));
    expect(piece0, findsNothing);
    expect(t.takeException(), isNull);
  });
}
