import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/current_study_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/community_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockListBloc extends MockBloc<FellowshipListEvent, FellowshipListState>
    implements FellowshipListBloc {}

class _MockDiscoverBloc extends MockBloc<DiscoverEvent, DiscoverState>
    implements DiscoverBloc {}

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _SeenWalkthrough extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

const _me = 'user-me';

final _fellowships = [
  const FellowshipEntity(
    id: 'f-official',
    name: 'Disciplefy',
    memberCount: 3,
    userRole: 'member',
    joinedAt: '2026-01-01',
    createdAt: '2026-01-01',
    isOfficial: true,
    currentStudy: CurrentStudyEntity(
      learningPathId: 'p1',
      learningPathTitle: 'New Believer Essentials',
      currentGuideIndex: 0,
      startedAt: '2026-01-01',
      totalGuides: 8,
    ),
  ),
  const FellowshipEntity(
    id: 'f-mine',
    name: 'Daily Post Test Group with a rather long fellowship name',
    memberCount: 1,
    userRole: 'mentor',
    joinedAt: '2026-01-01',
    createdAt: '2026-01-01',
    mentors: [FellowshipMentorEntity(userId: _me, displayName: 'Fenn')],
    currentStudy: CurrentStudyEntity(
      learningPathId: 'p2',
      learningPathTitle: 'The Gospel of Matthew',
      currentGuideIndex: 2,
      startedAt: '2026-01-01',
      totalGuides: 29,
    ),
  ),
];

const _publicFellowships = [
  PublicFellowshipEntity(
    id: 'pub-hi',
    name: 'Disciplefy हिन्दी',
    description:
        'Disciplefy की आधिकारिक संगति। हर दिन एक नए पाठ के साथ मिलकर बाइबल का अध्ययन करें।',
    language: 'hi',
    memberCount: 1,
    maxMembers: null,
    isOfficial: true,
  ),
  PublicFellowshipEntity(
    id: 'pub-en',
    name: 'Tuesday Group',
    description: 'We read together.',
    language: 'en',
    memberCount: 20,
    maxMembers: 20,
    mentorName: 'Anna George',
    currentStudyTitle: 'Romans',
  ),
];

