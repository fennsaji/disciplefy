import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/topic_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/learning_path_category_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/study_topics_screen.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_paths_section.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_header_cards.dart';

import '../../../../helpers/welcome_test_harness.dart';
import '../../../../helpers/text_fit.dart';

class _MockLearningPathsBloc
    extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

/// Every `learning_paths.icon_name` in the database.
const _dbIconNames = [
  'account_balance', 'air', 'anchor', 'auto_awesome', 'auto_stories', //
  'brightness_5', 'church', 'family_restroom', 'favorite', 'front_hand',
  'gavel', 'gpp_bad', 'group', 'groups', 'healing', 'help_outline',
  'history_edu', 'import_contacts', 'language', 'lightbulb', 'lock_open',
  'menu_book', 'military_tech', 'park', 'psychology', 'public',
  'record_voice_over', 'restart_alt', 'self_improvement',
  'sentiment_very_satisfied', 'shield', 'terrain', 'trending_up', 'verified',
  'visibility', 'volunteer_activism', 'water_drop', 'wb_sunny', 'work',
  'workspace_premium',
];

LearningPath _path(
  String id, {
  String title = 'Rooted in Christ',
  String level = 'seeker',
  String category = 'Foundations',
  bool enrolled = false,
  int progress = 0,
  bool featured = false,
  int topics = 5,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: title,
      description: 'A path description',
      iconName: 'park',
      color: '#4F46E5',
      totalXp: 250,
      estimatedDays: 21,
      discipleLevel: level,
      isFeatured: featured,
      topicsCount: topics,
      isEnrolled: enrolled,
      progressPercentage: progress,
      category: category,
    );

final _paths = [
  _path('a', featured: true),
  _path('b',
      title: 'The Crucifixion and Resurrection of Jesus',
      level: 'follower',
      enrolled: true,
      progress: 38,
      topics: 16),
  _path('c', title: 'Sermon on the Mount', level: 'disciple'),
  _path('d', title: 'Heart for the World', level: 'leader'),
];

LearningPathsLoaded _loaded({bool hasMoreInCategory = false}) =>
    LearningPathsLoaded(
      categories: [
        LearningPathCategory(
          name: 'Foundations',
          paths: _paths,
          totalInCategory: hasMoreInCategory ? 9 : _paths.length,
          hasMoreInCategory: hasMoreInCategory,
          nextPathOffset: _paths.length,
        ),
      ],
      enrolledPaths: [_paths[1]],
    );

/// Path and topic titles are content: at the test font's wide glyphs a long
/// one may reach its line cap. Everything else must fit.
final _titles = {for (final p in _paths) p.title};

void main() {
  group('iconForPath', () {
    test('maps every icon name used in the database', () {
      for (final name in _dbIconNames.where((n) => n != 'auto_stories')) {
        expect(iconForPath(name), isNot(defaultPathIcon),
            reason: '$name is unmapped');
      }
      expect(iconForPath('auto_stories'), Icons.auto_stories_rounded);
    });

    test('falls back to the category icon, then the default', () {
      expect(iconForPath('no_such_icon', category: 'mission & service'),
          Icons.volunteer_activism_rounded);
      expect(iconForPath(null, category: 'Unknown'), defaultPathIcon);
      expect(iconForPath(''), defaultPathIcon);
    });
  });

  test('PathLevelStyle picks the gradient by level, seeker by default', () {
    expect(PathLevelStyle.gradientFor('follower').colors,
        const [Color(0xFF0F766E), Color(0xFF059669)]);
    expect(PathLevelStyle.gradientFor('Leader').colors,
        const [Color(0xFFB45309), Color(0xFFEA580C)]);
    expect(PathLevelStyle.gradientFor(null).colors,
        PathLevelStyle.gradientFor('seeker').colors);
  });

  group('TopicsContinueData.resolve', () {
    test('uses the in-progress topic for position and next title', () {
      final data = TopicsContinueData.resolve(
        inProgressTopics: [
          InProgressTopic(
            topicId: 't',
            title: 'Confidence in Your Salvation',
            description: '',
            category: '',
            startedAt: DateTime(2026),
            xpValue: 10,
            learningPathId: 'b',
            learningPathName: 'Ignored',
            positionInPath: 4,
            totalTopicsInPath: 8,
            topicsCompletedInPath: 3,
          ),
        ],
        paths: _paths,
      )!;
      expect(data.pathId, 'b');
      expect(data.title, _paths[1].title);
      expect(data.currentTopic, 4);
      expect(data.totalTopics, 8);
      expect(data.nextTopicTitle, 'Confidence in Your Salvation');
      expect(data.progressPercentage, 38);
    });

    test('falls back to the furthest in-progress path', () {
      final data = TopicsContinueData.resolve(
          inProgressTopics: const [], paths: _paths)!;
      expect(data.pathId, 'b');
      expect(data.nextTopicTitle, isNull);
      expect(data.currentTopic, _paths[1].topicsCompleted + 1);
    });

    test('is null when nothing is in progress', () {
      expect(
        TopicsContinueData.resolve(
            inProgressTopics: const [], paths: [_paths.first]),
        isNull,
      );
    });
  });

  group('widgets', () {
    late FakeTranslationService translations;
    late _MockLearningPathsBloc bloc;
    late _MockConnectivityBloc connectivity;

    setUp(() {
      translations = FakeTranslationService();
      sl.registerSingleton<TranslationService>(translations);
      bloc = _MockLearningPathsBloc();
      connectivity = _MockConnectivityBloc();
      when(() => connectivity.state).thenReturn(ConnectivityOnline());
    });
    tearDown(() async {
      await bloc.close();
      await connectivity.close();
      await sl.reset();
    });

    Widget app(Widget home, {required bool dark, required AppLanguage lang}) =>
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(lang.code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<LearningPathsBloc>.value(value: bloc),
              BlocProvider<ConnectivityBloc>.value(value: connectivity),
            ],
            child: home,
          ),
        );

    for (final lang in AppLanguage.values) {
      for (final dark in [true, false]) {
        final name = '${lang.code} ${dark ? 'dark' : 'light'}';

        testWidgets('header cards and path tiles fit 320 wide ($name)',
            (tester) async {
          translations.language = lang;
          useSurface(tester, const Size(320, 640));
          await tester.pumpWidget(app(
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TopicsContinueCard(
                      data: const TopicsContinueData(
                        pathId: 'b',
                        title: 'New Believer Essentials',
                        currentTopic: 4,
                        totalTopics: 8,
                        progressPercentage: 38,
                        nextTopicTitle: 'Confidence in Your Salvation',
                      ),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TopicsStatTile(
                              icon: Icons.local_fire_department_outlined,
                              value: '4 days',
                              label: 'Study streak',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TopicsStatTile(
                              icon: Icons.emoji_events_outlined,
                              value: '#5',
                              label: 'Leaderboard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in _paths) ...[
                    Center(child: LearningPathCard(path: p, onTap: () {})),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            dark: dark,
            lang: lang,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(truncatedTexts(tester, allow: {..._titles, 'Confidence'}),
              isEmpty);
        });

        testWidgets('learning paths section renders ($name)', (tester) async {
          translations.language = lang;
          useSurface(tester, const Size(320, 640));
          whenListen(bloc, const Stream<LearningPathsState>.empty(),
              initialState: _loaded());
          await tester.pumpWidget(app(
            Scaffold(
              body: SingleChildScrollView(
                child: LearningPathsSection(
                  onPathTap: (_) {},
                  onCategorySeeAll: (_) {},
                ),
              ),
            ),
            dark: dark,
            lang: lang,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(truncatedTexts(tester, allow: {..._titles, 'Confidence'}),
              isEmpty);
          expect(find.byKey(const Key('learning_paths_chip_leader')),
              findsOneWidget);
        });

        testWidgets('category page renders ($name)', (tester) async {
          translations.language = lang;
          useSurface(tester, const Size(320, 640));
          whenListen(bloc, const Stream<LearningPathsState>.empty(),
              initialState: _loaded());
          await tester.pumpWidget(app(
            const LearningPathCategoryPage(
                category: 'Foundations', language: 'en'),
            dark: dark,
            lang: lang,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(truncatedTexts(tester, allow: {..._titles, 'Confidence'}),
              isEmpty);
          expect(find.byKey(const Key('path_category_row_a')), findsOneWidget);
        });
      }
    }

    testWidgets('header: title and overflow menu, no trophy', (tester) async {
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(app(
        const Scaffold(body: StudyTopicsAppBar()),
        dark: true,
        lang: AppLanguage.english,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Topics'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    });

    testWidgets('section: rows, See all, row tap, Leader and All filters',
        (tester) async {
      useSurface(tester, const Size(390, 900));
      whenListen(bloc, const Stream<LearningPathsState>.empty(),
          initialState: _loaded());
      String? seeAll;
      LearningPath? tapped;
      await tester.pumpWidget(app(
        Scaffold(
          body: SingleChildScrollView(
            child: LearningPathsSection(
              onPathTap: (p) => tapped = p,
              onCategorySeeAll: (c) => seeAll = c,
            ),
          ),
        ),
        dark: true,
        lang: AppLanguage.english,
      ));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('learning_paths_see_all_Foundations')));
      expect(seeAll, 'Foundations');

      await tester.tap(find.text('Rooted in Christ'));
      expect(tapped?.id, 'a');

      await tester
          .ensureVisible(find.byKey(const Key('learning_paths_chip_leader')));
      await tester.tap(find.byKey(const Key('learning_paths_chip_leader')));
      await tester.pumpAndSettle();
      expect(find.text('Heart for the World'), findsOneWidget);
      expect(find.text('Rooted in Christ'), findsNothing);

      // "All" clears the level and featured filters.
      await tester
          .ensureVisible(find.byKey(const Key('learning_paths_chip_all')));
      await tester.tap(find.byKey(const Key('learning_paths_chip_all')));
      await tester.pumpAndSettle();
      expect(find.byType(PathListRow), findsNWidgets(_paths.length));
    });

    testWidgets('category page: row opens detail, scrolling loads more',
        (tester) async {
      useSurface(tester, const Size(390, 700));
      whenListen(bloc, const Stream<LearningPathsState>.empty(),
          initialState: _loaded(hasMoreInCategory: true));
      final router = GoRouter(
        initialLocation: '/c',
        routes: [
          GoRoute(
            path: '/c',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<LearningPathsBloc>.value(value: bloc),
              ],
              child: const LearningPathCategoryPage(
                  category: 'Foundations', language: 'en'),
            ),
          ),
          GoRoute(
            path: '/learning-path/:id',
            builder: (_, s) =>
                Scaffold(body: Text('detail ${s.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.darkTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ));
      await tester.pumpAndSettle();

      // The list is short and the category has more: it asks for the rest.
      verify(() =>
              bloc.add(const LoadMorePathsForCategory(category: 'Foundations')))
          .called(greaterThan(0));
      expect(find.text('9 paths · Seeker to Leader'), findsOneWidget);

      await tester.tap(find.byKey(const Key('path_category_row_c')));
      await tester.pumpAndSettle();
      expect(find.text('detail c'), findsOneWidget);
    });
  });
}
