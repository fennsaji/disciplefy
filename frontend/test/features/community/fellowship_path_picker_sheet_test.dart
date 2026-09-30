// Widget tests for the mentor's "Choose a learning path" sheet: header,
// level groups with counts, level-gradient rows with each path's own icon,
// Current / Completed tags, level filter, search, states, and that tapping a
// path closes the sheet and hands the path back. Rendered dark and light at
// 320x640 in English, Hindi and Malayalam with nothing overflowing.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_path_picker_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

// ── Fixtures ────────────────────────────────────────────────────────────────

LearningPath _p(
  String id,
  String title,
  String level, {
  String icon = 'book',
  String category = '',
  int? order,
  int xp = 400,
  int days = 14,
  bool completed = false,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: title,
      description: 'A guided journey through the essentials of the faith, '
          'studied together one lesson at a time with your fellowship.',
      iconName: icon,
      color: '#4F46E5',
      totalXp: xp,
      estimatedDays: days,
      discipleLevel: level,
      topicsCount: 8,
      category: category,
      displayOrder: order,
      fellowshipCompleted: completed,
    );

final _nbe =
    _p('nbe', 'New Believer Essentials', 'seeker', icon: 'menu_book', order: 1);
final _rooted = _p('rooted', 'Rooted in Christ', 'seeker',
    icon: 'park', order: 2, completed: true);
final _spirit =
    _p('spirit', 'Who Is the Holy Spirit?', 'follower', icon: 'air');
final _mount = _p('mount', 'Sermon on the Mount', 'disciple',
    icon: 'not_a_known_icon', category: 'Foundations of Faith');
final _lead =
    _p('lead', 'Leading Others', 'leader', icon: 'groups', xp: 0, days: 0);

// Arrives in the mentor's personal order; the sheet re-sorts by level.
final _listing = [_lead, _spirit, _rooted, _mount, _nbe];

LearningPathsLoaded _loaded(List<LearningPath> paths) => LearningPathsLoaded(
      categories: const [],
      searchQuery: '',
      searchResults: paths,
    );

// ── Harness ─────────────────────────────────────────────────────────────────

late FakeTranslationService _translations;
late _MockPathsBloc _paths;
late List<LearningPath> _selected;

Future<void> _open(
  WidgetTester tester, {
  bool dark = true,
  AppLanguage language = AppLanguage.english,
  Size size = const Size(320, 640),
}) async {
  _translations.language = language;
  useSurface(tester, size);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(language.code),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (_) => BlocProvider<LearningPathsBloc>.value(
              value: _paths,
              child: FellowshipPathPickerSheet(
                fellowshipId: 'f1',
                fellowshipName: 'Grace Fellowship',
                currentPathId: 'nbe',
                onPathSelected: _selected.add,
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void _expectClean(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  // Descriptions are clamped to two lines by design.
  expectNoTruncatedText(tester, allow: {'A guided journey'});
}

const _variants = [
  (AppLanguage.english, true),
  (AppLanguage.english, false),
  (AppLanguage.hindi, true),
  (AppLanguage.hindi, false),
  (AppLanguage.malayalam, true),
  (AppLanguage.malayalam, false),
];

void main() {
  setUpAll(() async {
    await loadAppFonts();
    registerFallbackValue(const LoadFlatLearningPaths());
  });

  setUp(() {
    _translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(_translations);
    _paths = _MockPathsBloc();
    _selected = [];
    when(() => _paths.state).thenReturn(_loaded(_listing));
  });

  tearDown(() async => sl.reset());

  group('fits 320x640', () {
    for (final v in _variants) {
      testWidgets('${v.$1.code} ${v.$2 ? 'dark' : 'light'}', (tester) async {
        await _open(tester, language: v.$1, dark: v.$2);
        _expectClean(tester);
        expect(find.byType(FellowshipPathPickerSheet), findsOneWidget);
        // Scroll through the whole list: nothing overflows further down.
        await tester.dragUntilVisible(find.text('Leading Others'),
            find.byType(CustomScrollView), const Offset(0, -150));
        await tester.pumpAndSettle();
        _expectClean(tester);
        expect(find.text('Leading Others'), findsOneWidget);
      });
    }
  });

  testWidgets('header: fellowship eyebrow, title and subtitle', (tester) async {
    await _open(tester);
    expect(find.text('GRACE FELLOWSHIP'), findsOneWidget);
    expect(find.text('Choose a learning path'), findsOneWidget);
    expect(find.text('Everyone studies it together, one lesson at a time.'),
        findsOneWidget);
    expect(find.text('Pick a Learning Path for Your Fellowship'), findsNothing);
  });

  testWidgets('groups by level in order, each with its path count',
      (tester) async {
    await _open(tester, size: const Size(320, 2400));
    expect(find.text('2 paths'), findsOneWidget);
    expect(find.text('1 path'), findsNWidgets(3));

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    // Seeker (curated order), follower, disciple, leader.
    expect(y('New Believer Essentials'), lessThan(y('Rooted in Christ')));
    expect(y('Rooted in Christ'), lessThan(y('Who Is the Holy Spirit?')));
    expect(y('Who Is the Holy Spirit?'), lessThan(y('Sermon on the Mount')));
    expect(y('Sermon on the Mount'), lessThan(y('Leading Others')));

    // Level headings sit left, counts right-aligned in the same row.
    expect(find.text('SEEKER'), findsOneWidget);
    expect(tester.getTopLeft(find.text('SEEKER')).dy,
        closeTo(tester.getTopLeft(find.text('2 paths')).dy, 4));
  });

  testWidgets('rows use each path\'s own icon from iconForPath',
      (tester) async {
    await _open(tester, size: const Size(320, 2400));
    for (final path in _listing) {
      final row = find.byKey(Key('path_picker_row_${path.id}'));
      final icon = tester.widget<Icon>(
          find.descendant(of: row, matching: find.byType(Icon)).first);
      expect(icon.icon, iconForPath(path.iconName, category: path.category));
      expect(icon.color, Colors.white);
    }
    // No generic book tile for every row.
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
  });

  testWidgets('meta, Current and Completed tags', (tester) async {
    await _open(tester, size: const Size(320, 2400));
    expect(find.text('8 Topics · 400 XP · 14 days'), findsNWidgets(4));
    // Zero XP / days are left out.
    expect(find.text('8 Topics'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('path_picker_row_nbe')),
            matching: find.text('Current')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('path_picker_row_rooted')),
            matching: find.text('Completed')),
        findsOneWidget);
  });

  testWidgets('tapping a path closes the sheet and returns that path',
      (tester) async {
    await _open(tester);
    await tester.tap(find.text('Rooted in Christ'));
    await tester.pumpAndSettle();
    expect(find.byType(FellowshipPathPickerSheet), findsNothing);
    expect(_selected, [_rooted]);
  });

  testWidgets('level chips filter the list client-side', (tester) async {
    await _open(tester, size: const Size(320, 2400));
    await tester.tap(find.byKey(const Key('path_picker_level_follower')));
    await tester.pumpAndSettle();
    expect(find.text('Who Is the Holy Spirit?'), findsOneWidget);
    expect(find.text('New Believer Essentials'), findsNothing);
    expect(find.text('Leading Others'), findsNothing);
    expect(find.text('FOLLOWER'), findsOneWidget);
    expect(find.text('1 path'), findsOneWidget);

    // Tapping the selected chip again (or All) shows every level.
    await tester.tap(find.byKey(const Key('path_picker_level_all')));
    await tester.pumpAndSettle();
    expect(find.text('New Believer Essentials'), findsOneWidget);
    expect(find.text('Leading Others'), findsOneWidget);
    // Filtering is client-side: no reload was requested.
    verifyNever(() => _paths.add(any()));
  });

  testWidgets('a level with no paths says so', (tester) async {
    when(() => _paths.state).thenReturn(_loaded([_nbe]));
    await _open(tester);
    await tester
        .ensureVisible(find.byKey(const Key('path_picker_level_leader')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('path_picker_level_leader')));
    await tester.pumpAndSettle();
    expect(find.text('No paths match the selected filters'), findsOneWidget);
  });

  testWidgets('search is debounced; clearing reloads with the fellowship',
      (tester) async {
    await _open(tester);
    await tester.enterText(
        find.byKey(const Key('path_picker_search')), 'grace');
    await tester.pump(const Duration(milliseconds: 200));
    verifyNever(() => _paths.add(any()));
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => _paths.add(const SearchLearningPaths(query: 'grace')))
        .called(1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 500));
    verify(() => _paths.add(const LoadFlatLearningPaths(fellowshipId: 'f1')))
        .called(1);
  });

  testWidgets('no search results', (tester) async {
    when(() => _paths.state).thenReturn(const LearningPathsLoaded(
      categories: [],
      searchQuery: 'zzz',
      searchResults: [],
    ));
    await _open(tester);
    _expectClean(tester);
    expect(find.text('No paths match your search'), findsOneWidget);
  });

  testWidgets('a failed search does not claim nothing matched', (tester) async {
    when(() => _paths.state).thenReturn(const LearningPathsLoaded(
      categories: [],
      searchQuery: 'zzz',
      searchResults: [],
      searchFailed: true,
    ));
    await _open(tester);
    expect(find.text('No paths match your search'), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  group('states', () {
    // The spinner never settles, so it is pumped in place, not opened.
    testWidgets('loading shows a spinner', (tester) async {
      when(() => _paths.state).thenReturn(const LearningPathsLoading());
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<LearningPathsBloc>.value(
            value: _paths,
            child: FellowshipPathPickerSheet(
              fellowshipId: 'f1',
              onPathSelected: _selected.add,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final v in _variants) {
      testWidgets('error with retry ${v.$1.code} ${v.$2 ? 'dark' : 'light'}',
          (tester) async {
        when(() => _paths.state)
            .thenReturn(const LearningPathsError(message: 'Network error'));
        await _open(tester, language: v.$1, dark: v.$2);
        _expectClean(tester);
        expect(find.text('Network error'), findsOneWidget);
        await tester.tap(find.byType(OutlinedButton));
        verify(() =>
                _paths.add(const LoadFlatLearningPaths(fellowshipId: 'f1')))
            .called(1);
      });
    }

    testWidgets('empty listing', (tester) async {
      when(() => _paths.state).thenReturn(_loaded(const []));
      await _open(tester);
      _expectClean(tester);
      expect(find.text('No learning paths available.'), findsOneWidget);
    });
  });
}
