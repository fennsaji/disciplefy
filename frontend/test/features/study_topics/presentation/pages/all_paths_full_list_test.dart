import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/all_paths_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/learning_path_category_page.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';
import '../../helpers/paged_paths_repository.dart';

/// All paths and a category's "See all" with the real bloc over a server
/// that pages: every path must be reachable, not only the first page.
void main() {
  late PagedPathsRepository repository;
  late LearningPathsBloc bloc;

  setUpAll(loadAppFonts);

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });

  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    useSurface(tester, const Size(390, 900));
    bloc = LearningPathsBloc(
      repository: repository,
      resetLearningProgress: ResetLearningProgress(repository),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: BlocProvider<LearningPathsBloc>.value(value: bloc, child: page),
    ));
    await tester.pumpAndSettle();
  }

  group('All paths', () {
    setUp(() {
      repository = PagedPathsRepository([
        for (var i = 1; i <= 120; i++)
          pagedPath(i, category: i > 100 ? 'Prophets' : 'Foundations'),
      ]);
    });

    testWidgets('lists every path across three pages and counts them all',
        (tester) async {
      await pump(tester, const AllPathsPage(language: 'en'));

      expect(find.text('120 paths'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('all_paths_row_p120')), 400,
          scrollable: find.descendant(
              of: find.byKey(const Key('all_paths_list')),
              matching: find.byType(Scrollable)));
      expect(find.text('Path 120'), findsOneWidget);
    });

    testWidgets('a category only on the last page has its chip and paths',
        (tester) async {
      await pump(tester, const AllPathsPage(language: 'en'));

      await tester.tap(find.byKey(const Key('all_paths_chip_Prophets')));
      await tester.pumpAndSettle();
      expect(find.text('Path 101'), findsOneWidget);
      expect(find.text('Path 1'), findsNothing);
    });

    testWidgets('search finds a path from the third page', (tester) async {
      await pump(tester, const AllPathsPage(language: 'en'));

      await tester.tap(find.byKey(const Key('all_paths_search_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('all_paths_search_field')), 'path 115');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Path 115'), findsOneWidget);
      expect(find.text('Path 1'), findsNothing);
    });

    testWidgets('a failed search offers a retry instead of "no match"',
        (tester) async {
      await pump(tester, const AllPathsPage(language: 'en'));
      repository.failFlatAt = 0;

      await tester.tap(find.byKey(const Key('all_paths_search_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('all_paths_search_field')), 'path 115');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      repository.failFlatAt = null;
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.text('Path 115'), findsOneWidget);
    });
  });

  group('category See all', () {
    setUp(() {
      repository = PagedPathsRepository([
        for (var i = 1; i <= 12; i++) pagedPath(i),
      ]);
    });

    testWidgets('search matches a path that was not loaded yet',
        (tester) async {
      await pump(
          tester,
          const LearningPathCategoryPage(
              category: 'Foundations', language: 'en'));
      // Rows are tall enough that the first pages fill the screen.
      await tester.tap(find.byKey(const Key('path_category_search_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('path_category_search_field')), 'path 12');
      await tester.pumpAndSettle();
      expect(find.text('Path 12'), findsOneWidget);
    });

    testWidgets('a failing page is not retried in a tight loop',
        (tester) async {
      repository.failCategoryPages = true;
      await pump(
          tester,
          const LearningPathCategoryPage(
              category: 'Foundations', language: 'en'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(repository.categoryOffsets.length, lessThanOrEqualTo(2));
    });
  });
}
