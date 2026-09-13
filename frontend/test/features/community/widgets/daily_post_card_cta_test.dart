import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/daily_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/study_guide_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  testWidgets('daily post body hides the reflection question from older posts',
      (tester) async {
    const content = '📖 Who is Jesus Christ?\n\n'
        '✨ Do you know how strong your faith is?\n\n'
        'Knowing who Jesus is changes your everyday faith.\n\n'
        '✝️ Philippians 2:5-11\n\n'
        '💬 Why does it matter that Jesus is fully God and fully man?';

    await tester.pumpWidget(_wrap(
      const DailyPostBody(content: content, accent: Colors.amber),
    ));

    expect(find.text('Do you know how strong your faith is?'), findsOneWidget);
    expect(find.text('Knowing who Jesus is changes your everyday faith.'),
        findsOneWidget);
    expect(find.text('✝️ Philippians 2:5-11'), findsOneWidget);
    expect(find.textContaining('fully God and fully man'), findsNothing);
  });

  testWidgets(
      'study guide chip with an action label shows the title above the label, in the accent',
      (tester) async {
    const gold = Color(0xFF8B6914);
    await tester.pumpWidget(_wrap(
      const StudyGuideChip(
        title: 'Who is Jesus Christ?',
        actionLabel: 'Open Study Guide',
        accent: gold,
      ),
    ));

    final title = find.text('Who is Jesus Christ?');
    final label = find.text('Open Study Guide');
    expect(title, findsOneWidget);
    expect(label, findsOneWidget);
    expect(tester.getTopLeft(title).dy, lessThan(tester.getTopLeft(label).dy),
        reason: 'the guide title leads; the action label sits under it');
    expect(tester.widget<Text>(label).style?.color, gold);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('study guide chip without an action label keeps the quiet row',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const StudyGuideChip(title: 'Who is Jesus Christ?'),
    ));

    expect(find.text('Who is Jesus Christ?'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
  });
}
