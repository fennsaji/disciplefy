import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/entities/personalization_entity.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/repositories/personalization_repository.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/pages/personalization_questionnaire_page.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/widgets/question_option_card.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _FakeRepository implements PersonalizationRepository {
  int saves = 0;
  int skips = 0;
  bool failSave = false;
  FaithStage? lastFaithStage;

  @override
  Future<PersonalizationEntity> getPersonalization() async =>
      const PersonalizationEntity();

  @override
  Future<PersonalizationEntity> savePersonalization({
    required FaithStage? faithStage,
    required List<SpiritualGoal> spiritualGoals,
    required TimeAvailability? timeAvailability,
    required LearningStyle? learningStyle,
    required LifeStageFocus? lifeStageFocus,
    required BiggestChallenge? biggestChallenge,
  }) async {
    saves++;
    lastFaithStage = faithStage;
    if (failSave) throw Exception('offline');
    return const PersonalizationEntity(questionnaireCompleted: true);
  }

  @override
  Future<PersonalizationEntity> skipQuestionnaire() async {
    skips++;
    return const PersonalizationEntity(questionnaireSkipped: true);
  }
}

void main() {
  late FakeTranslationService translations;
  late _FakeRepository repository;
  late int completions;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    repository = _FakeRepository();
    completions = 0;
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester, {required bool dark}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(
          path: '/questionnaire',
          builder: (_, __) => PersonalizationQuestionnairePage(
            repository: repository,
            onComplete: () => completions++,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    // Pushed over home, as in the app, so finishing pops back.
    unawaited(router.push('/questionnaire'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> pickFirstOption(WidgetTester tester) async {
    final single = find.byType(QuestionOptionCard);
    final option = single.evaluate().isNotEmpty
        ? single.first
        : find.byType(MultiSelectOptionCard).first;
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: all six steps fit 320x640',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpPage(tester, dark: dark);

        for (var step = 0; step < 6; step++) {
          expect(tester.takeException(), isNull, reason: 'step ${step + 1}');
          expectNoTruncatedText(tester);
          await pickFirstOption(tester);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
          await tapKey(tester, 'questionnaire_continue');
        }

        expect(repository.saves, 1);
        expect(completions, 1);
        expect(find.text('home'), findsOneWidget);
      });
    }

    testWidgets('$theme: continue needs an answer; back returns a step',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpPage(tester, dark: dark);

      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);
      expect(find.text('Where are you in your faith journey?'), findsOneWidget);
      expect(find.byKey(const Key('questionnaire_back')), findsNothing);

      // Disabled until an option is picked.
      await tapKey(tester, 'questionnaire_continue');
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);

      await pickFirstOption(tester);
      await tapKey(tester, 'questionnaire_continue');
      expect(find.textContaining('STEP 2 OF 6'), findsOneWidget);
      expect(find.text('0/3 selected'), findsOneWidget);
      await pickFirstOption(tester);
      expect(find.text('1/3 selected'), findsOneWidget);

      await tapKey(tester, 'questionnaire_back');
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);
    });

    testWidgets('$theme: skip asks first, then skips the questionnaire',
        (tester) async {
      useSurface(tester, const Size(320, 640));
      await pumpPage(tester, dark: dark);

      await tapKey(tester, 'questionnaire_skip');
      expect(find.text('Skip Personalization?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapKey(tester, 'questionnaire_skip_confirm');
      expect(repository.skips, 1);
      expect(completions, 1);
    });

    testWidgets('$theme: a failed save offers retry instead of a spinner',
        (tester) async {
      useSurface(tester, const Size(320, 640));
      repository.failSave = true;
      await pumpPage(tester, dark: dark);

      for (var step = 0; step < 6; step++) {
        await pickFirstOption(tester);
        await tapKey(tester, 'questionnaire_continue');
      }
      expect(repository.saves, 1);
      expect(find.byKey(const Key('questionnaire_retry')), findsOneWidget);

      // Retry sends the same answers again; nothing is asked twice.
      repository.failSave = false;
      await tapKey(tester, 'questionnaire_retry');
      expect(repository.saves, 2);
      expect(repository.lastFaithStage, FaithStage.values.first);
      expect(find.textContaining('STEP 1 OF 6'), findsNothing);
      expect(completions, 1);
    });
  }
}
