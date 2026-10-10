import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/shared/widgets/keep_alive_block.dart';

void main() {
  Future<ScrollController> pumpList(WidgetTester tester,
      {required bool keep}) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget field = const TextField(key: Key('draft'));
    if (keep) field = KeepAliveBlock(child: field);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            SliverList.list(children: [
              field,
              for (var i = 0; i < 40; i++)
                SizedBox(height: 200, child: Text('$i')),
            ]),
          ],
        ),
      ),
    ));
    return controller;
  }

  Future<void> typeScrollAwayAndBack(
      WidgetTester tester, ScrollController controller) async {
    await tester.enterText(find.byKey(const Key('draft')), 'unsent question');
    // A focused field keeps itself alive; the user has moved on.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    controller.jumpTo(0);
    await tester.pump();
  }

  testWidgets('a lazily built block forgets its state once scrolled away',
      (tester) async {
    final controller = await pumpList(tester, keep: false);
    await typeScrollAwayAndBack(tester, controller);
    expect(find.text('unsent question'), findsNothing);
  });

  testWidgets('KeepAliveBlock keeps its state after scrolling away and back',
      (tester) async {
    final controller = await pumpList(tester, keep: true);
    await typeScrollAwayAndBack(tester, controller);
    expect(find.text('unsent question'), findsOneWidget);
  });
}
