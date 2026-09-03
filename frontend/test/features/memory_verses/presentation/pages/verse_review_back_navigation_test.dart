import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/verse_review_page.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import 'memory_verses_reset_flow_test.mocks.dart';

class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

/// Regression for the "Page not found: /memory-verses/practice" report
/// (3 Sept 2026). When the review page is the root of the stack — which is
/// how a push notification used to open it — there is nothing to pop, and
/// the old fallback built '/memory-verses/practice/' from the empty verse id.
/// Back must land on the memory verse list instead.
void main() {
  late MockTranslationService translations;
  late MockWalkthroughRepository walkthrough;
  late _MockMemoryVerseBloc bloc;
  late GoRouter router;

  setUpAll(() {
    translations = MockTranslationService();
    when(translations.getTranslation(any, any)).thenAnswer(
        (i) => (i.positionalArguments[0] as String).split('.').last);
    sl.registerLazySingleton<TranslationService>(() => translations);
  });

  tearDownAll(() => sl.reset());

  setUp(() {
    bloc = _MockMemoryVerseBloc();
    // Any non-loaded state renders just a spinner: the cheapest body.
    whenListen<MemoryVerseState>(bloc, const Stream<MemoryVerseState>.empty(),
        initialState: const MemoryVerseInitial());

    walkthrough = MockWalkthroughRepository();
    when(walkthrough.hasSeen(any)).thenAnswer((_) async => true);
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerLazySingleton<WalkthroughRepository>(() => walkthrough);

    router = GoRouter(
      // Root of the stack, exactly like a push-opened screen: no verse id.
      initialLocation: '/memory-verse-review',
      routes: [
        GoRoute(
          path: '/memory-verse-review',
          builder: (_, __) => BlocProvider<MemoryVerseBloc>.value(
            value: bloc,
            child: const VerseReviewPage(verseId: ''),
          ),
        ),
        GoRoute(
          path: '/memory-verses',
          builder: (_, __) => const Scaffold(body: Text('memory verse list')),
        ),
        GoRoute(
          path: '/memory-verses/practice/:verseId',
          builder: (_, __) => const Scaffold(body: Text('practice')),
        ),
      ],
      errorBuilder: (_, __) => const Scaffold(body: Text('not-found')),
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pump();
  }

  String path() => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('back from a root review page with no verse id goes to the list',
      (tester) async {
    await pumpPage(tester);
    expect(path(), '/memory-verse-review');

    // The page draws its own leading IconButton wired to
    // _handleBackNavigation, not a Navigator BackButton.
    final leading = find.descendant(
        of: find.byType(AppBar), matching: find.byType(IconButton));
    expect(leading, findsWidgets);
    await tester.tap(leading.first);
    await tester.pumpAndSettle();

    expect(path(), '/memory-verses');
    expect(find.text('memory verse list'), findsOneWidget);
    expect(find.text('not-found'), findsNothing);
    expect(path(), isNot(startsWith('/memory-verses/practice')));
  });
}
