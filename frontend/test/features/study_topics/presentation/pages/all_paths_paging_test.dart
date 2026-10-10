import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/all_paths_page.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';
import '../../helpers/paged_paths_repository.dart';

/// All paths over a server that pages: the first page shows at once, the
/// rest load on scroll, and chips, categories, search and the count come
/// from the server rather than from the paths loaded so far.
void main() {
  late PagedPathsRepository repository;
  late AllPathsBloc bloc;

  setUpAll(loadAppFonts);

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    // 60 paths; "Prophets" only from path 51, far past the first page.
    repository = PagedPathsRepository([
      for (var i = 1; i <= 60; i++)
        pagedPath(i, category: i > 50 ? 'Prophets' : 'Foundations'),
    ]);
  });

  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    useSurface(tester, const Size(390, 900));
    bloc = AllPathsBloc(repository: repository);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: BlocProvider<AllPathsBloc>.value(
        value: bloc,
        child: const AllPathsPage(language: 'en'),
      ),
    ));
    if (settle) await tester.pumpAndSettle();
  }

  Finder listScrollable() => find.descendant(
      of: find.byKey(const Key('all_paths_list')),
      matching: find.byType(Scrollable));

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(listScrollable(), const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('shows the first page while later pages are still loading',
      (tester) async {
    final gate = Completer<void>();
    repository.flatGates[AllPathsBloc.pageSize] = gate;
    await pump(tester);

    expect(find.text('Path 1'), findsOneWidget);
    expect(repository.flatOffsets, [0]);
    expect(repository.flatLimits.single, AllPathsBloc.pageSize);
    gate.complete();
  });

  testWidgets('scrolling to the end requests the next page', (tester) async {
    await pump(tester);
    expect(repository.flatOffsets, [0]);

    // Only as far as the first page's end, so page 3 is not asked too.
    for (var i = 0;
        i < 12 && !repository.flatOffsets.contains(AllPathsBloc.pageSize);
        i++) {
      await tester.drag(listScrollable(), const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(repository.flatOffsets, [0, AllPathsBloc.pageSize]);
    await tester.scrollUntilVisible(
        find.byKey(const Key('all_paths_row_p26')), 300,
        scrollable: listScrollable());
    expect(find.text('Path 26'), findsOneWidget);
  });

  testWidgets('counts every path from the server total, not the loaded page',
      (tester) async {
    await pump(tester);
    expect(find.text('60 paths'), findsOneWidget);
  });

  testWidgets('every category has a chip with only the first page loaded',
      (tester) async {
    await pump(tester);
    expect(repository.flatOffsets, [0]);
    expect(find.byKey(const Key('all_paths_chip_Foundations')), findsOneWidget);
    expect(find.byKey(const Key('all_paths_chip_Prophets')), findsOneWidget);
  });

  testWidgets('a chip lists its category from the server', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('all_paths_chip_Prophets')));
    await tester.pumpAndSettle();

    expect(repository.categoryRequests, ['Prophets']);
    expect(find.text('Path 51'), findsOneWidget);
    expect(find.text('Path 1'), findsNothing);
  });

  testWidgets('search asks the server', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('all_paths_search_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('all_paths_search_field')), 'path 55');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(repository.searches, contains('path 55'));
    expect(find.text('Path 55'), findsOneWidget);
    expect(find.text('Path 1'), findsNothing);
  });

  testWidgets(
      'a failing next page keeps the first page, offers a footer retry and is '
      'not retried on its own', (tester) async {
    repository.failFlatAt = AllPathsBloc.pageSize;
    await pump(tester);
    await scrollToEnd(tester);
    await tester.pump(const Duration(seconds: 5));
    await scrollToEnd(tester);

    expect(find.byKey(const Key('all_paths_more_retry')), findsOneWidget);
    expect(find.text('Path 25'), findsOneWidget);
    expect(
        repository.flatOffsets.where((o) => o == AllPathsBloc.pageSize).length,
        1);

    repository.failFlatAt = null;
    await tester.tap(find.byKey(const Key('all_paths_more_retry')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('all_paths_row_p26')), 300,
        scrollable: listScrollable());
    expect(find.text('Path 26'), findsOneWidget);
  });

  testWidgets('a failing first page shows an error with Retry, not a spinner',
      (tester) async {
    repository.failFlatAt = 0;
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    repository.failFlatAt = null;
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Path 1'), findsOneWidget);
  });

  testWidgets('chips still come from the loaded paths if categories fail',
      (tester) async {
    repository.failSummaries = true;
    await pump(tester);
    expect(find.text('Path 1'), findsOneWidget);
    expect(find.byKey(const Key('all_paths_chip_Foundations')), findsOneWidget);
  });
}
