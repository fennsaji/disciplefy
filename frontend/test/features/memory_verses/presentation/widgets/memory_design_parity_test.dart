import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/mastery_progress_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_verse_list_item.dart';

import '../../../../helpers/welcome_test_harness.dart';

MemoryVerseEntity _verse({required int dueInDays}) {
  final now = DateTime.now();
  return MemoryVerseEntity(
    id: 'v1',
    verseReference: 'Philippians 4:13',
    verseText: 'I can do all things through him who strengthens me.',
    language: 'en',
    sourceType: 'manual',
    easeFactor: 2.5,
    intervalDays: 3,
    repetitions: 2,
    nextReviewDate: DateTime(now.year, now.month, now.day + dueInDays, 9),
    addedDate: DateTime(2026, 9, 2),
    totalReviews: 4,
    createdAt: DateTime(2026, 9, 2),
    masteryLevel: MasteryLevel.beginner,
  );
}

BoxDecoration? _glowOf(WidgetTester tester, Finder of) {
  final boxes = tester
      .widgetList<DecoratedBox>(
          find.descendant(of: of, matching: find.byType(DecoratedBox)))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
  return boxes.isEmpty ? null : boxes.first;
}

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDown(sl.reset);

  Widget host(Widget child, {bool dark = true}) => welcomeApp(
        dark: dark,
        screen: Scaffold(body: ListView(children: [child])),
      );

  group('Verse card', () {
    testWidgets('a due verse shows the grey Due chip at the top',
        (tester) async {
      await tester.pumpWidget(
          host(MemoryVerseListItem(verse: _verse(dueInDays: 0), onTap: () {})));
      expect(find.byType(MemoryDueChip), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      // The chip sits on the reference line, above the verse text.
      expect(
        tester.getTopLeft(find.text('Due')).dy,
        lessThan(tester.getTopLeft(find.textContaining('I can do all')).dy),
      );
    });

    testWidgets('the highlighted card glows gold on dark only', (tester) async {
      await tester.pumpWidget(host(MemoryVerseListItem(
          verse: _verse(dueInDays: 0), onTap: () {}, highlighted: true)));
      expect(_glowOf(tester, find.byType(MemoryVerseListItem)), isNotNull);

      await tester.pumpWidget(host(
          MemoryVerseListItem(
              verse: _verse(dueInDays: 0), onTap: () {}, highlighted: true),
          dark: false));
      await tester.pumpAndSettle();
      expect(_glowOf(tester, find.byType(MemoryVerseListItem)), isNull);
    });

    testWidgets('a verse not due keeps reviews, interval and the due day',
        (tester) async {
      await tester.pumpWidget(
          host(MemoryVerseListItem(verse: _verse(dueInDays: 3), onTap: () {})));
      expect(find.byType(MemoryDueChip), findsNothing);
      expect(find.text('2 reviews'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('In 3 days'), findsOneWidget);
    });
  });

  group('Shared controls', () {
    testWidgets('choice chip: 32px gold pill in a 40px tap row',
        (tester) async {
      await tester.pumpWidget(host(Row(children: [
        MemoryChoiceChip(label: 'Salvation', selected: true, onTap: () {}),
        MemoryChoiceChip(label: 'Comfort', selected: false, onTap: () {}),
      ])));
      final chip = find.byType(MemoryChoiceChip).first;
      expect(tester.getSize(chip).height, 40);
      final pill = tester.widget<Container>(
          find.descendant(of: chip, matching: find.byType(Container)).first);
      final shape = pill.decoration! as ShapeDecoration;
      final palette = ReaderPalette.of(tester.element(chip));
      expect(shape.color, palette.selectedFill);
      expect(
          tester
              .getSize(find.descendant(of: chip, matching: find.byWidget(pill)))
              .height,
          32);
    });

    testWidgets('segmented control: the chosen segment is gold',
        (tester) async {
      await tester.pumpWidget(host(MemorySegmentedControl<int>(
        segments: const [
          MemorySegment(value: 0, label: 'Easy'),
          MemorySegment(value: 1, label: 'Medium'),
        ],
        selected: 1,
        onChanged: (_) {},
      )));
      final palette = ReaderPalette.of(
          tester.element(find.byType(MemorySegmentedControl<int>)));
      final selected = tester.widget<Material>(find
          .ancestor(of: find.text('Medium'), matching: find.byType(Material))
          .first);
      expect(selected.color, palette.selectedFill);
      expect(tester.getSize(find.byType(MemorySegmentedControl<int>)).height,
          greaterThanOrEqualTo(40));
    });

    testWidgets('practice pills are 40px; secondary is outlined',
        (tester) async {
      await tester.pumpWidget(host(MemoryActionBar(
        secondary: [
          MemoryActionPill(
              label: 'Hint', icon: Icons.lightbulb, onPressed: () {}),
        ],
        primary: MemoryPrimaryPill(label: 'Check', onPressed: () {}),
      )));
      expect(tester.getSize(find.byType(MemoryPrimaryPill)).height, 40);
      expect(tester.getSize(find.byType(MemoryActionPill)).height, 40);
      final secondary = tester.widget<TextButton>(find.descendant(
          of: find.byType(MemoryActionPill),
          matching: find.byType(TextButton)));
      final shape = secondary.style!.shape!.resolve({})! as StadiumBorder;
      expect(shape.side, isNot(BorderSide.none));
    });
  });
}
