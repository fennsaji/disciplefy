import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/plan_summary_card.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

PlanSummaryCard _trialCard() => PlanSummaryCard(
      planName: 'Standard',
      isTrial: true,
      trialEnds: DateTime(2027, 3, 31),
      left: 30,
      dailyLimit: 40,
      resetsAt: DateTime(2026, 10, 7, 5, 30),
      costs: const {StudyMode.quick: 10, StudyMode.standard: 20},
    );

PlanSummaryCard _paidPlusCard() => PlanSummaryCard(
      planName: 'Plus',
      isTrial: false,
      renewsOn: DateTime(2026, 11, 7),
      providerLabel: 'Google Play',
      left: 45,
      dailyLimit: 60,
      resetsAt: DateTime(2026, 10, 7, 5, 30),
      costs: const {
        StudyMode.quick: 10,
        StudyMode.standard: 20,
        StudyMode.deep: 30,
      },
    );

Widget _screen(Widget card) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: card,
      ),
    );

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  testWidgets('trial: name, Trial tag, until date, ring, cost line; no billing',
      (tester) async {
    await tester.pumpWidget(welcomeApp(screen: _screen(_trialCard())));
    await tester.pumpAndSettle();

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Free trial until March 31, 2027'), findsOneWidget);
    expect(find.text('30 left today'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('of 40'), findsOneWidget);
    expect(find.text('Resets at 5:30 AM'), findsOneWidget);
    expect(find.text('Quick Read 10 · Standard 20'), findsOneWidget);
    expect(find.textContaining('Billed via'), findsNothing);
    expect(find.textContaining('Renews'), findsNothing);
  });

  testWidgets('paid Plus on Google Play: renewal and billing shown',
      (tester) async {
    await tester.pumpWidget(welcomeApp(screen: _screen(_paidPlusCard())));
    await tester.pumpAndSettle();

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Trial'), findsNothing);
    expect(find.textContaining('Free trial'), findsNothing);
    expect(find.text('Renews November 7, 2026'), findsOneWidget);
    expect(find.text('Billed via Google Play'), findsOneWidget);
    expect(find.text('45 left today'), findsOneWidget);
    expect(find.text('Quick Read 10 · Standard 20 · Deep Dive 30'),
        findsOneWidget);
  });

  testWidgets('no provider (web trial, system): no "Billed via" line',
      (tester) async {
    await tester.pumpWidget(welcomeApp(
      screen: _screen(PlanSummaryCard(
        planName: 'Standard',
        isTrial: false,
        renewsOn: DateTime(2026, 11, 7),
        left: 10,
        dailyLimit: 40,
        resetsAt: null,
        costs: const {},
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Billed via'), findsNothing);
    expect(find.textContaining('Resets at'), findsNothing);
    expect(find.text('10 left today'), findsOneWidget);
  });

  testWidgets('unlimited plan: no "of N" and no "left today" count',
      (tester) async {
    await tester.pumpWidget(welcomeApp(
      screen: _screen(PlanSummaryCard(
        planName: 'Premium',
        isTrial: false,
        left: 0,
        dailyLimit: -1,
        resetsAt: DateTime(2026, 10, 7, 5, 30),
        costs: const {StudyMode.quick: 10},
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('left today'), findsNothing);
    expect(find.textContaining('of -1'), findsNothing);
    expect(find.text('Unlimited credits'), findsOneWidget);
  });

  group('320px fit', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 800));
          await tester.pumpWidget(welcomeApp(
            dark: dark,
            screen: _screen(Column(
              children: [_trialCard(), _paidPlusCard()],
            )),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  });
}
