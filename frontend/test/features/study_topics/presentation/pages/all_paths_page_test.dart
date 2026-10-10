import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/all_paths_page.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';
import '../../helpers/paged_paths_repository.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

LearningPath _path(
  String id,
  String title, {
  required String category,
  bool enrolled = false,
  int progress = 0,
  int total = 5,
  bool guestAccessible = false,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: title,
      description: '',
      iconName: 'park',
      color: '#10B981',
      totalXp: 250,
      estimatedDays: 21,
      discipleLevel: 'seeker',
      topicsCount: total,
      category: category,
      isEnrolled: enrolled,
      progressPercentage: progress,
      guestAccessible: guestAccessible,
    );

final pathA = _path('a', 'New Believer Essentials',
    category: 'Foundations', enrolled: true, progress: 38, total: 8);
final pathB = _path('b', 'The Gospel of Mark', category: 'Gospels');
final pathC = _path('c', 'Rooted in Christ', category: 'Foundations');

void main() {
  late FakeTranslationService translations;
  late PagedPathsRepository repository;
  AllPathsBloc? bloc;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    repository = PagedPathsRepository([]);
    bloc = null;
  });

  tearDown(() async {
    GuestPathEnrollment.reset();
    await bloc?.close();
    await sl.reset();
  });

  Future<void> pumpAllPaths(
    WidgetTester tester, {
    required List<LearningPath> paths,
    bool dark = true,
    AppLanguage lang = AppLanguage.english,
    Size size = const Size(390, 900),
  }) async {
    translations.language = lang;
    useSurface(tester, size);
    repository.paths
      ..clear()
      ..addAll(paths);
    // Created in the test's zone so its requests run under the fake clock.
    bloc = AllPathsBloc(repository: repository);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: BlocProvider<AllPathsBloc>.value(
        value: bloc!,
        child: const AllPathsPage(language: 'en'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('current path pinned with Current tag; chips filter',
      (tester) async {
    await pumpAllPaths(tester, paths: [pathB, pathC, pathA]);
    expect(
        tester.getTopLeft(find.text('Current')).dy <
            tester.getTopLeft(find.text(pathB.title)).dy,
        isTrue);
    expect(
        tester.getTopLeft(find.text(pathA.title)).dy <
            tester.getTopLeft(find.text(pathB.title)).dy,
        isTrue);
    expect(find.text('Lesson 4 of 8'), findsOneWidget);
    expect(find.text('All paths'), findsOneWidget);
    expect(find.text('3 paths'), findsOneWidget);

    await tester.tap(find.text('Gospels'));
    await tester.pumpAndSettle();
    expect(find.text(pathA.title), findsNothing);
    expect(find.text(pathB.title), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text(pathA.title), findsOneWidget);
  });

  testWidgets('chips: All first, then categories in curated order',
      (tester) async {
    await pumpAllPaths(tester, paths: [pathC, pathB, pathA]);
    final all = tester.getTopLeft(find.text('All')).dx;
    final foundations = tester.getTopLeft(find.text('Foundations')).dx;
    final gospels = tester.getTopLeft(find.text('Gospels')).dx;
    expect(all < foundations && foundations < gospels, isTrue);
  });

  testWidgets('opens with the first page and searches on the server',
      (tester) async {
    await pumpAllPaths(tester, paths: [pathA, pathB]);
    expect(repository.flatOffsets, [0]);
    await tester.tap(find.byKey(const Key('all_paths_search_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('all_paths_search_field')), 'mark');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repository.searches.last, 'mark');
    expect(find.text(pathB.title), findsOneWidget);
    expect(find.text(pathC.title), findsNothing);
  });

  testWidgets(
      'a path row still opens after a pushed path page was dropped by go '
      '(its push future never completes)', (tester) async {
    useSurface(tester, const Size(390, 900));
    repository.paths.add(pathB);
    bloc = AllPathsBloc(repository: repository);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AllPathsBloc>.value(
          value: bloc!,
          child: const AllPathsPage(language: 'en'),
        ),
      ),
      GoRoute(
        path: '/learning-path/:id',
        builder: (_, __) => const Scaffold(body: Text('path page')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.darkTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(pathB.title));
    await tester.pumpAndSettle();
    expect(find.text('path page'), findsOneWidget);

    // Lesson complete → Back home: `go` drops the pushed page and its
    // push future is never completed.
    router.go('/');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('path page'), findsNothing);

    await tester.tap(find.text(pathB.title));
    await tester.pumpAndSettle();
    expect(find.text('path page'), findsOneWidget);
  });

  test('the route is /paths and stays open for guests', () {
    expect(AppRoutes.allPaths, '/paths');
    expect(GuestRouteGate.reasonFor(AppRoutes.allPaths), isNull);
  });

  group('guest', () {
    setUp(() {
      final guest = _MockGuest();
      final flags = _MockFlags();
      when(() => guest.isGuest).thenReturn(true);
      when(() => flags.guestMode).thenReturn(true);
      sl.registerSingleton<GuestSessionService>(guest);
      sl.registerSingleton<RolloutFlags>(flags);
      GuestPathEnrollment.currentUserId = () => 'guest-1';
    });

    testWidgets(
        'own path open, other rows locked and open the account sheet instead '
        'of the path', (tester) async {
      GuestPathEnrollment.record('a');
      final second =
          _path('s', 'Second path', category: 'Growth', guestAccessible: true);
      await pumpAllPaths(tester, paths: [pathA, second, pathB]);

      expect(find.byKey(const Key('guest_path_lock_a')), findsNothing);
      expect(find.byKey(const Key('guest_path_lock_s')), findsOneWidget);
      expect(find.byKey(const Key('guest_path_lock_b')), findsOneWidget);

      await tester.tap(find.text('Second path'));
      await tester.pumpAndSettle();
      expect(find.text('Your next path needs an account'), findsOneWidget);
    });
  });

  for (final width in fitWidths) {
    for (final lang in AppLanguage.values) {
      for (final dark in [true, false]) {
        final name = '${lang.code} ${dark ? 'dark' : 'light'}';
        testWidgets('fits ${width.toInt()} wide ($name)', (tester) async {
          await pumpAllPaths(
            tester,
            paths: [pathB, pathC, pathA],
            dark: dark,
            lang: lang,
            size: Size(width, 700),
          );
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
