// Widget tests for the restyled fellowship screens: fellowship home, feed,
// post detail, members and lessons, plus the sheets and dialogs they open.
//
// Each screen is rendered dark and light, at 320x640, in English, Hindi and
// Malayalam: nothing may overflow and no label may be cut off. Key taps must
// still dispatch the same bloc events as before the restyle.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:dartz/dartz.dart' show Right;
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/current_study_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_meeting_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_feed_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_home_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_lessons_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_members_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_post_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_report_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mentor_contact_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/text_fit.dart' show loadAppFonts;
import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockCommunityRepository extends Mock implements CommunityRepository {}

class _MockLanguagePrefs extends Mock implements LanguagePreferenceService {}

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

class _MockMeetingsBloc
    extends MockBloc<FellowshipMeetingsEvent, FellowshipMeetingsState>
    implements FellowshipMeetingsBloc {}

// ── Fixtures ────────────────────────────────────────────────────────────────

const _prayer = FellowshipPostEntity(
  id: 'p1',
  fellowshipId: 'f1',
  authorUserId: 'u-priya',
  content:
      "Please pray for my mother's surgery on Thursday. Trusting God for peace for our family.",
  postType: 'prayer',
  reactionCounts: {'i_prayed': 4},
  isDeleted: false,
  createdAt: '2026-03-21T10:00:00Z',
  authorDisplayName: 'Priya Thomas',
  commentCount: 2,
);

const _daily = FellowshipPostEntity(
  id: 'd1',
  fellowshipId: 'f1',
  authorUserId: kDisciplerUserId,
  content: '📖 Who is Jesus Christ?\n\n'
      '✨ Jesus asked His disciples, "Who do you say that I am?"\n\n'
      '✝️ Matthew 16:15-16',
  postType: 'daily',
  reactionCounts: {'fire': 6},
  isDeleted: false,
  createdAt: '2026-03-21T06:00:00Z',
  authorDisplayName: 'Discipler',
  commentCount: 2,
  guideTitle: 'New Believer Essentials',
  lessonIndex: 1,
);

const _comments = [
  FellowshipCommentEntity(
    id: 'c1',
    postId: 'p1',
    authorUserId: 'u-joel',
    content: 'Praying with you, Priya. The Lord is near.',
    isDeleted: false,
    createdAt: '2026-03-21T11:00:00Z',
    authorDisplayName: 'Joel Mathew',
  ),
  FellowshipCommentEntity(
    id: 'c2',
    postId: 'p1',
    authorUserId: kDisciplerUserId,
    content: 'Do not be anxious about anything. — Philippians 4:6',
    isDeleted: false,
    createdAt: '2026-03-21T11:10:00Z',
    authorDisplayName: 'Discipler',
  ),
];

const _members = [
  FellowshipMemberEntity(
    userId: 'u-fenn',
    displayName: 'Fenn Saji',
    role: 'mentor',
    joinedAt: '2025-03-01T00:00:00Z',
    isMuted: false,
    isOwner: true,
    topicsCompleted: 3,
    mentorWhatsapp: '+911234567890',
    mentorEmail: 'fenn@example.com',
  ),
  FellowshipMemberEntity(
    userId: 'u-priya',
    displayName: 'Priya Thomas',
    role: 'member',
    joinedAt: '2025-04-01T00:00:00Z',
    isMuted: true,
    topicsCompleted: 8,
  ),
  FellowshipMemberEntity(
    userId: 'u-joel',
    displayName: 'Joel Mathew',
    role: 'member',
    joinedAt: '2025-05-01T00:00:00Z',
    isMuted: false,
    topicsCompleted: 1,
  ),
];

const _fellowship = FellowshipEntity(
  id: 'f1',
  name: 'Disciplefy',
  memberCount: 3,
  userRole: 'mentor',
  joinedAt: '2025-03-01T00:00:00Z',
  createdAt: '2025-03-01T00:00:00Z',
  isOfficial: true,
  currentStudy: CurrentStudyEntity(
    learningPathId: 'path1',
    learningPathTitle: 'New Believer Essentials',
    currentGuideIndex: 0,
    startedAt: '2026-09-01T00:00:00Z',
    totalGuides: 8,
  ),
  mentors: [FellowshipMentorEntity(userId: 'u-fenn', displayName: 'Fenn Saji')],
);

const _studyState = FellowshipStudyState(
  fellowshipId: 'f1',
  isMentor: true,
  currentLearningPathId: 'path1',
  currentPathTitle: 'New Believer Essentials',
  currentGuideIndex: 1,
  totalGuides: 3,
);

