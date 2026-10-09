// Community tab: Discover opens on the app language, joining a public
// fellowship opens it with a confirmation, joining has one entry (the key
// icon) and the Discipler is labelled "Guided by Discipler".

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
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/community_tab_screen.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../../helpers/text_fit.dart' show loadAppFonts;
import '../../../helpers/welcome_test_harness.dart';
import '../../settings/text_fit.dart';

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

const _official = FellowshipEntity(
  id: 'f-official',
  name: 'Disciplefy',
  memberCount: 3,
  userRole: 'member',
  joinedAt: '2026-01-01',
  createdAt: '2026-01-01',
  isOfficial: true,
);

const _publicHindi = PublicFellowshipEntity(
  id: 'pub-hi',
  name: 'Disciplefy हिन्दी',
  description: 'Disciplefy की आधिकारिक संगति।',
  language: 'hi',
  memberCount: 1,
  maxMembers: null,
  isOfficial: true,
);

void main() {
  late _MockListBloc listBloc;
  late _MockDiscoverBloc discoverBloc;
  late _MockTokenBloc tokenBloc;
  late _MockConnectivityBloc connectivityBloc;
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;
  late List<String> visited;

  setUpAll(() async {
    await loadAppFonts();
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

    when(() => listBloc.state).thenReturn(const FellowshipListState(
      status: FellowshipListStatus.success,
      fellowships: [_official],
    ));
    when(() => discoverBloc.state).thenReturn(const DiscoverState());
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

  for (final language in AppLanguage.values) {
    testWidgets('Discover defaults to the app language (${language.code})',
        (tester) async {
      useSurface(tester, const Size(390, 900));
      await pump(tester, language: language);
      // The mocked bloc stays on its initial (spinner) state, so pump frames
      // rather than settle.
      await tester.tap(find
          .text(translations.getTranslation('community_shared.discover_tab')));
      await tester.pump();
      await tester.pump();
      verify(() =>
              discoverBloc.add(DiscoverLoadRequested(language: language.code)))
          .called(1);
      verifyNever(() => discoverBloc.add(const DiscoverLoadRequested()));
    });
  }

  testWidgets('joining opens the group with a confirmation', (tester) async {
    const loaded = DiscoverState(
      status: DiscoverStatus.success,
      language: 'hi',
      fellowships: [_publicHindi],
    );
    whenListen(
      discoverBloc,
      Stream<DiscoverState>.fromIterable([
        loaded.copyWith(
          fellowships: const [],
          justJoinedId: () => 'pub-hi',
          justJoinedName: () => 'Disciplefy हिन्दी',
        ),
      ]),
      initialState: loaded,
    );
    useSurface(tester, const Size(390, 900));
    await pump(tester);
    await openDiscover(tester);

    expect(visited, ['/community/pub-hi']);
    expect(find.text('You joined Disciplefy हिन्दी'), findsOneWidget);
    verify(() => discoverBloc.add(const DiscoverJoinAcknowledged())).called(1);
    verify(() => listBloc.add(const FellowshipListLoadRequested()))
        .called(greaterThanOrEqualTo(1));
  });

  testWidgets('no "Mentor:" label for the Discipler', (tester) async {
    when(() => discoverBloc.state).thenReturn(const DiscoverState(
      status: DiscoverStatus.success,
      language: 'hi',
      fellowships: [_publicHindi],
    ));
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    expect(find.text('Guided by Discipler · 3 members'), findsOneWidget);
    expect(find.textContaining('Mentor:'), findsNothing);

    await openDiscover(tester);
    expect(find.text('Guided by Discipler · 1 member'), findsOneWidget);
    expect(find.textContaining('Mentor:'), findsNothing);
  });

  testWidgets('one join entry: the key icon, labelled, no floating pill',
      (tester) async {
    useSurface(tester, const Size(390, 900));
    await pump(tester);

    expect(find.text('Join a Fellowship'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Join with invite code'), findsOneWidget);

    await tester.tap(find.byTooltip('Join with invite code'));
    await tester.pumpAndSettle();
    expect(visited, ['/community/join']);
  });

  group('fits 320 wide', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          when(() => discoverBloc.state).thenReturn(DiscoverState(
            status: DiscoverStatus.success,
            language: language.code,
            fellowships: const [_publicHindi],
          ));
          useSurface(tester, const Size(320, 640));
          await pump(tester, dark: dark, language: language);
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);

          await openDiscover(tester);
          expectNoTruncatedText(tester, allowed: {_publicHindi.description!});
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
