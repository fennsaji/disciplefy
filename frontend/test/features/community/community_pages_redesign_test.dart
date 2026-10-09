import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/blocked_user_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/daily_post_status_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/discipler_activity_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_meeting_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/blocked_users_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/create_fellowship_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/discipler_activity_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_daily_post_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_invites_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_meetings_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_settings_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/join_fellowship_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/schedule_meeting_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/share_guide_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_edit_dialog.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockMeetingsBloc
    extends MockBloc<FellowshipMeetingsEvent, FellowshipMeetingsState>
    implements FellowshipMeetingsBloc {}

class _MockSettingsBloc
    extends MockBloc<FellowshipSettingsEvent, FellowshipSettingsState>
    implements FellowshipSettingsBloc {}

class _MockDailyPostBloc
    extends MockBloc<FellowshipDailyPostEvent, FellowshipDailyPostState>
    implements FellowshipDailyPostBloc {}

class _MockMembersBloc
    extends MockBloc<FellowshipMembersEvent, FellowshipMembersState>
    implements FellowshipMembersBloc {}

class _MockListBloc extends MockBloc<FellowshipListEvent, FellowshipListState>
    implements FellowshipListBloc {}

class _MockActivityBloc
    extends MockBloc<DisciplerActivityEvent, DisciplerActivityState>
    implements DisciplerActivityBloc {}

class _MockBlockedBloc extends MockBloc<BlockedUsersEvent, BlockedUsersState>
    implements BlockedUsersBloc {}

const _languages = [
  AppLanguage.english,
  AppLanguage.hindi,
  AppLanguage.malayalam,
];

String _iso(DateTime d) => d.toIso8601String();

FellowshipMeetingEntity _meeting(
  String id,
  DateTime start, {
  String title = 'Sunday Bible Study',
  String? location,
  String meetLink = 'https://meet.google.com/abc-defg-hij',
  String? recurrence,
  String? description,
}) =>
    FellowshipMeetingEntity(
      id: id,
      fellowshipId: 'f1',
      createdBy: 'u1',
      title: title,
      description: description,
      startsAt: _iso(start),
      endsAt: _iso(start.add(const Duration(hours: 1))),
      recurrence: recurrence,
      location: location,
      meetLink: meetLink,
      createdAt: _iso(start),
    );

FellowshipEntity _fellowship({String role = 'admin'}) => FellowshipEntity(
      id: 'f1',
      name: 'Disciplefy',
      description: 'The official Disciplefy fellowship.',
      memberCount: 3,
      userRole: role,
      joinedAt: '2026-01-01T00:00:00Z',
      createdAt: '2026-01-01T00:00:00Z',
      disciplerAllowed: true,
      dailyPostAllowed: true,
      isOfficial: true,
    );

DailyPostStatusEntity _dailyData({bool dailyPostOn = true}) =>
    DailyPostStatusEntity(
      settings: DailyPostSettingsEntity(
        dailyPostOn: dailyPostOn,
        frequencyDays: 1,
        autoAdvance: true,
        time: '06:00',
        times: const ['06:00', '07:00', '19:00'],
        previewAllowed: true,
        regenerateAllowed: true,
        postNowAllowed: true,
      ),
      today: '2026-09-30',
      nextPostDate: '2026-10-01',
      nextPostTime: '06:00',
      pathTitle: 'Gospel of Matthew',
      pathTotalLessons: 28,
      lastPost: const DailyPostHistoryItemEntity(
        dailyPostId: 'd3',
        postDate: '2026-09-29',
        topicTitle: 'Matthew 3: Repentance and the Baptism of Jesus',
      ),
      upcoming: const [
        DailyPostLessonEntity(
            learningPathTopicId: 't4',
            position: 3,
            title: 'Matthew 4: The Temptation of Jesus'),
        DailyPostLessonEntity(
            learningPathTopicId: 't5',
            position: 4,
            title: 'Matthew 5: The Sermon on the Mount'),
      ],
      preview: const DailyPostPreviewEntity(
        postDate: '2026-10-01',
        topicTitle: 'Matthew 4: The Temptation of Jesus',
        content: 'Tested in the wilderness, Jesus answers with Scripture.',
        regenerationsLeft: 2,
      ),
      history: const [
        DailyPostHistoryItemEntity(
          dailyPostId: 'd3',
          postDate: '2026-09-29',
          topicTitle: 'Matthew 3: Repentance and the Baptism of Jesus',
          completedCount: 3,
        ),
        DailyPostHistoryItemEntity(
          dailyPostId: 'd2',
          postDate: '2026-09-28',
          topicTitle: 'Matthew 2: The Wise Men and the Flight to Egypt',
          completedCount: 2,
          postDeleted: true,
        ),
      ],
      repostsLeftToday: 1,
    );

