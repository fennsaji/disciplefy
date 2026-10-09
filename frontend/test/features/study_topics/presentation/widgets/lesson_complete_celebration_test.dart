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

  testWidgets('animates: pops then confetti bursts to rest', (t) async {
    await t.pumpWidget(_app());
    final centre = t.getCenter(check);
    expect((t.getCenter(piece0) - centre).distance, lessThan(2));
    await t.pump(const Duration(milliseconds: 50));
    expect(_scale(t), lessThan(1));
    final rest = t.getCenter(piece0);
    await t.pumpAndSettle();
    expect(_scale(t), closeTo(1, 0.001));
    final end = t.getCenter(piece0);
    expect((end - centre).distance, greaterThan(100));
    expect(end, isNot(rest));
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion shows final state at once', (t) async {
    await t.pumpWidget(_app(reduce: true));
    expect(_scale(t), closeTo(1, 0.001));
    expect(
        (t.getCenter(piece0) - t.getCenter(check)).distance, greaterThan(100));
    expect(t.takeException(), isNull);
  });
}