LearningPathTopic _topic(int position, String title,
        {bool completed = false, bool milestone = false}) =>
    LearningPathTopic(
      position: position,
      isMilestone: milestone,
      topicId: 't$position',
      title: title,
      description: '',
      category: 'Foundations of Faith',
      xpValue: 50,
      isCompleted: completed,
    );

final _pathDetail = LearningPathDetail(
  id: 'path1',
  slug: 'nbe',
  title: 'New Believer Essentials',
  description: 'Start here',
  iconName: 'book',
  color: '#4F46E5',
  totalXp: 150,
  estimatedDays: 7,
  discipleLevel: 'seeker',
  topics: [
    _topic(0, 'Who is Jesus Christ?', completed: true),
    _topic(1, 'What is the Gospel and why does it matter?', milestone: true),
    _topic(2, 'Assurance of Salvation'),
  ],
);

FellowshipMeetingEntity _meeting() => FellowshipMeetingEntity(
      id: 'm1',
      fellowshipId: 'f1',
      createdBy: 'u-fenn',
      title: 'Sunday Bible Study',
      startsAt: DateTime(2026, 10, 4, 19).toUtc().toIso8601String(),
      endsAt: DateTime(2026, 10, 4, 20).toUtc().toIso8601String(),
      meetLink: 'https://meet.google.com/abc',
      createdAt: '2026-09-01T00:00:00Z',
    );

// ── Harness ─────────────────────────────────────────────────────────────────

