import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_header_line.dart';

import '../../../../helpers/welcome_test_harness.dart';

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDown(sl.reset);

  testWidgets('the tappable streak line is at least 40px tall', (tester) async {
    var taps = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: Column(children: [
        MemoryHeaderLine(streak: 4, verseCount: 5, onTap: () => taps++),
      ]),
    )));
    final line = find.byType(MemoryHeaderLine);
    expect(tester.getSize(line).height, greaterThanOrEqualTo(40));
    // A tap near the top edge, outside the text itself, still counts.
    await tester.tapAt(tester.getTopLeft(line) + const Offset(40, 3));
    expect(taps, 1);
  });
}
