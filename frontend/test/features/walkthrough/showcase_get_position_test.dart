// The patched showcaseview copy is part of this repo, so its internals are
// tested here.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/src/get_position.dart';

/// Never lays out its child, like a subtree caught before its first layout.
class _NeverLaysOut extends SingleChildRenderObjectWidget {
  const _NeverLaysOut({super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNeverLaysOut();
}

class _RenderNeverLaysOut extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.smallest;
  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

void main() {
  GetPosition measure(GlobalKey key) =>
      GetPosition(key: key, screenWidth: 400, screenHeight: 800);

  testWidgets('measures a laid-out target', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, top: 20),
        child: SizedBox(key: key, width: 60, height: 50),
      ),
    ));
    expect(measure(key).getRect(), const Rect.fromLTWH(10, 20, 60, 50));
  });

  testWidgets(
      'a target below a render box that is not laid out is treated as '
      'missing instead of throwing', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Column(children: [
      _NeverLaysOut(
        child: FractionalTranslation(
          translation: const Offset(0, 1),
          child: SizedBox(key: key, width: 60, height: 50),
        ),
      ),
    ]));
    final position = measure(key);
    expect(tester.takeException(), isNull);
    expect(position.getRect(), Rect.zero);
    expect(position.getHeight(), 0);
  });

  testWidgets('a target that is not mounted is treated as missing',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    expect(measure(GlobalKey()).getRect(), Rect.zero);
  });
}