late FakeTranslationService _translations;
late _MockFeedBloc _feed;
late _MockMembersBloc _membersBloc;
late _MockStudyBloc _study;
late _MockPathsBloc _paths;
late _MockMeetingsBloc _meetings;

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  bool dark = true,
  AppLanguage language = AppLanguage.english,
  Size size = const Size(320, 640),
  bool provideBlocs = true,
}) async {
  _translations.language = language;
  useSurface(tester, size);
  final app = MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(language.code),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: screen,
  );
  await tester.pumpWidget(provideBlocs
      ? MultiBlocProvider(
          providers: [
            BlocProvider<FellowshipFeedBloc>.value(value: _feed),
            BlocProvider<FellowshipMembersBloc>.value(value: _membersBloc),
            BlocProvider<FellowshipStudyBloc>.value(value: _study),
            BlocProvider<LearningPathsBloc>.value(value: _paths),
            BlocProvider<FellowshipMeetingsBloc>.value(value: _meetings),
          ],
          child: app,
        )
      : app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectClean(WidgetTester tester, {Set<String> allowed = const {}}) {
  expect(tester.takeException(), isNull);
  // Author names and previewed post text ellipsize by design.
  expectNoTruncatedText(tester, allowed: {
    ...allowed,
    'Priya Thomas',
    _prayer.content,
  });
}

const _variants = [
  (AppLanguage.english, true),
  (AppLanguage.english, false),
  (AppLanguage.hindi, true),
  (AppLanguage.hindi, false),
  (AppLanguage.malayalam, true),
  (AppLanguage.malayalam, false),
];

String _label((AppLanguage, bool) v) =>
    '${v.$1.code} ${v.$2 ? 'dark' : 'light'}';

void main() {
  setUpAll(() async {
    // Real Inter/Poppins metrics for Latin text; Hindi and Malayalam still
    // fall back to the wider test font, which stresses the layouts.
    await loadAppFonts();
    registerFallbackValue(const FellowshipFeedLoadRequested(fellowshipId: ''));
    registerFallbackValue(
        const FellowshipMembersLoadRequested(fellowshipId: ''));
    registerFallbackValue(const FellowshipStudyRefreshRequested());
    SharedPreferences.setMockInitialValues({});
    // FellowshipHomeScreen reads the signed-in user id from Supabase.
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  setUp(() {
    _translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(_translations);
    _feed = _MockFeedBloc();
    _membersBloc = _MockMembersBloc();
    _study = _MockStudyBloc();
    _paths = _MockPathsBloc();
    _meetings = _MockMeetingsBloc();
    when(() => _feed.state).thenReturn(const FellowshipFeedState());
    when(() => _membersBloc.state).thenReturn(const FellowshipMembersState());
    when(() => _study.state).thenReturn(_studyState);
    when(() => _paths.state).thenReturn(const LearningPathsInitial());
    when(() => _meetings.state).thenReturn(const FellowshipMeetingsState());
  });

  tearDown(() async => sl.reset());

  // ── Post detail ───────────────────────────────────────────────────────────

  group('post detail', () {
    setUp(() {
      when(() => _feed.state).thenReturn(const FellowshipFeedState(
        status: FellowshipFeedStatus.success,
        posts: [_prayer],
        comments: _comments,
        commentsStatus: FellowshipCommentsStatus.success,
        currentUserId: 'u-joel',
      ));
    });

    for (final v in _variants) {
      testWidgets('fits 320 wide — ${_label(v)}', (tester) async {
        await _pump(
          tester,
          const FellowshipPostDetailScreen(fellowshipId: 'f1', postId: 'p1'),
          language: v.$1,
          dark: v.$2,
        );
        _expectClean(tester);
      });
    }

    testWidgets('shows the post, the replies label, replies and composer',
        (tester) async {
      await _pump(
        tester,
        const FellowshipPostDetailScreen(fellowshipId: 'f1', postId: 'p1'),
        size: const Size(390, 900),
      );
      expect(find.text('Post'), findsOneWidget);
      expect(find.text('Priya Thomas'), findsOneWidget);
      // The label above the thread (the card has no reply button here).
      expect(find.text('2 replies'), findsOneWidget);
      expect(find.text('Joel Mathew'), findsOneWidget);
      expect(find.text('Add a comment…'), findsOneWidget);
      expect(find.byTooltip('Mention someone'), findsOneWidget);
      verify(() =>
              _feed.add(const FellowshipCommentsOpenRequested(postId: 'p1')))
          .called(1);
    });

    testWidgets('sending a reply dispatches the same create event',
        (tester) async {
      await _pump(
        tester,
        const FellowshipPostDetailScreen(fellowshipId: 'f1', postId: 'p1'),
        size: const Size(390, 900),
      );
      await tester.enterText(find.byType(TextField), 'Amen');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      verify(() => _feed.add(const FellowshipCommentCreateRequested(
            content: 'Amen',
          ))).called(1);
    });

    testWidgets('a removed post says so', (tester) async {
      when(() => _feed.state).thenReturn(
          const FellowshipFeedState(status: FellowshipFeedStatus.success));
      await _pump(
        tester,
        const FellowshipPostDetailScreen(fellowshipId: 'f1', postId: 'gone'),
      );
      expect(find.textContaining("isn't available"), findsOneWidget);
    });
  });

  // ── Feed ──────────────────────────────────────────────────────────────────

  group('feed', () {
    const feedState = FellowshipFeedState(
      status: FellowshipFeedStatus.success,
      posts: [_daily, _prayer],
      hasMore: false,
      postingContextResolved: true,
    );

    for (final v in _variants) {
      testWidgets('fits 320 wide — ${_label(v)}', (tester) async {
        when(() => _feed.state).thenReturn(feedState);
        await _pump(
          tester,
          const Scaffold(body: FellowshipFeedTabScreen(fellowshipId: 'f1')),
          language: v.$1,
          dark: v.$2,
          size: const Size(320, 1400),
        );
        _expectClean(tester, allowed: {'Priya Thomas'});
      });

      testWidgets('new post sheet fits 320 wide — ${_label(v)}',
          (tester) async {
        when(() => _feed.state).thenReturn(feedState);
        await _pump(
          tester,
          const Scaffold(body: FellowshipFeedTabScreen(fellowshipId: 'f1')),
          language: v.$1,
          dark: v.$2,
          size: const Size(320, 900),
        );
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        expect(find.byType(FellowshipCreatePostSheet), findsOneWidget);
        _expectClean(tester, allowed: {'Priya Thomas'});
      });
    }

    testWidgets('error state retry reloads the feed', (tester) async {
      when(() => _feed.state).thenReturn(const FellowshipFeedState(
        status: FellowshipFeedStatus.failure,
        errorMessage: 'Offline',
      ));
      await _pump(
        tester,
        const Scaffold(body: FellowshipFeedTabScreen(fellowshipId: 'f1')),
      );
      await tester.tap(find.text('Retry'));
      verify(() =>
              _feed.add(const FellowshipFeedLoadRequested(fellowshipId: 'f1')))
          .called(1);
    });

    testWidgets('creating a post dispatches the same event', (tester) async {
      when(() => _feed.state).thenReturn(feedState);
      await _pump(
        tester,
        const Scaffold(body: FellowshipFeedTabScreen(fellowshipId: 'f1')),
        size: const Size(390, 900),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prayer').last);
      await tester.enterText(
          find.descendant(
              of: find.byType(FellowshipCreatePostSheet),
              matching: find.byType(TextField)),
          'Pray for us');
      await tester.tap(find.text('Post'));
      verify(() => _feed.add(const FellowshipPostCreateRequested(
            fellowshipId: 'f1',
            content: 'Pray for us',
            postType: 'prayer',
          ))).called(1);
    });
  });

  // ── Members ───────────────────────────────────────────────────────────────

  group('members', () {
    const membersState = FellowshipMembersState(
      status: FellowshipMembersStatus.success,
      members: _members,
      isMentor: true,
      currentUserId: 'u-fenn',
    );

    for (final v in _variants) {
      testWidgets('fits 320 wide — ${_label(v)}', (tester) async {
        when(() => _membersBloc.state).thenReturn(membersState);
        when(() => _paths.state)
            .thenReturn(LearningPathDetailLoaded(pathDetail: _pathDetail));
        await _pump(
          tester,
          const FellowshipMembersTabScreen(
            fellowshipId: 'f1',
            disciplerAllowed: true,
          ),
          language: v.$1,
          dark: v.$2,
          size: const Size(320, 1000),
        );
        _expectClean(tester);
        // The viewer's own row (u-fenn) is marked "(you)".
        expect(find.textContaining('Fenn Saji'), findsOneWidget);
        expect(find.byType(DisciplerAvatar), findsOneWidget);
      });
    }

    testWidgets('error retry reloads the members', (tester) async {
      when(() => _membersBloc.state).thenReturn(const FellowshipMembersState(
        status: FellowshipMembersStatus.failure,
        errorMessage: 'Offline',
      ));
      await _pump(tester, const FellowshipMembersTabScreen(fellowshipId: 'f1'));
      await tester.tap(find.byIcon(Icons.refresh));
      verify(() => _membersBloc.add(
          const FellowshipMembersLoadRequested(fellowshipId: 'f1'))).called(1);
    });

    testWidgets('removing a member asks first, then dispatches',
        (tester) async {
      when(() => _membersBloc.state).thenReturn(membersState);
      await _pump(
        tester,
        const FellowshipMembersTabScreen(fellowshipId: 'f1'),
        size: const Size(390, 900),
      );
      // Joel's menu (the last member card).
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove Member').last);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      verify(() => _membersBloc.add(
          const FellowshipMembersRemoveRequested(userId: 'u-joel'))).called(1);
    });
  });

  // ── Lessons ───────────────────────────────────────────────────────────────

  group('lessons', () {
    for (final v in _variants) {
      testWidgets('fits 320 wide — ${_label(v)}', (tester) async {
        when(() => _membersBloc.state).thenReturn(const FellowshipMembersState(
          status: FellowshipMembersStatus.success,
          members: _members,
          isMentor: true,
        ));
        when(() => _paths.state)
            .thenReturn(LearningPathDetailLoaded(pathDetail: _pathDetail));
        await _pump(
          tester,
          const Scaffold(
            body: FellowshipLessonsTabScreen(
              fellowshipId: 'f1',
              languageOverride: 'en',
            ),
          ),
          language: v.$1,
          dark: v.$2,
          size: const Size(320, 2400),
        );
        _expectClean(tester);
        expect(find.text('Assurance of Salvation'), findsOneWidget);
      });
    }

    testWidgets('no path: a member sees the placeholder, no assign button',
        (tester) async {
      when(() => _study.state)
          .thenReturn(const FellowshipStudyState(fellowshipId: 'f1'));
      await _pump(
        tester,
        const Scaffold(
          body: FellowshipLessonsTabScreen(
            fellowshipId: 'f1',
            languageOverride: 'en',
          ),
        ),
      );
      _expectClean(tester);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    });

    testWidgets('advancing asks first, then dispatches', (tester) async {
      when(() => _membersBloc.state).thenReturn(const FellowshipMembersState(
        status: FellowshipMembersStatus.success,
        members: _members,
        isMentor: true,
      ));
      await _pump(
        tester,
        const Scaffold(
          body: FellowshipLessonsTabScreen(
            fellowshipId: 'f1',
            languageOverride: 'en',
          ),
        ),
        size: const Size(390, 1600),
      );
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      verify(() => _study.add(const FellowshipStudyAdvanceRequested()))
          .called(1);
    });
  });

  // ── Fellowship home ───────────────────────────────────────────────────────

  group('fellowship home', () {
    setUp(() {
      sl.registerFactory<FellowshipFeedBloc>(() => _feed);
      sl.registerFactory<FellowshipMembersBloc>(() => _membersBloc);
      sl.registerFactory<FellowshipStudyBloc>(() => _study);
      sl.registerFactory<LearningPathsBloc>(() => _paths);
      sl.registerFactory<FellowshipMeetingsBloc>(() => _meetings);
      when(() => _feed.state).thenReturn(const FellowshipFeedState(
        status: FellowshipFeedStatus.success,
        posts: [_daily, _prayer],
        hasMore: false,
        postingContextResolved: true,
        isMentor: true,
      ));
      when(() => _membersBloc.state).thenReturn(const FellowshipMembersState(
        status: FellowshipMembersStatus.success,
        members: _members,
        isMentor: true,
      ));
      when(() => _study.state).thenReturn(const FellowshipStudyState(
        fellowshipId: 'f1',
        isMentor: true,
        currentLearningPathId: 'path1',
        currentPathTitle: 'New Believer Essentials',
        currentGuideIndex: 0,
        totalGuides: 8,
      ));
      when(() => _meetings.state).thenReturn(FellowshipMeetingsState(
        status: FellowshipMeetingsStatus.success,
        meetings: [_meeting()],
      ));
    });

    const home = FellowshipHomeScreen(
      fellowshipId: 'f1',
      fellowshipName: 'Disciplefy',
      fellowship: _fellowship,
    );

    for (final v in _variants) {
      testWidgets('fits 320 wide — ${_label(v)}', (tester) async {
        await _pump(
          tester,
          home,
          language: v.$1,
          dark: v.$2,
          size: const Size(320, 2600),
          provideBlocs: false,
        );
        _expectClean(tester, allowed: {'Priya Thomas'});
      });
    }

    testWidgets('meta line, name, study card, next meeting and activity',
        (tester) async {
      await _pump(tester, home,
          size: const Size(390, 2400), provideBlocs: false);
      expect(find.text('OFFICIAL · 3 MEMBERS · MENTOR: FENN SAJI'),
          findsOneWidget);
      expect(find.text('Disciplefy'), findsOneWidget);
      expect(find.text('Message mentor'), findsOneWidget);
      expect(find.text('STUDYING TOGETHER'), findsOneWidget);
      expect(find.text('New Believer Essentials · Lesson 1'), findsOneWidget);
      expect(find.text('Group progress · 1 of 8'), findsOneWidget);
      expect(find.text('Next: Sunday Bible Study'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Start study'), findsOneWidget);
    });

    testWidgets('overflow menu keeps every mentor item', (tester) async {
      await _pump(tester, home,
          size: const Size(390, 1200), provideBlocs: false);
      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      expect(find.text('Fellowship Settings'), findsOneWidget);
      expect(find.text('Delete Fellowship'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    });

    testWidgets('deleting asks first, then dispatches', (tester) async {
      await _pump(tester, home,
          size: const Size(390, 1200), provideBlocs: false);
      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Fellowship'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      verify(() => _membersBloc.add(const FellowshipDeleteRequested()))
          .called(1);
    });
  });

  // ── Opened by id only (Home banner, activity row, deep link) ─────────────

  group('fellowship home opened by id without the entity', () {
    const byId = FellowshipHomeScreen(fellowshipId: 'f1');

    void stubRole({required bool mentor}) {
      sl.registerFactory<FellowshipFeedBloc>(() => _feed);
      sl.registerFactory<FellowshipMembersBloc>(() => _membersBloc);
      sl.registerFactory<FellowshipStudyBloc>(() => _study);
      sl.registerFactory<LearningPathsBloc>(() => _paths);
      sl.registerFactory<FellowshipMeetingsBloc>(() => _meetings);
      when(() => _feed.state).thenReturn(FellowshipFeedState(
        status: FellowshipFeedStatus.success,
        hasMore: false,
        postingContextResolved: true,
        isMentor: mentor,
      ));
      when(() => _membersBloc.state).thenReturn(FellowshipMembersState(
        status: FellowshipMembersStatus.success,
        members: _members,
        isMentor: mentor,
      ));
      when(() => _study.state)
          .thenReturn(const FellowshipStudyState(fellowshipId: 'f1'));
    }

    testWidgets('a mentor still gets the mentor controls', (tester) async {
      stubRole(mentor: true);
      await _pump(tester, byId,
          size: const Size(390, 1200), provideBlocs: false);
      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      expect(find.text('Fellowship Settings'), findsOneWidget);
      expect(find.text('Delete Fellowship'), findsOneWidget);
      verify(() =>
              _study.add(const FellowshipStudyRoleResolved(isMentor: true)))
          .called(1);
    });

    testWidgets('loads the entity by id: daily post and discipler items',
        (tester) async {
      // Blocs have not resolved the role yet; only the loaded entity knows.
      stubRole(mentor: false);
      final repo = _MockCommunityRepository();
      final prefs = _MockLanguagePrefs();
      when(prefs.getStudyContentLanguage)
          .thenAnswer((_) async => AppLanguage.english);
      when(() => repo.getFellowships(any())).thenAnswer((_) async => Right([
            FellowshipEntity(
              id: 'other',
              name: 'Other',
              memberCount: 1,
              userRole: 'member',
              joinedAt: _fellowship.joinedAt,
              createdAt: _fellowship.createdAt,
            ),
            const FellowshipEntity(
              id: 'f1',
              name: 'Loaded Group',
              memberCount: 3,
              userRole: 'mentor',
              joinedAt: '2025-03-01T00:00:00Z',
              createdAt: '2025-03-01T00:00:00Z',
              dailyPostAllowed: true,
              disciplerAllowed: true,
            ),
          ]));
      sl.registerSingleton<CommunityRepository>(repo);
      sl.registerSingleton<LanguagePreferenceService>(prefs);
      await _pump(tester, byId,
          size: const Size(390, 1200), provideBlocs: false);
      await tester.pumpAndSettle();
      expect(find.text('Loaded Group'), findsWidgets);
      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      expect(find.text('Fellowship Settings'), findsOneWidget);
      expect(find.text('Daily post'), findsOneWidget);
      expect(find.text('Discipler activity'), findsOneWidget);
      verify(() => repo.getFellowships(any())).called(1);
    });

    testWidgets('a member does not get the mentor controls', (tester) async {
      stubRole(mentor: false);
      await _pump(tester, byId,
          size: const Size(390, 1200), provideBlocs: false);
      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      expect(find.text('Fellowship Settings'), findsNothing);
      expect(find.text('Delete Fellowship'), findsNothing);
      expect(find.text('Leave Fellowship'), findsOneWidget);
      verifyNever(
          () => _study.add(any(that: isA<FellowshipStudyRoleResolved>())));
    });
  });

  // ── Sheets and dialogs ────────────────────────────────────────────────────

  group('sheets and dialogs', () {
    for (final v in _variants) {
      testWidgets('report sheet fits 320 wide — ${_label(v)}', (tester) async {
        when(() => _feed.state).thenReturn(const FellowshipFeedState());
        await _pump(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BlocProvider<FellowshipFeedBloc>.value(
                    value: _feed,
                    child: const FellowshipReportSheet(
                      fellowshipId: 'f1',
                      contentType: 'post',
                      contentId: 'p1',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          language: v.$1,
          dark: v.$2,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        _expectClean(tester);
      });

      testWidgets('mentor contact sheet fits 320 wide — ${_label(v)}',
          (tester) async {
        await _pump(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMentorContactSheet(
                  context,
                  mentorsWithContact: [_members.first],
                  fellowshipName: 'Disciplefy',
                ),
                child: const Text('open'),
              ),
            ),
          ),
          language: v.$1,
          dark: v.$2,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        _expectClean(tester);
        expect(find.text('Fenn Saji'), findsOneWidget);
      });

      testWidgets('block dialog fits 320 wide — ${_label(v)}', (tester) async {
        bool? result;
        await _pump(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showBlockUserConfirmation(context),
                child: const Text('open'),
              ),
            ),
          ),
          language: v.$1,
          dark: v.$2,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        _expectClean(tester);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });
    }

    testWidgets('report needs at least 5 characters', (tester) async {
      when(() => _feed.state).thenReturn(const FellowshipFeedState());
      await _pump(
        tester,
        Scaffold(
          body: BlocProvider<FellowshipFeedBloc>.value(
            value: _feed,
            child: const FellowshipReportSheet(
              fellowshipId: 'f1',
              contentType: 'post',
              contentId: 'p1',
            ),
          ),
        ),
        size: const Size(390, 800),
      );
      await tester.enterText(find.byType(TextFormField), 'bad');
      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(find.text('Please write at least 5 characters.'), findsOneWidget);
      verifyNever(() => _feed.add(any()));
    });
  });
}