User _user() => User(
      id: 'u-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
    );

/// Scrolls the page's main scrollable (not a text field's) until [finder]
/// is built and visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  late FakeTranslationService translations;

  setUpAll(() {
    registerFallbackValue(const FellowshipInvitesListRequested());
    registerFallbackValue(const FellowshipJoinRequested(inviteToken: 'x'));
    registerFallbackValue(const FellowshipMeetingsLoadRequested('x'));
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  /// Mounts [screen] at /page inside a router with stub destinations.
  Widget app(
    Widget screen, {
    required bool dark,
    AppLanguage language = AppLanguage.english,
  }) {
    translations.language = language;
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => screen),
        GoRoute(
          path: '/community/:id/post/:postId',
          builder: (_, s) => Text('stub:post:${s.pathParameters['postId']}'),
        ),
        GoRoute(
          path: '/community/:id/daily-post',
          builder: (_, __) => const Text('stub:daily-post'),
        ),
        GoRoute(
          path: '/community/:id',
          builder: (_, s) => Text('stub:fellowship:${s.pathParameters['id']}'),
        ),
        GoRoute(path: '/community', builder: (_, __) => const Text('stub:c')),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  // -------------------------------------------------------------------------
  // Meetings
  // -------------------------------------------------------------------------

  group('Meetings', () {
    test('groups meetings into this week, next week and later', () {
      // Wednesday; the week starts on Sunday 27 Sep.
      final now = DateTime(2026, 9, 30, 9);
      final groups = groupMeetingsByWeek([
        _meeting('a', DateTime(2026, 9, 30, 19)),
        _meeting('b', DateTime(2026, 10, 3, 19)),
        _meeting('c', DateTime(2026, 10, 4, 19)),
        _meeting('d', DateTime(2026, 10, 10, 19)),
        _meeting('e', DateTime(2026, 10, 11, 19)),
      ], now);
      expect(groups.map((g) => g.meetings.map((m) => m.id).toList()), [
        ['a', 'b'],
        ['c', 'd'],
        ['e'],
      ]);
      expect(groups.map((g) => g.labelKey), [
        'community_pages.this_week',
        'community_pages.next_week',
        'community_pages.later',
      ]);
    });

    late _MockMeetingsBloc bloc;

    Widget meetings({required bool dark, AppLanguage? language}) =>
        BlocProvider<FellowshipMeetingsBloc>.value(
          value: bloc,
          child: app(
            const Scaffold(
              body: FellowshipMeetingsTabScreen(
                  fellowshipId: 'f1', isMentor: true),
            ),
            dark: dark,
            language: language ?? AppLanguage.english,
          ),
        );

    setUp(() {
      bloc = _MockMeetingsBloc();
      final soon = DateTime.now().add(const Duration(hours: 2));
      whenListen(
        bloc,
        const Stream<FellowshipMeetingsState>.empty(),
        initialState: FellowshipMeetingsState(
          status: FellowshipMeetingsStatus.success,
          showSyncBanner: true,
          meetings: [
            _meeting('m1', soon, recurrence: 'weekly'),
            _meeting('m2', soon.add(const Duration(days: 1)),
                title: 'Midweek Prayer',
                location: 'St. Thomas Church hall',
                meetLink: ''),
            _meeting('m3', soon.add(const Duration(days: 2)),
                title: 'Planning call', meetLink: ''),
          ],
        ),
      );
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: cards, join pill, sync banner',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(meetings(dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Sunday Bible Study'), findsOneWidget);
        expect(find.text('Midweek Prayer'), findsOneWidget);
        expect(find.textContaining('Google Meet'), findsOneWidget);
        expect(find.textContaining('St. Thomas Church hall'), findsOneWidget);
        // Only the online meeting with a link can be joined.
        expect(find.text('Join'), findsOneWidget);
        expect(find.text('No link yet'), findsOneWidget);
        expect(find.text('Weekly'), findsOneWidget);
        expect(find.text('Sync to Calendar'), findsOneWidget);
        // Mentors get a cancel action on every meeting.
        expect(find.byTooltip('Cancel meeting'), findsNWidgets(3));
        expectNoTruncatedText(tester);
      });
    }

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: no overflow or truncation',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(meetings(dark: true, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('load failure retries with the same event', (tester) async {
      whenListen(
        bloc,
        const Stream<FellowshipMeetingsState>.empty(),
        initialState: const FellowshipMeetingsState(
            status: FellowshipMeetingsStatus.failure),
      );
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(meetings(dark: true));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load meetings"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      verify(() => bloc.add(const FellowshipMeetingsLoadRequested('f1')))
          .called(1);
    });

    testWidgets('empty state keeps the mentor prompt', (tester) async {
      whenListen(
        bloc,
        const Stream<FellowshipMeetingsState>.empty(),
        initialState: const FellowshipMeetingsState(
            status: FellowshipMeetingsStatus.success),
      );
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(meetings(dark: false));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming meetings'), findsOneWidget);
      expect(find.text('Tap + to schedule a meeting'), findsOneWidget);
    });
  });

  group('Schedule meeting sheet', () {
    late _MockMeetingsBloc bloc;

    setUp(() {
      bloc = _MockMeetingsBloc();
      whenListen(bloc, const Stream<FellowshipMeetingsState>.empty(),
          initialState: const FellowshipMeetingsState());
    });

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: fields and pills fit',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(BlocProvider<FellowshipMeetingsBloc>.value(
          value: bloc,
          child: app(
            const Scaffold(body: ScheduleMeetingSheet(fellowshipId: 'f1')),
            dark: language != AppLanguage.hindi,
            language: language,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('in person shows location; empty title blocks submit',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(BlocProvider<FellowshipMeetingsBloc>.value(
        value: bloc,
        child: app(
          const Scaffold(body: ScheduleMeetingSheet(fellowshipId: 'f1')),
          dark: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsNothing);
      await tester.tap(find.text('In person'));
      await tester.pumpAndSettle();
      expect(find.text('Location'), findsOneWidget);

      await tester.ensureVisible(find.text('Schedule & send invites'));
      await tester.tap(find.text('Schedule & send invites'));
      await tester.pumpAndSettle();
      expect(find.text('Title is required'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });
  });

  // -------------------------------------------------------------------------
  // Fellowship settings
  // -------------------------------------------------------------------------

  group('Fellowship settings', () {
    late _MockSettingsBloc bloc;

    Widget settings({required bool dark, AppLanguage? language}) =>
        BlocProvider<FellowshipSettingsBloc>.value(
          value: bloc,
          child: app(
            FellowshipSettingsScreen(
                fellowshipId: 'f1', fellowship: _fellowship()),
            dark: dark,
            language: language ?? AppLanguage.english,
          ),
        );

    setUp(() {
      bloc = _MockSettingsBloc();
      final f = _fellowship();
      whenListen(bloc, const Stream<FellowshipSettingsState>.empty(),
          initialState: FellowshipSettingsState(original: f, draft: f));
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: sections and rows',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(settings(dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('DISCIPLEFY'), findsOneWidget);
        expect(find.text('Fellowship settings'), findsOneWidget);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('Everyone'), findsOneWidget);
        expect(find.text('Only mentors'), findsOneWidget);
        await scrollTo(tester, find.text('Which questions'));
        expect(find.text('All questions'), findsOneWidget);
        expect(find.text('Immediately'), findsOneWidget);
        await scrollTo(tester, find.text('Daily post'));
        expect(find.text('React to posts'), findsOneWidget);
        expectNoTruncatedText(tester);
      });
    }

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: no overflow or truncation',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(settings(dark: true, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('controls dispatch the same settings events', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(settings(dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Only mentors'));
      verify(() => bloc.add(const FellowshipSettingsChanged(
          postingPermission: 'mentor_only'))).called(1);

      await scrollTo(tester, find.text('Which questions'));
      await tester.tap(find.text('Which questions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lesson discussions only'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const FellowshipSettingsChanged(
          disciplerReplyScope: 'lessons_only'))).called(1);

      await tester.tap(find.text('Wait for a mentor first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 h'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(
              const FellowshipSettingsChanged(disciplerReplyDelayMin: 120)))
          .called(1);

      await tester.tap(find.text('React to posts'));
      verify(() => bloc.add(
              const FellowshipSettingsChanged(disciplerReactEnabled: false)))
          .called(1);

      await scrollTo(tester, find.text('Daily post'));
      await tester.tap(find.text('Daily post'));
      await tester.pumpAndSettle();
      expect(find.text('stub:daily-post'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Daily post
  // -------------------------------------------------------------------------

  group('Daily post', () {
    late _MockDailyPostBloc bloc;

    Widget daily({required bool dark, AppLanguage? language}) =>
        BlocProvider<FellowshipDailyPostBloc>.value(
          value: bloc,
          child: app(
            const FellowshipDailyPostScreen(fellowshipId: 'f1'),
            dark: dark,
            language: language ?? AppLanguage.english,
          ),
        );

    setUp(() {
      bloc = _MockDailyPostBloc();
      whenListen(bloc, const Stream<FellowshipDailyPostState>.empty(),
          initialState: FellowshipDailyPostState(
            status: FellowshipDailyPostStatus.loaded,
            fellowshipId: 'f1',
            data: _dailyData(),
          ));
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: next post, schedule, history',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(daily(dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('GOSPEL OF MATTHEW · BY DISCIPLER'), findsOneWidget);
        expect(find.text('Daily post'), findsOneWidget);
        expect(find.text('Matthew 4: The Temptation of Jesus'), findsWidgets);
        expect(find.text('Post now'), findsOneWidget);
        await scrollTo(tester, find.text('Post frequency'));
        expect(find.text('Daily'), findsOneWidget);
        await scrollTo(tester, find.text('Posts next'));
        await scrollTo(tester, find.text('New teaser (2 left today)'));
        await scrollTo(tester,
            find.text('Matthew 2: The Wise Men and the Flight to Egypt'));
        expect(find.text('Post again (1 left today)'), findsNWidgets(2));
        expectNoTruncatedText(tester);
      });
    }

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: no overflow or truncation',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(daily(dark: false, language: language));
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      });
    }

    testWidgets('controls dispatch the same events', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(daily(dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Post now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post now').last);
      await tester.pumpAndSettle();
      verify(() =>
              bloc.add(const FellowshipDailyPostActionRequested('post_now')))
          .called(1);

      await scrollTo(tester, find.text('Post a daily study'));
      await tester.tap(find.text('Post a daily study'));
      verify(() => bloc.add(
              const FellowshipDailyPostSettingsChanged(dailyPostOn: false)))
          .called(1);

      await tester.tap(find.text('Post frequency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      verify(() => bloc
              .add(const FellowshipDailyPostSettingsChanged(frequencyDays: 7)))
          .called(1);

      await tester.tap(find.text('Posting time (IST)'));
      await tester.pumpAndSettle();
      // intl may put a narrow no-break space before AM.
      await tester.tap(find.textContaining(RegExp(r'^7:00\s+AM$')));
      await tester.pumpAndSettle();
      verify(() =>
              bloc.add(const FellowshipDailyPostScheduleChanged(time: '07:00')))
          .called(1);

      await scrollTo(tester, find.text('Post this next'));
      await tester.tap(find.text('Post this next'));
      verify(() => bloc.add(const FellowshipDailyPostScheduleChanged(
          nextLearningPathTopicId: 't5'))).called(1);
    });

    testWidgets('schedule rows are disabled while daily posts are off',
        (tester) async {
      whenListen(bloc, const Stream<FellowshipDailyPostState>.empty(),
          initialState: FellowshipDailyPostState(
            status: FellowshipDailyPostStatus.loaded,
            data: _dailyData(dailyPostOn: false),
          ));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(daily(dark: true));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Post frequency'));
      await tester.tap(find.text('Post frequency'));
      await tester.pumpAndSettle();
      expect(find.text('Every 2 days'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Invites, join, create
  // -------------------------------------------------------------------------

  group('Invites', () {
    late _MockMembersBloc bloc;

    Widget invites({required bool dark, AppLanguage? language}) =>
        BlocProvider<FellowshipMembersBloc>.value(
          value: bloc,
          child: app(
            const FellowshipInvitesScreen(
                fellowshipId: 'f1', fellowshipName: 'Disciplefy'),
            dark: dark,
            language: language ?? AppLanguage.english,
          ),
        );

    setUp(() {
      bloc = _MockMembersBloc();
      whenListen(bloc, const Stream<FellowshipMembersState>.empty(),
          initialState: const FellowshipMembersState(
            invitesListStatus: FellowshipInvitesListStatus.success,
            invitesList: [
              {
                'id': 'i1',
                'token': 'abcdef',
                'join_url': 'https://go.disciplefy.in/j/abcdef',
                'use_count': 2,
                'max_uses': null,
              },
            ],
          ));
    });

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: card and actions fit',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(invites(dark: true, language: language));
        await tester.pumpAndSettle();
        expect(find.text('ABCDEF'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester,
            allowed: {'https://go.disciplefy.in/j/abcdef'});
      });
    }

    testWidgets('loads, revokes and generates like before', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(invites(dark: false));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const FellowshipInvitesListRequested())).called(1);

      final l10n = AppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.inviteRevoke));
      verify(() =>
              bloc.add(const FellowshipInviteRevokeRequested(inviteId: 'i1')))
          .called(1);

      await tester.tap(find.text(l10n.inviteGenerateLink));
      verify(() => bloc.add(const FellowshipMembersInviteRequested()))
          .called(1);
    });
  });

  group('Join fellowship', () {
    late _MockListBloc bloc;

    setUp(() {
      bloc = _MockListBloc();
      whenListen(bloc, const Stream<FellowshipListState>.empty(),
          initialState: const FellowshipListState());
      sl.registerFactory<FellowshipListBloc>(() => bloc);
    });

    for (final dark in [true, false]) {
      for (final language in _languages) {
        testWidgets(
            '${dark ? 'dark' : 'light'} 320pt ${language.code}: '
            'tiles and button fit', (tester) async {
          useSurface(tester, const Size(320, 640));
          await tester.pumpWidget(app(const JoinFellowshipScreen(),
              dark: dark, language: language));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
          expect(find.byType(PhotoWash), findsOneWidget);
        });
      }
    }

    testWidgets('disabled pill is raised fill with muted ink', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const JoinFellowshipScreen(), dark: true));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CommunityWideCta));
      final palette = ReaderPalette.of(context);
      final button = tester.widget<FilledButton>(find.descendant(
          of: find.byType(CommunityWideCta),
          matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
      expect(button.style!.backgroundColor!.resolve({WidgetState.disabled}),
          palette.raised);
      expect(button.style!.foregroundColor!.resolve({WidgetState.disabled}),
          palette.muted);
      // No stray placeholder dot in the empty first cell.
      expect(find.text('·'), findsNothing);
    });

    testWidgets('deep-link token is pre-filled and auto-submitted',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(
          app(const JoinFellowshipScreen(initialToken: 'qwerty'), dark: false));
      await tester.pumpAndSettle();
      verify(() =>
              bloc.add(const FellowshipJoinRequested(inviteToken: 'QWERTY')))
          .called(1);
      for (final c in 'QWERTY'.split('')) {
        expect(find.text(c), findsOneWidget);
      }
    });

    testWidgets('failure shows inline error and snackbar; edit clears it',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      whenListen(
        bloc,
        Stream<FellowshipListState>.fromIterable(const [
          FellowshipListState(joinStatus: FellowshipJoinStatus.loading),
          FellowshipListState(
            joinStatus: FellowshipJoinStatus.failure,
            joinError: 'Invite code not found',
          ),
        ]),
        initialState: const FellowshipListState(),
      );
      await tester.pumpWidget(
          app(const JoinFellowshipScreen(initialToken: 'abcdef'), dark: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join_fellowship_error')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcde');
      await tester.pump();
      expect(find.byKey(const Key('join_fellowship_error')), findsNothing);
    });

    testWidgets('typed code joins with the upper-cased token', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const JoinFellowshipScreen(), dark: false));
      await tester.pumpAndSettle();

      // Disabled until a code is typed.
      await tester.tap(find.byType(CommunityWideCta));
      verifyNever(() => bloc.add(any()));

      await tester.enterText(find.byType(TextField), 'abcdef');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CommunityWideCta));
      verify(() =>
              bloc.add(const FellowshipJoinRequested(inviteToken: 'ABCDEF')))
          .called(1);
    });
  });

  group('Create fellowship', () {
    late _MockListBloc bloc;
    late MockAuthBloc auth;

    setUp(() {
      bloc = _MockListBloc();
      whenListen(bloc, const Stream<FellowshipListState>.empty(),
          initialState: const FellowshipListState());
      sl.registerFactory<FellowshipListBloc>(() => bloc);
      auth = MockAuthBloc();
      whenListen(auth, const Stream<AuthState>.empty(),
          initialState: AuthenticatedState(
              user: _user(), profile: const {'is_admin': true}));
    });

    Widget create({required bool dark, AppLanguage? language}) =>
        BlocProvider<AuthBloc>.value(
          value: auth,
          child: app(const CreateFellowshipScreen(),
              dark: dark, language: language ?? AppLanguage.english),
        );

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: admin form fits', (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(create(dark: false, language: language));
        await tester.pumpAndSettle();
        // Placeholder hints (not labels) may clip: the test font draws every
        // glyph a full em wide, so these example hints need 4+ lines here
        // but fit on one line in Inter.
        final l10n = AppLocalizations(Locale(language.code));
        final hints = {
          l10n.createFellowshipNameHint,
          l10n.createFellowshipDescHint,
        };
        for (var i = 0; i < 5; i++) {
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester, allowed: hints);
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      });
    }

    testWidgets('admin options and create dispatch', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(create(dark: true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Morning Word');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('മലയാളം'));
      await tester.tap(find.text('മലയാളം'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byType(CommunityWideCta));
      await tester.tap(find.byType(CommunityWideCta));
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final event = captured.single as FellowshipCreateRequested;
      expect(event.name, 'Morning Word');
      expect(event.language, 'ml');
      expect(event.maxMembers, 12);
      expect(event.postingPermission, 'all_members');
    });
  });

  // -------------------------------------------------------------------------
  // Discipler activity, blocked users, share sheet
  // -------------------------------------------------------------------------

  group('Discipler activity', () {
    late _MockActivityBloc bloc;

    setUp(() {
      bloc = _MockActivityBloc();
      whenListen(bloc, const Stream<DisciplerActivityState>.empty(),
          initialState: const DisciplerActivityState(
            status: DisciplerActivityStatus.success,
            items: [
              DisciplerActivityEntity(
                id: 'a1',
                kind: 'draft',
                postId: 'p1',
                commentId: 'c1',
                commentPending: true,
                summary: 'Drafted a reply to a question about prayer.',
                postContent: 'How should we pray for each other?',
                commentContent: 'Start with thanksgiving.',
                createdAt: '2026-09-29T10:00:00Z',
                language: 'en',
              ),
              DisciplerActivityEntity(
                id: 'a2',
                kind: 'reply',
                postId: 'p2',
                commentId: 'c2',
                summary: 'Answered a question.',
                commentContent: 'Jesus answered with Scripture.',
                createdAt: '2026-09-28T10:00:00Z',
              ),
            ],
          ));
    });

    Widget activity({AppLanguage? language}) =>
        BlocProvider<DisciplerActivityBloc>.value(
          value: bloc,
          child: app(const DisciplerActivityScreen(fellowshipId: 'f1'),
              dark: true, language: language ?? AppLanguage.english),
        );

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: filters and cards fit',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(activity(language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('review, filter and open dispatch as before', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(activity());
      await tester.pumpAndSettle();
      verify(() => bloc.add(
          const DisciplerActivityLoadRequested(fellowshipId: 'f1'))).called(1);

      final l10n = AppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.approve));
      verify(() => bloc.add(
              const DisciplerActivityReviewed(commentId: 'c1', approve: true)))
          .called(1);

      await tester.tap(find.text(l10n.activityTabReplies));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const DisciplerActivityLoadRequested(
          fellowshipId: 'f1', kind: 'reply'))).called(1);

      await tester.tap(find.text('Answered a question.'));
      await tester.pumpAndSettle();
      expect(find.text('stub:post:p2'), findsOneWidget);
    });
  });

  group('Discipler edit dialog', () {
    Future<String?> Function() open(WidgetTester tester) {
      String? result;
      var done = false;
      final context = tester.element(find.text('open'));
      showDisciplerEditDialog(context, initialText: 'Old text', maxLength: 200)
          .then((value) {
        result = value;
        done = true;
      });
      return () async {
        await tester.pumpAndSettle();
        expect(done, isTrue);
        return result;
      };
    }

    for (final dark in [true, false]) {
      for (final language in _languages) {
        testWidgets(
            '${dark ? 'dark' : 'light'} 320pt ${language.code}: popup fits',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          await tester.pumpWidget(
              app(const Text('open'), dark: dark, language: language));
          await tester.pumpAndSettle();
          open(tester);
          await tester.pumpAndSettle();
          expect(find.byType(PopupDialog), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }

    testWidgets('save is disabled until changed, then returns trimmed text',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const Text('open'), dark: false));
      await tester.pumpAndSettle();
      final result = open(tester);
      await tester.pumpAndSettle();
      final save = find.byType(PopupPrimaryButton);
      expect(tester.widget<PopupPrimaryButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  New text  ');
      await tester.pump();
      await tester.tap(save);
      expect(await result(), 'New text');
    });

    testWidgets('cancel returns null', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const Text('open'), dark: true));
      await tester.pumpAndSettle();
      final result = open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupTextButton));
      expect(await result(), isNull);
    });
  });

  group('Blocked users', () {
    late _MockBlockedBloc bloc;

    setUp(() {
      bloc = _MockBlockedBloc();
      whenListen(bloc, const Stream<BlockedUsersState>.empty(),
          initialState: BlockedUsersState(
            status: BlockedUsersStatus.success,
            users: [
              BlockedUserEntity(
                userId: 'u9',
                displayName: 'Thomas Varghese',
                blockedAt: DateTime(2026, 9),
              ),
            ],
          ));
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: unblock dispatches',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(BlocProvider<BlockedUsersBloc>.value(
          value: bloc,
          child: app(const BlockedUsersView(), dark: dark),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Thomas Varghese'), findsOneWidget);
        expectNoTruncatedText(tester);
        await tester.tap(find.text('Unblock'));
        verify(() => bloc.add(const BlockedUserUnblockRequested('u9')))
            .called(1);
        await tester.pump();
        // Confirmation uses the shared floating snackbar.
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.behavior, SnackBarBehavior.floating);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      });
    }
  });

  group('Share guide sheet', () {
    final fellowships = [
      _fellowship(),
      const FellowshipEntity(
        id: 'f2',
        name: 'Morning Word',
        memberCount: 1,
        userRole: 'member',
        joinedAt: '2026-01-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    ];

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: selecting updates the button',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ShareGuideSheet(
                studyGuideId: 'g1',
                guideTitle: 'Matthew 4: The Temptation of Jesus',
                guideInputType: 'scripture',
                guideLanguage: 'ml',
                fellowships: fellowships,
              ),
            ),
          ),
          dark: language == AppLanguage.english,
          language: language,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        const title = {'Matthew 4: The Temptation of Jesus'};
        expectNoTruncatedText(tester, allowed: title);

        await tester.tap(find.text('Morning Word'));
        await tester.pumpAndSettle();
        if (language == AppLanguage.english) {
          expect(find.text('Share to 1 fellowship'), findsOneWidget);
          expect(find.text('1 member'), findsOneWidget);
          expect(find.text('Guided by Discipler · 3 members'), findsOneWidget);
        }
        expectNoTruncatedText(tester, allowed: title);
      });
    }
  });
}
