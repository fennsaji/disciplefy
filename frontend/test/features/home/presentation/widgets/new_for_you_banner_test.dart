import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/new_for_you_banner.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

const _bannerText = {
  NewForYouKind.paths: (
    'Explore more learning paths',
    'From the Gospels to prayer and hard times.',
    'Browse paths',
  ),
  NewForYouKind.memory: (
    "Keep today's verse with you",
    'Practise Psalm 23:1 in one minute.',
    'Practise · 1 min',
  ),
  NewForYouKind.generate: (
    'Study any verse or topic',
    'A guide for whatever is on your mind.',
    'Start a study',
  ),
  NewForYouKind.discipler: (
    'Ask a question about the Bible',
    'Answers that point back to Scripture.',
    'Ask Discipler',
  ),
  NewForYouKind.fellowships: (
    'Join the Disciplefy fellowship',
    'Study New Believer Essentials with others.',
    'Join Disciplefy',
  ),
};

void main() {
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget app(
    Widget child, {
    bool dark = false,
    String? language,
  }) {
    if (language != null) {
      translations.language = AppLanguage.fromCode(language);
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/intro/:kind',
          builder: (_, s) =>
              Scaffold(body: Text('stub:intro:${s.pathParameters['kind']}')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Widget banner(
    NewForYouKind kind, {
    VoidCallback? onOpen,
    VoidCallback? onDismiss,
  }) =>
      NewForYouBanner(
        kind: kind,
        verseReference: 'Psalm 23:1',
        pathTitle: 'New Believer Essentials',
        onOpen: onOpen ?? () {},
        onDismiss: onDismiss ?? () {},
      );

  testWidgets('banner: CTA opens, × dismisses, text ≥12pt', (tester) async {
    var opened = 0, dismissed = 0;
    await tester.pumpWidget(app(NewForYouBanner(
      kind: NewForYouKind.paths,
      onOpen: () => opened++,
      onDismiss: () => dismissed++,
    )));
    await tester.pumpAndSettle();
    expect(find.text('NEW FOR YOU'), findsOneWidget);
    await tester.tap(find.text('Browse paths'));
    expect(opened, 1);
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    expect(dismissed, 1);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect((t.style?.fontSize ?? 14) >= 12, isTrue, reason: t.data);
    }
  });

  testWidgets('CTA is a 32px pill', (tester) async {
    await tester.pumpWidget(app(banner(NewForYouKind.paths)));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FilledButton)).height, 32);
  });

  for (final kind in NewForYouKind.values) {
    testWidgets('$kind banner copy', (tester) async {
      await tester.pumpWidget(app(banner(kind)));
      await tester.pumpAndSettle();
      final (title, sub, cta) = _bannerText[kind]!;
      expect(find.text(title), findsOneWidget);
      expect(find.text(sub), findsOneWidget);
      expect(find.text(cta), findsOneWidget);
    });
  }

  testWidgets('memory and fellowships fall back when there is no ref or path',
      (tester) async {
    await tester.pumpWidget(app(Column(children: [
      NewForYouBanner(
          kind: NewForYouKind.memory, onOpen: () {}, onDismiss: () {}),
      const SizedBox(height: 8),
      NewForYouBanner(
          kind: NewForYouKind.fellowships, onOpen: () {}, onDismiss: () {}),
    ])));
    await tester.pumpAndSettle();
    expect(find.text("Practise today's verse in one minute."), findsOneWidget);
    expect(find.text('Study the same lesson with others.'), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
  });

  for (final language in ['en', 'hi', 'ml']) {
    testWidgets('$language banners at 360px fit beside the CTA',
        (tester) async {
      useSurface(tester, const Size(360, 1400));
      await tester.pumpWidget(app(
        Column(children: [
          for (final kind in NewForYouKind.values) ...[
            banner(kind),
            const SizedBox(height: 8),
          ],
        ]),
        language: language,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester);
    });
  }

  for (final language in ['hi', 'ml']) {
    for (final dark in [false, true]) {
      testWidgets('$language 320px every banner fits (dark: $dark)',
          (tester) async {
        useSurface(tester, const Size(320, 1400));
        await tester.pumpWidget(app(
          Column(children: [
            for (final kind in NewForYouKind.values) ...[
              banner(kind),
              const SizedBox(height: 8),
            ],
          ]),
          dark: dark,
          language: language,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        expect(find.textContaining('nfy.'), findsNothing);
      });
    }
  }

  group('NewForYouSection', () {
    late NewForYouCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cubit = NewForYouCubit(
          prefs: await SharedPreferences.getInstance(),
          clock: () => DateTime(2026, 10, 6));
    });

    tearDown(() => cubit.close());

    Widget section() => BlocProvider.value(
          value: cubit,
          child: const NewForYouSection(verseReference: 'Psalm 23:1'),
        );

    testWidgets('nothing without a banner', (tester) async {
      await tester.pumpWidget(app(section()));
      await tester.pumpAndSettle();
      expect(find.byType(NewForYouBanner), findsNothing);
    });

    testWidgets('opening marks it done and opens the introduction',
        (tester) async {
      await cubit.load(
          'u1',
          const NewForYouEligibility(
              firstLessonCompleted: true, available: {NewForYouKind.memory}));
      await tester.pumpWidget(app(section()));
      await tester.pumpAndSettle();
      expect(find.text('Practise Psalm 23:1 in one minute.'), findsOneWidget);
      await tester.tap(find.text('Practise · 1 min'));
      await tester.pumpAndSettle();
      expect(find.text('stub:intro:memory'), findsOneWidget);
      expect(cubit.state, isNull);
    });

    testWidgets('× dismisses it', (tester) async {
      await cubit.load(
          'u1',
          const NewForYouEligibility(
              firstLessonCompleted: true, available: {NewForYouKind.paths}));
      await tester.pumpWidget(app(section()));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(NewForYouBanner), findsNothing);
      expect(cubit.state, isNull);
    });
  });
}
