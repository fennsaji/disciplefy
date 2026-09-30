// Widget tests for the fellowship lessons page: the path top bar, the
// "Studying together" summary card and the lesson path with its status
// markers. Rendered dark and light at 320 wide in English, Hindi and
// Malayalam with nothing overflowing or truncated; tapping a lesson opens the
// guide detail and refreshes the same blocs as before.

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
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_guide_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_lessons_tab_screen.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/text_fit.dart' show loadAppFonts;
import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockFeedBloc extends MockBloc<FellowshipFeedEvent, FellowshipFeedState>
    implements FellowshipFeedBloc {}

class _MockMembersBloc
    extends MockBloc<FellowshipMembersEvent, FellowshipMembersState>
    implements FellowshipMembersBloc {}

class _MockStudyBloc
    extends MockBloc<FellowshipStudyEvent, FellowshipStudyState>
    implements FellowshipStudyBloc {}

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _RouteRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

// ── Fixtures ────────────────────────────────────────────────────────────────

LearningPathTopic _topic(int position, String title,
        {bool completed = false,
        bool milestone = false,
        String category = 'Foundations of Faith'}) =>
    LearningPathTopic(
      position: position,
      isMilestone: milestone,
      topicId: 't$position',
      title: title,
      description: '',
      category: category,
      xpValue: 50,
      isCompleted: completed,
    );

LearningPathDetail _path(List<LearningPathTopic> topics) => LearningPathDetail(
      id: 'path1',
      slug: 'nbe',
      title: 'New Believer Essentials',
      description: 'Start here',
      iconName: 'book',
      color: '#4F46E5',
      totalXp: 400,
      estimatedDays: 7,
      discipleLevel: 'seeker',
      topics: topics,
    );

final _topics = [
  _topic(0, 'Who is Jesus Christ?', completed: true),
  _topic(1, 'One God, Three Persons', completed: true),
  _topic(2, 'What is the Gospel?'),
  _topic(3, 'Confidence in Your Salvation', milestone: true),
  _topic(4, 'Why Read the Bible?'),
  _topic(5, 'Importance of Prayer'),
  _topic(6, 'The Role of the Holy Spirit', milestone: true),
  _topic(7, 'Baptism and Communion'),
];

const _studyState = FellowshipStudyState(
  fellowshipId: 'f1',
  currentLearningPathId: 'path1',
  currentPathTitle: 'New Believer Essentials',
  currentGuideIndex: 2,
  totalGuides: 8,
);

// ── Harness ─────────────────────────────────────────────────────────────────

late FakeTranslationService _translations;
late _MockFeedBloc _feed;
late _MockMembersBloc _members;
late _MockStudyBloc _study;
late _MockPathsBloc _paths;

