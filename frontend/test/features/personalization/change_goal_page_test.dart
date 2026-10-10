import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_repository.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/bloc/change_goal_cubit.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/pages/change_goal_page.dart';

import '../../helpers/fit_matrix.dart';
import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockGoals extends Mock implements GrowthGoalRepository {}

void main() {
  late _MockGoals goals;
  late FakeTranslationService translations;
  bool? popped;

  setUpAll(() async {
    registerFallbackValue(GrowthGoal.newToFaith);
    registerFallbackValue(GrowthGoalSource.app);
    await loadAppFonts();
  });

  setUp(() {
    popped = null;
    goals = _MockGoals();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    when(() => goals.cachedGoal).thenReturn(GrowthGoal.readGospel);
    when(() => goals.loadGoal()).thenAnswer((_) async => GrowthGoal.readGospel);
    when(() => goals.saveGoal(any(), source: any(named: 'source'))).thenAnswer(
        (i) async => Right(i.positionalArguments.first as GrowthGoal));
  });

  tearDown(() => sl.reset());

  /// Home at '/', which opens the page the way Settings does (push).
  Future<void> pumpPage(WidgetTester tester,
      {bool dark = false, double textScale = 1}) async {
    final cubit = ChangeGoalCubit(goals);
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  popped = await context.push<bool>(AppRoutes.changeGoal),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.changeGoal,
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: ChangeGoalPage(cubit: cubit..load()),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const Text('settings'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, GrowthGoal goal) {
    final row = find.byKey(Key('change_goal_${goal.name}'));
    return find
        .descendant(of: row, matching: find.byIcon(Icons.check_rounded))
        .evaluate()
        .isNotEmpty;
  }

  testWidgets('six goals, the saved one selected, Save off until one changes',
      (tester) async {
    await pumpPage(tester);
    expect(find.text('What would you like to grow in?'), findsOneWidget);
    for (final goal in GrowthGoal.values) {
      expect(find.byKey(Key('change_goal_${goal.name}')), findsOneWidget);
    }
    expect(selected(tester, GrowthGoal.readGospel), isTrue);
    final save = tester.widget<FilledButton>(find.descendant(
        of: find.byKey(const Key('change_goal_save')),
        matching: find.byType(FilledButton)));
    expect(save.onPressed, isNull);
  });

  testWidgets('pick another goal and Save: saved on the server, page closes',
      (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Hope in hard times'));
    await tester.pump();
    expect(selected(tester, GrowthGoal.hopeHardTimes), isTrue);
    expect(selected(tester, GrowthGoal.readGospel), isFalse);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => goals.saveGoal(GrowthGoal.hopeHardTimes,
        source: GrowthGoalSource.settings)).called(1);
    expect(popped, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a failed save keeps the page open with the pick',
      (tester) async {
    when(() => goals.saveGoal(any(), source: any(named: 'source')))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    await pumpPage(tester);
    await tester.tap(find.text('Understanding the gospel'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save your goal. Try again."), findsOneWidget);
    expect(popped, isNull);
    expect(selected(tester, GrowthGoal.understandGospel), isTrue);
  });

  testWidgets('no goal yet: nothing selected until one is picked',
      (tester) async {
    when(() => goals.cachedGoal).thenReturn(null);
    when(() => goals.loadGoal()).thenAnswer((_) async => null);
    await pumpPage(tester);
    for (final goal in GrowthGoal.values) {
      expect(selected(tester, goal), isFalse);
    }
    await tester.tap(find.text("I'm new to faith"));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => goals.saveGoal(GrowthGoal.newToFaith,
        source: GrowthGoalSource.settings)).called(1);
  });

  for (final c in fitCases()) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('${c.name} ${scale}x fits', (tester) async {
        translations.language = AppLanguage.fromCode(c.lang);
        useFitSurface(tester, c, height: 700);
        await pumpPage(tester, dark: c.dark, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        // Save stays on screen.
        expect(tester.getRect(find.byKey(const Key('change_goal_save'))).bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height));
      });
    }
  }
}
