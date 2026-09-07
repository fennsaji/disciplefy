import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

/// Opens a modal bottom sheet whose content is [content] wrapped in a
/// [SheetScrollView], and returns once the sheet has settled.
Future<void> _openSheet(WidgetTester tester, Widget content) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SheetScrollView(child: content),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('content that fits leaves the sheet draggable to dismiss',
      (tester) async {
    await _openSheet(tester, const SizedBox(height: 200, child: Text('short')));
    expect(find.text('short'), findsOneWidget);

    await tester.drag(find.text('short'), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('short'), findsNothing,
        reason: 'a sheet whose content fits must still pull down to dismiss');
  });

  testWidgets('content that fits does not scroll', (tester) async {
    await _openSheet(tester, const SizedBox(height: 200, child: Text('short')));

    final physics = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .physics;
    expect(physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('content taller than the sheet scrolls', (tester) async {
    await _openSheet(
      tester,
      const SizedBox(height: 4000, child: Text('tall')),
    );

    final physics = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .physics;
    expect(physics, isA<ClampingScrollPhysics>(),
        reason: 'overflowing content must scroll');

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('tall'), findsOneWidget,
        reason: 'scrolling must not dismiss the sheet');
  });

  testWidgets('overflowing content still pulls down to dismiss',
      (tester) async {
    await _openSheet(
      tester,
      const SizedBox(height: 4000, child: Text('tall')),
    );
    expect(find.text('tall'), findsOneWidget);

    // At the top of the list, so this is a pull past the top, not a scroll.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('tall'), findsNothing,
        reason: 'a scrollable sheet must still pull down to dismiss');
  });

  testWidgets('scrolling down then up does not dismiss the sheet',
      (tester) async {
    await _openSheet(
      tester,
      const SizedBox(height: 4000, child: Text('tall')),
    );

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    // Scrolling back to the top must not be read as a dismiss pull.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('tall'), findsOneWidget);
  });
}
