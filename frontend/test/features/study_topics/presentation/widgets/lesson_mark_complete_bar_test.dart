import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/lesson_mark_complete_bar.dart';

import '../../../../helpers/welcome_test_harness.dart';

const _lesson =
    LessonRef(pathId: 'p', pathTitle: 'P', lessonNumber: 4, lessonTotal: 8);

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDown(() => sl.reset());

  testWidgets('tapping completes immediately, 40px gold button',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(LessonMarkCompleteBar(
      lesson: _lesson,
      onComplete: () async => calls++,
    )));
    expect(tester.getSize(find.byType(FilledButton)).height, 40);
    await tester.tap(find.text('Mark complete · Lesson 4 of 8'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('shows a spinner and ignores taps while completing',
      (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(_app(LessonMarkCompleteBar(
      lesson: _lesson,
      onComplete: () {
        calls++;
        return done.future;
      },
    )));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    done.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('secondary is hidden when null and shown when given',
      (tester) async {
    await tester.pumpWidget(
        _app(LessonMarkCompleteBar(lesson: _lesson, onComplete: () async {})));
    expect(find.text('sec'), findsNothing);
    await tester.pumpWidget(_app(LessonMarkCompleteBar(
        lesson: _lesson,
        onComplete: () async {},
        secondary: const Text('sec'))));
    expect(find.text('sec'), findsOneWidget);
  });

  testWidgets('fill is white on dark and gold on light', (tester) async {
    Color? fillOf() => tester
        .widget<FilledButton>(find.byType(FilledButton))
        .style!
        .backgroundColor!
        .resolve({});
    Future<void> pumpWith(ThemeData t) => tester.pumpWidget(MaterialApp(
          theme: t,
          home: Scaffold(
              body: LessonMarkCompleteBar(
                  lesson: _lesson, onComplete: () async {})),
        ));
    await pumpWith(AppTheme.darkTheme);
    expect(fillOf(), Colors.white);
    await pumpWith(AppTheme.lightTheme);
    await tester.pumpAndSettle();
    expect(fillOf(), AppColors.brandHighlightDark);
  });

  testWidgets('stays 40px under a compact (web) density, 15pt, gold glow',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme.copyWith(visualDensity: VisualDensity.compact),
      home: Scaffold(
          body:
              LessonMarkCompleteBar(lesson: _lesson, onComplete: () async {})),
    ));
    expect(tester.getSize(find.byType(FilledButton)).height, 40);
    final style = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .style!
        .textStyle!
        .resolve({});
    expect(style!.fontSize, 15);
    final glow = tester.widget<DecoratedBox>(find
        .ancestor(
            of: find.byType(FilledButton), matching: find.byType(DecoratedBox))
        .first);
    final shadows = (glow.decoration as BoxDecoration).boxShadow!;
    expect(shadows.single.blurRadius, 16);
  });

  testWidgets('a long label shrinks rather than cutting at 320pt',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: LessonMarkCompleteBar(
        lesson: LessonRef(
            pathId: 'p', pathTitle: 'P', lessonNumber: 12, lessonTotal: 40),
        onComplete: _noop,
      ),
    )));
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.textContaining('Mark complete'));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(find.byType(FittedBox), findsOneWidget);
  });
}

Future<void> _noop() async {}