Future<void> _pump(
  WidgetTester tester, {
  bool dark = true,
  AppLanguage language = AppLanguage.english,
  Size size = const Size(320, 2000),
  NavigatorObserver? observer,
}) async {
  _translations.language = language;
  useSurface(tester, size);
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider<FellowshipFeedBloc>.value(value: _feed),
      BlocProvider<FellowshipMembersBloc>.value(value: _members),
      BlocProvider<FellowshipStudyBloc>.value(value: _study),
      BlocProvider<LearningPathsBloc>.value(value: _paths),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [if (observer != null) observer],
      // Same composition as the fellowship home's lessons page.
      home: const Scaffold(
        body: Column(children: [
          FellowshipLessonsTopBar(),
          Expanded(
            child: FellowshipLessonsTabScreen(
              fellowshipId: 'f1',
              languageOverride: 'en',
            ),
          ),
        ]),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectClean(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expectNoTruncatedText(tester);
}

Finder _markerWith(IconData icon) => find.descendant(
      of: find.byType(Container),
      matching: find.byIcon(icon),
    );

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
    registerFallbackValue(const FellowshipFeedLoadRequested(fellowshipId: ''));
    registerFallbackValue(
        const FellowshipMembersLoadRequested(fellowshipId: ''));
    registerFallbackValue(const FellowshipStudyRefreshRequested());
    registerFallbackValue(const LoadLearningPathDetails(pathId: ''));
  });

  setUp(() {
    _translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(_translations);
    _feed = _MockFeedBloc();
    _members = _MockMembersBloc();
    _study = _MockStudyBloc();
    _paths = _MockPathsBloc();
    when(() => _feed.state).thenReturn(const FellowshipFeedState(
      topicPostCounts: {'t2': 4},
    ));
    when(() => _members.state).thenReturn(const FellowshipMembersState());
    when(() => _study.state).thenReturn(_studyState);
    when(() => _paths.state)
        .thenReturn(LearningPathDetailLoaded(pathDetail: _path(_topics)));
  });

  tearDown(() async => sl.reset());

  group('fits 320 wide', () {
    for (final v in _variants) {
      testWidgets('${v.$1.code} ${v.$2 ? 'dark' : 'light'}', (tester) async {
        await _pump(tester, language: v.$1, dark: v.$2);
        _expectClean(tester);
        expect(find.text('New Believer Essentials'), findsOneWidget);
        expect(find.text('Baptism and Communion'), findsOneWidget);
      });
    }

    testWidgets('mentor view fits too', (tester) async {
      when(() => _study.state).thenReturn(_studyState.copyWith(isMentor: true));
      await _pump(tester, language: AppLanguage.malayalam);
      _expectClean(tester);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });
  });

  testWidgets('top bar shows the path title with category and level',
      (tester) async {
    await _pump(tester);
    expect(find.text('New Believer Essentials'), findsOneWidget);
    expect(find.text('Foundations of Faith · Seeker'), findsOneWidget);
    // The category is not repeated on every lesson.
    expect(find.text('Foundations of Faith'), findsNothing);
    // No generic "Lessons" / "All lessons" headings.
    expect(find.text('Lessons'), findsNothing);
    expect(find.text('All lessons'), findsNothing);
  });

  testWidgets('summary card shows the current lesson and group progress',
      (tester) async {
    await _pump(tester);
    expect(find.text('STUDYING TOGETHER'), findsOneWidget);
    expect(find.text('Lesson 3 of 8'), findsOneWidget);
    // Current lesson title: in the card and on its row.
    expect(find.text('What is the Gospel?'), findsNWidgets(2));
    expect(find.text('Group progress · 2 of 8 done'), findsOneWidget);
    expect(find.text('+100 XP earned'), findsOneWidget);
  });

  testWidgets('status markers: done, now, locked', (tester) async {
    await _pump(tester);
    // Two completed lessons: green check marker + "Completed" meta.
    expect(_markerWith(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('Completed'), findsNWidgets(2));
    // The current lesson: "Now" tag and its number in the marker.
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Lessons past the current one are locked on a sequential path.
    expect(_markerWith(Icons.lock_rounded), findsNWidgets(5));
    // Milestones use the tag with a flag.
    expect(find.text('Milestone'), findsNWidgets(2));
    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2));
    // Discussion count stays on the row.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('several categories are grouped under section labels',
      (tester) async {
    when(() => _paths.state).thenReturn(LearningPathDetailLoaded(
      pathDetail: _path([
        _topic(0, 'Who is Jesus Christ?', completed: true),
        _topic(1, 'What is the Gospel?'),
        _topic(2, 'Why Read the Bible?', category: 'Spiritual Disciplines'),
      ]),
    ));
    await _pump(tester);
    _expectClean(tester);
    expect(find.text('FOUNDATIONS OF FAITH'), findsOneWidget);
    expect(find.text('SPIRITUAL DISCIPLINES'), findsOneWidget);
    expect(find.text('New Believer Essentials'), findsOneWidget);
  });

  testWidgets('tapping a lesson opens its guide and refreshes on return',
      (tester) async {
    final recorder = _RouteRecorder();
    await _pump(tester, observer: recorder);
    final initialRoutes = recorder.pushed.length;

    await tester.tap(find.text('One God, Three Persons'));
    expect(recorder.pushed.length, initialRoutes + 1);
    final route = recorder.pushed.last as MaterialPageRoute<void>;
    final page = route.builder(tester.element(find.byType(Scaffold).first));
    expect(page, isA<FellowshipGuideDetailScreen>());
    final detail = page as FellowshipGuideDetailScreen;
    expect(detail.topic.topicId, 't1');
    expect(detail.fellowshipId, 'f1');
    expect(detail.pathTitle, 'New Believer Essentials');
    expect(detail.contentLanguage, 'en');

    // Leave the guide without building it (it needs Supabase).
    tester.state<NavigatorState>(find.byType(Navigator)).removeRoute(route);
    await tester.pump();

    verify(() => _paths.add(const LoadLearningPathDetails(
          pathId: 'path1',
          forceRefresh: true,
        ))).called(1);
    verify(() => _study.add(const FellowshipStudyRefreshRequested())).called(1);
    verify(() => _members.add(
        const FellowshipMembersLoadRequested(fellowshipId: 'f1'))).called(1);
    verify(() =>
            _feed.add(const FellowshipFeedLoadRequested(fellowshipId: 'f1')))
        .called(1);
  });

  testWidgets('the summary card opens the current lesson', (tester) async {
    final recorder = _RouteRecorder();
    await _pump(tester, observer: recorder);
    final initialRoutes = recorder.pushed.length;
    await tester.tap(find.text('Lesson 3 of 8'));
    expect(recorder.pushed.length, initialRoutes + 1);
    final route = recorder.pushed.last as MaterialPageRoute<void>;
    final page = route.builder(tester.element(find.byType(Scaffold).first))
        as FellowshipGuideDetailScreen;
    expect(page.topic.topicId, 't2');
    tester.state<NavigatorState>(find.byType(Navigator)).removeRoute(route);
    await tester.pump();
  });

  testWidgets('locked lessons do not open', (tester) async {
    final recorder = _RouteRecorder();
    await _pump(tester, observer: recorder);
    final initialRoutes = recorder.pushed.length;
    await tester.tap(find.text('Baptism and Communion'));
    await tester.pump();
    expect(recorder.pushed.length, initialRoutes);
  });

  testWidgets('a load error offers a retry that reloads the path',
      (tester) async {
    when(() => _paths.state)
        .thenReturn(const LearningPathsError(message: 'boom'));
    await _pump(tester);
    _expectClean(tester);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    verify(() => _paths.add(const LoadLearningPathDetails(
          pathId: 'path1',
          forceRefresh: true,
        ))).called(1);
  });

  group('mentor view', () {
    FellowshipMemberEntity member(String id, String name, int done,
            {String role = 'member'}) =>
        FellowshipMemberEntity(
          userId: id,
          displayName: name,
          role: role,
          joinedAt: '2026-01-01T00:00:00Z',
          isMuted: false,
          topicsCompleted: done,
        );

    setUp(() {
      when(() => _study.state).thenReturn(_studyState.copyWith(isMentor: true));
      when(() => _members.state).thenReturn(FellowshipMembersState(
        status: FellowshipMembersStatus.success,
        isMentor: true,
        fellowshipId: 'f1',
        currentUserId: 'u1',
        members: [
          member('u1', 'Fenn Ignatius Saji', 2, role: 'mentor'),
          member('u2', 'Priya Thomas', 2),
          member('u3', 'Joel Mathew', 1),
          member('u4', 'Fenn', 0),
        ],
      ));
    });

    for (final size in const [Size(320, 640), Size(320, 2400)]) {
      for (final v in _variants) {
        testWidgets(
            '${size.height.toInt()} ${v.$1.code} '
            '${v.$2 ? 'dark' : 'light'} fits', (tester) async {
          await _pump(tester, language: v.$1, dark: v.$2, size: size);
          _expectClean(tester);
        });
      }
    }

    testWidgets('advance pill with hint, change path, member progress',
        (tester) async {
      await _pump(tester, size: const Size(320, 2400));
      expect(find.text('Advance to next lesson'), findsOneWidget);
      expect(find.text('Moves everyone to lesson 4'), findsOneWidget);
      expect(find.text('Change learning path'), findsOneWidget);
      expect(find.byIcon(Icons.route_rounded), findsOneWidget);
      expect(find.text('MEMBER PROGRESS'), findsOneWidget);
      // Caught up = completed at least the group's current lesson index (2).
      expect(find.text('2 of 4 caught up'), findsOneWidget);
      expect(find.text('Fenn Ignatius Saji (you)'), findsOneWidget);
      expect(find.text('Mentor'), findsOneWidget);
      expect(find.text('2 / 8'), findsNWidgets(2));
      expect(find.text('1 / 8'), findsOneWidget);
      expect(find.text('0 / 8'), findsOneWidget);
      // Duplicated pieces are gone.
      expect(find.text('Fellowship Progress'), findsNothing);
      expect(find.textContaining('Current lesson'), findsNothing);
      // Mentors still see and can open the whole lesson path.
      expect(find.text('Who is Jesus Christ?'), findsOneWidget);
      expect(find.text('Baptism and Communion'), findsOneWidget);
    });

    testWidgets('change path sits above member progress', (tester) async {
      await _pump(tester, size: const Size(320, 2400));
      final changeY = tester.getTopLeft(find.text('Change learning path')).dy;
      final progressY = tester.getTopLeft(find.text('MEMBER PROGRESS')).dy;
      final lessonY = tester.getTopLeft(find.text('Who is Jesus Christ?')).dy;
      expect(changeY, lessThan(progressY));
      expect(progressY, lessThan(lessonY));
    });

    testWidgets('advance asks to confirm, then dispatches the same event',
        (tester) async {
      await _pump(tester, size: const Size(320, 2400));
      await tester.tap(find.text('Advance to next lesson'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advance to next lesson').last);
      await tester.pumpAndSettle();
      verify(() => _study.add(const FellowshipStudyAdvanceRequested()))
          .called(1);
    });

    testWidgets('while advancing the pill shows a spinner', (tester) async {
      when(() => _study.state).thenReturn(_studyState.copyWith(
        isMentor: true,
        advanceStatus: FellowshipStudyAdvanceStatus.loading,
      ));
      await _pump(tester, size: const Size(320, 2400));
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('last lesson shows Finish Path without the hint',
        (tester) async {
      when(() => _study.state).thenReturn(
          _studyState.copyWith(isMentor: true, currentGuideIndex: 7));
      await _pump(tester, size: const Size(320, 2400));
      expect(find.text('Finish Path'), findsOneWidget);
      expect(find.textContaining('Moves everyone'), findsNothing);
    });
  });

  testWidgets('member view has no mentor controls', (tester) async {
    when(() => _members.state).thenReturn(const FellowshipMembersState(
      status: FellowshipMembersStatus.success,
      fellowshipId: 'f1',
      currentUserId: 'u2',
    ));
    await _pump(tester);
    _expectClean(tester);
    expect(find.text('Advance to next lesson'), findsNothing);
    expect(find.textContaining('Moves everyone'), findsNothing);
    expect(find.text('MEMBER PROGRESS'), findsNothing);
    expect(find.text('Change learning path'), findsNothing);
    expect(find.text('Baptism and Communion'), findsOneWidget);
  });
}
