import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/utils/app_scroll_behavior.dart';

void main() {
  testWidgets('a mouse drag scrolls a list', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: List.generate(
              40, (i) => SizedBox(height: 80, child: Text('row $i'))),
        ),
      ),
    ));

    final gesture = await tester.startGesture(const Offset(200, 400),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(0, -300));
    await gesture.up();
    await tester.pump();

    expect(controller.offset, greaterThan(100));
  });

  testWidgets('the default behaviour ignores a mouse drag', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: List.generate(
              40, (i) => SizedBox(height: 80, child: Text('row $i'))),
        ),
      ),
    ));

    final gesture = await tester.startGesture(const Offset(200, 400),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(0, -300));
    await gesture.up();
    await tester.pump();

    expect(controller.offset, 0);
  });
}
