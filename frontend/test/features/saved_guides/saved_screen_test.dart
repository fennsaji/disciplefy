import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/pages/saved_screen.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/guide_list_item.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/library_continue_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/services/reading_progress_store.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

class _MockSavedBloc extends MockBloc<SavedGuidesEvent, SavedGuidesState>
    implements UnifiedSavedGuidesBloc {}

SavedGuideEntity _guide(
  String id,
  String title, {
  GuideType type = GuideType.topic,
  String mode = 'standard',
  bool saved = true,
  DateTime? accessed,
}) =>
    SavedGuideEntity(
      id: id,
      title: title,
      content: 'content',
      type: type,
      studyMode: mode,
      createdAt: DateTime(2026, 9, 2),
      lastAccessedAt: accessed ?? DateTime(2026, 9, 20),
      isSaved: saved,
      verseReference: type == GuideType.verse ? title : null,
      topicName: type == GuideType.topic ? title : null,
    );

final _saved = [
  _guide('g1', 'Forgiveness', accessed: DateTime(2026, 9, 28)),
  _guide('g2', 'John 3:16', type: GuideType.verse, mode: 'quick'),
  _guide('g3', 'What does the Bible say about suffering?', mode: 'deep'),
  _guide('g4', 'Psalm 23', type: GuideType.verse, mode: 'lectio'),
  _guide('g5', 'Why Read the Bible?'),
];

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _MockSavedBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(), prefs));
    bloc = _MockSavedBloc();
    GetIt.instance.registerFactory<UnifiedSavedGuidesBloc>(() => bloc);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pumpLibrary(
    WidgetTester tester, {
    required bool dark,
    required SavedGuidesState state,
    int? tab,
  }) async {
    whenListen(bloc, const Stream<SavedGuidesState>.empty(),
        initialState: state);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: SavedScreen(initialTabIndex: tab),
    ));
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: title, tabs, continue card with progress, grid',
        (tester) async {
      _useNarrowPhone(tester);
      await ReadingProgressStore().save('g1', 3, 6);

      await pumpLibrary(tester,
          dark: dark,
          state: SavedGuidesApiLoaded(
            savedGuides: _saved,
            recentGuides: const [],
          ));

      expect(tester.takeException(), isNull);
      expect(find.text('Your library'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      // The Continue card resumes the guide with stored progress.
      expect(find.byType(LibraryContinueCard), findsOneWidget);
      expect(find.text('CONTINUE · SECTION 3 OF 6'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(LibraryContinueCard),
              matching: find.text('Forgiveness')),
          findsOneWidget);
      expect(find.byKey(const Key('library_continue_progress_fill')),
          findsOneWidget);
      final eyebrow =
          tester.widget<Text>(find.text('CONTINUE · SECTION 3 OF 6'));
      expect(eyebrow.style?.color, AppColors.brandGold);
      // Its guide is not repeated in the grid.
      expect(find.byKey(const ValueKey('saved_g1')), findsNothing);
      expect(find.byKey(const ValueKey('saved_g2')), findsOneWidget);
      expect(find.text('Scripture'), findsWidgets);
      expect(find.text('Question'), findsWidgets);
      expect(find.textContaining('Quick Read'), findsOneWidget);
    });

    testWidgets('$theme: cards in a row share a height', (tester) async {
      _useNarrowPhone(tester);
      await pumpLibrary(tester,
          dark: dark,
          state: SavedGuidesApiLoaded(
            savedGuides: _saved,
            recentGuides: const [],
          ));
      final left = tester.getSize(find.byKey(const ValueKey('saved_g2')));
      final right = tester.getSize(find.byKey(const ValueKey('saved_g3')));
      expect(left.height, right.height);
      // Content-sized, not a fixed tall tile.
      expect(left.height, lessThan(200));
    });

    testWidgets('$theme: no progress shows plain CONTINUE', (tester) async {
      _useNarrowPhone(tester);
      await pumpLibrary(tester,
          dark: dark,
          state: SavedGuidesApiLoaded(
            savedGuides: _saved,
            recentGuides: const [],
          ));
      expect(tester.takeException(), isNull);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.byKey(const Key('library_continue_progress_fill')),
          findsNothing);
      // Most recently accessed guide.
      expect(
          find.descendant(
              of: find.byType(LibraryContinueCard),
              matching: find.text('Forgiveness')),
          findsOneWidget);
    });

    testWidgets('$theme: empty saved tab hides the continue card',
        (tester) async {
      _useNarrowPhone(tester);
      await pumpLibrary(tester,
          dark: dark,
          state: const SavedGuidesApiLoaded(
            savedGuides: [],
            recentGuides: [],
            hasMoreSaved: false,
          ));
      expect(tester.takeException(), isNull);
      expect(find.byType(LibraryContinueCard), findsNothing);
      expect(find.text('No Saved Studies'), findsOneWidget);
    });

    testWidgets('$theme: auth required state', (tester) async {
      _useNarrowPhone(tester);
      await pumpLibrary(tester,
          dark: dark,
          state: const SavedGuidesAuthRequired(
            message: 'Sign in to see your guides',
            isForSavedGuides: true,
          ));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('library_sign_in')), findsOneWidget);
    });

    testWidgets('$theme: error state retries the current tab', (tester) async {
      _useNarrowPhone(tester);
      await pumpLibrary(tester,
          dark: dark, tab: 1, state: const SavedGuidesError(message: 'boom'));
      expect(tester.takeException(), isNull);
      clearInteractions(bloc);
      await tester.tap(find.byKey(const Key('library_retry')));
      verify(() => bloc.add(const LoadRecentGuidesFromApi(refresh: true)))
          .called(1);
    });
  }

  testWidgets('bookmark unsaves on Saved and saves on Recent', (tester) async {
    _useNarrowPhone(tester);
    await pumpLibrary(tester,
        dark: true,
        state: SavedGuidesApiLoaded(
          savedGuides: _saved,
          recentGuides: [
            _guide('r1', 'Hope', saved: false, accessed: DateTime(2026, 9, 28)),
            _guide('r2', 'Grace', saved: false),
            _guide('r3', 'Faith', saved: false),
          ],
        ));

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('saved_g2')),
        matching: find.byType(IconButton)));
    verify(() =>
            bloc.add(const ToggleGuideApiEvent(guideId: 'g2', save: false)))
        .called(1);

    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    // The tab listener fires while and after the index changes (as before).
    verify(() => bloc.add(const TabChangedEvent(tabIndex: 1)))
        .called(greaterThanOrEqualTo(1));
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('recent_r2')),
        matching: find.byType(IconButton)));
    verify(() => bloc.add(const ToggleGuideApiEvent(guideId: 'r2', save: true)))
        .called(1);
  });

  testWidgets('search filters the grid locally', (tester) async {
    _useNarrowPhone(tester);
    await pumpLibrary(tester,
        dark: false,
        state: SavedGuidesApiLoaded(
          savedGuides: _saved,
          recentGuides: const [],
        ));

    await tester.tap(find.byKey(const Key('library_search_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('library_search_field')), 'psalm');
    await tester.pumpAndSettle();

    expect(find.byType(LibraryContinueCard), findsNothing);
    expect(find.byType(GuideListItem), findsOneWidget);
    expect(find.text('Psalm 23'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('library_search_field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byType(GuideListItem), findsNothing);
    expect(find.textContaining('No guides match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library_search_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Your library'), findsOneWidget);
    expect(find.byType(LibraryContinueCard), findsOneWidget);
  });

  group('pickContinueGuide', () {
    test('prefers the most recently read unfinished guide', () {
      final progress = {
        'g2': ReadingProgress(
            section: 2, total: 6, updatedAt: DateTime(2026, 9, 25)),
        'g3': ReadingProgress(
            section: 4, total: 6, updatedAt: DateTime(2026, 9, 27)),
        'g4': ReadingProgress(
            section: 6, total: 6, updatedAt: DateTime(2026, 9, 29)),
      };
      expect(pickContinueGuide(_saved, progress)?.id, 'g3');
    });

    test('falls back to the most recently accessed guide', () {
      expect(pickContinueGuide(_saved, const {})?.id, 'g1');
    });

    test('null when there are no guides', () {
      expect(pickContinueGuide(const [], const {}), isNull);
    });
  });
}