void main() {
  late _MockListBloc listBloc;
  late _MockDiscoverBloc discoverBloc;
  late _MockTokenBloc tokenBloc;
  late _MockConnectivityBloc connectivityBloc;
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;
  late List<String> visited;

  setUpAll(() {
    registerFallbackValue(const DiscoverLoadRequested());
    registerFallbackValue(const FellowshipListLoadRequested());
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<WalkthroughRepository>(_SeenWalkthrough());

    listBloc = _MockListBloc();
    discoverBloc = _MockDiscoverBloc();
    tokenBloc = _MockTokenBloc();
    connectivityBloc = _MockConnectivityBloc();
    authBloc = MockAuthBloc();
    visited = [];

    when(() => listBloc.state).thenReturn(FellowshipListState(
      status: FellowshipListStatus.success,
      fellowships: _fellowships,
    ));
    when(() => discoverBloc.state).thenReturn(const DiscoverState(
      status: DiscoverStatus.success,
      fellowships: _publicFellowships,
    ));
    when(() => tokenBloc.state).thenReturn(const TokenInitial());
    when(() => connectivityBloc.state).thenReturn(ConnectivityOnline());
    when(() => authBloc.state).thenReturn(AuthenticatedState(
      user: User(
        id: _me,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
    ));
  });

  tearDown(() async => sl.reset());

  Widget app({bool dark = true, AppLanguage language = AppLanguage.english}) {
    final router = GoRouter(
      initialLocation: '/community',
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider<FellowshipListBloc>.value(value: listBloc),
              BlocProvider<DiscoverBloc>.value(value: discoverBloc),
            ],
            child: ShowCaseWidget(
              builder: (_) => const CommunityTabContent(),
            ),
          ),
          routes: [
            GoRoute(
              path: 'join',
              builder: (_, __) {
                visited.add('/community/join');
                return const Scaffold(body: Text('stub:join'));
              },
            ),
            GoRoute(
              path: 'create',
              builder: (_, __) {
                visited.add('/community/create');
                return const Scaffold(body: Text('stub:create'));
              },
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) {
                visited.add('/community/${state.pathParameters['id']}');
                return Scaffold(
                    body: Text('stub:${state.pathParameters['id']}'));
              },
            ),
          ],
        ),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<TokenBloc>.value(value: tokenBloc),
        BlocProvider<ConnectivityBloc>.value(value: connectivityBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(language.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
  }

  Future<void> pump(WidgetTester tester,
      {bool dark = true, AppLanguage language = AppLanguage.english}) async {
    translations.language = language;
    await tester.pumpWidget(app(dark: dark, language: language));
    await tester.pumpAndSettle();
  }

  Future<void> openDiscover(WidgetTester tester) async {
    await tester.tap(find
        .text(translations.getTranslation('community_shared.discover_tab')));
    await tester.pumpAndSettle();
  }

  group('fits 320x640 without overflow or truncated labels', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          await pump(tester, dark: dark, language: language);
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);

          await openDiscover(tester);
          // Descriptions are user content and may clamp at three lines.
          expectNoTruncatedText(tester, allowed: {
            for (final f in _publicFellowships) f.description!,
          });
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('My fellowships card shows mentor, members and current study',
      (tester) async {
    useSurface(tester, const Size(390, 1200));
    await pump(tester);

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Guided by Discipler · 3 members'), findsOneWidget);
    expect(find.text('Mentor: Fenn (you) · 1 member'), findsOneWidget);
    expect(find.text('New Believer Essentials · Lesson 1'), findsOneWidget);
    expect(find.text('0 of 8 done'), findsOneWidget);
    expect(find.text('The Gospel of Matthew · Lesson 3'), findsOneWidget);
    expect(find.text('2 of 29 done'), findsOneWidget);
    expect(find.text('Official'), findsOneWidget);
    expect(find.byType(DisciplerAvatar), findsOneWidget);
    // The role pill ("Member"/"Mentor") is gone in the redesign.
    expect(find.text('Member'), findsNothing);
    // Joining by code is the key icon only; the floating pill is gone.
    expect(find.text('Join a Fellowship'), findsNothing);
  });

  testWidgets('tapping a fellowship opens its page', (tester) async {
    useSurface(tester, const Size(390, 1200));
    await pump(tester);

    await tester.tap(find.text('Guided by Discipler · 3 members'));
    await tester.pumpAndSettle();
    expect(visited, ['/community/f-official']);
  });

  testWidgets('the key action opens Join', (tester) async {
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    await tester.tap(find.byTooltip('Join with invite code'));
    await tester.pumpAndSettle();
    expect(visited, ['/community/join']);
  });

  testWidgets('create is locked for a free member and opens no screen',
      (tester) async {
    when(() => listBloc.state).thenReturn(FellowshipListState(
      status: FellowshipListStatus.success,
      fellowships: [_fellowships.first],
    ));
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    expect(find.byTooltip('Create a fellowship (upgrade)'), findsOneWidget);
  });

  testWidgets('the create upsell names the plan from TokenBloc (Standard)',
      (tester) async {
    when(() => listBloc.state).thenReturn(FellowshipListState(
      status: FellowshipListStatus.success,
      fellowships: [_fellowships.first],
    ));
    when(() => tokenBloc.state).thenReturn(TokenLoaded(
      tokenStatus: TokenStatus(
        availableTokens: 30,
        purchasedTokens: 0,
        totalTokens: 30,
        dailyLimit: 40,
        totalConsumedToday: 10,
        userPlan: UserPlan.standard,
        lastReset: DateTime(2026, 10, 6),
        nextResetTime: DateTime(2026, 10, 7),
        authenticationType: AuthenticationType.authenticated,
        isPremium: false,
        unlimitedUsage: false,
        canPurchaseTokens: true,
        planDescription: '',
      ),
      lastUpdated: DateTime(2026, 10, 6),
    ));
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    await tester.tap(find.byTooltip('Create a fellowship (upgrade)'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan: Standard'), findsOneWidget);
    expect(find.text('Your plan: Free'), findsNothing);
    expect(visited, isEmpty);
  });

  testWidgets('a mentor can create a fellowship', (tester) async {
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    await tester.tap(find.byTooltip('Create Fellowship'));
    await tester.pumpAndSettle();
    expect(visited, ['/community/create']);
  });

  testWidgets('Discover: filter and join dispatch the same events',
      (tester) async {
    useSurface(tester, const Size(390, 1200));
    await pump(tester);
    await openDiscover(tester);

    expect(find.text('HI'), findsOneWidget);
    expect(find.text('Guided by Discipler · 1 member'), findsOneWidget);
    expect(find.text('Mentor: Anna George · 20 members'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Romans'), findsOneWidget);
    expect(find.text('20 / 20'), findsOneWidget);

    await tester.ensureVisible(find.text('Hindi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi'));
    verify(() => discoverBloc.add(const DiscoverLoadRequested(language: 'hi')))
        .called(1);

    await tester.tap(find.text('Join'));
    verify(() => discoverBloc.add(const DiscoverJoinRequested(
          fellowshipId: 'pub-hi',
          fellowshipName: 'Disciplefy हिन्दी',
        ))).called(1);
  });

  testWidgets('empty My fellowships offers join, discover and create',
      (tester) async {
    when(() => listBloc.state).thenReturn(const FellowshipListState(
      status: FellowshipListStatus.success,
    ));
    when(() => authBloc.state).thenReturn(AuthenticatedState(
      user: User(
        id: _me,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
      profile: const {'is_admin': true},
    ));
    // Tall enough to show both buttons without scrolling.
    useSurface(tester, const Size(320, 1000));
    await pump(tester);

    expect(find.text('Explore Public Fellowships'), findsOneWidget);
    expect(find.text('Create Fellowship'), findsOneWidget,
        reason: 'admins can create');
    expectNoTruncatedText(tester);

    await tester.tap(find.text('Explore Public Fellowships'));
    await tester.pumpAndSettle();
    expect(find.text('HI'), findsOneWidget, reason: 'switched to Discover');
  });

  testWidgets('offline error shows the offline message without retry',
      (tester) async {
    when(() => listBloc.state).thenReturn(const FellowshipListState(
      status: FellowshipListStatus.failure,
      errorMessage: 'x',
    ));
    when(() => connectivityBloc.state).thenReturn(ConnectivityOffline());
    useSurface(tester, const Size(320, 640));
    await pump(tester, dark: false, language: AppLanguage.malayalam);

    expect(
        find.text(
            translations.getTranslation('community_shared.offline_title')),
        findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('load error retry reloads the list', (tester) async {
    when(() => listBloc.state).thenReturn(const FellowshipListState(
      status: FellowshipListStatus.failure,
      errorMessage: 'x',
    ));
    useSurface(tester, const Size(390, 800));
    await pump(tester);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    verify(() => listBloc.add(const FellowshipListLoadRequested())).called(1);
  });
}
