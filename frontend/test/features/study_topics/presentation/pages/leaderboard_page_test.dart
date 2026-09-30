import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/leaderboard_entry.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/leaderboard_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/leaderboard_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/leaderboard_parts.dart';

import '../../../../helpers/welcome_test_harness.dart';
import '../../../settings/text_fit.dart';

class _MockLeaderboardBloc extends MockBloc<LeaderboardEvent, LeaderboardState>
    implements LeaderboardBloc {}

const _names = [
  'Anna George',
  'Joel Mathew',
  'Priya Thomas',
  'Rahul Varghese',
  'Fenn Saji',
  'Sneha Kurian',
  'David Paul',
];
const _xp = [2840, 2610, 2380, 1990, 1720, 1610, 1480];

final _entries = [
  for (var i = 0; i < _names.length; i++)
    LeaderboardEntry(
      displayName: _names[i],
      totalXp: _xp[i],
      rank: i + 1,
      isCurrentUser: i == 4,
    ),
];

const _userRank = UserXpRank(totalXp: 1720, rank: 5);

void main() {
  late FakeTranslationService translations;
  late _MockLeaderboardBloc bloc;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    bloc = _MockLeaderboardBloc();
  });
  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    LeaderboardState state, {
    bool dark = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    translations.language = language;
    useSurface(tester, const Size(320, 640));
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(BlocProvider<LeaderboardBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(language.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LeaderboardPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('fits 320x640', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          await pump(
            tester,
            LeaderboardLoaded(entries: _entries, userRank: _userRank),
            dark: dark,
            language: language,
          );
          expect(tester.takeException(), isNull);
          // Names are user content and may ellipsize (the test font is 1em/glyph).
          expectNoTruncatedText(tester, allowed: _names.toSet());
          expect(find.byType(LeaderboardPodium), findsOneWidget);
          expect(find.text('#5'), findsOneWidget);
        });
      }
    }
  });

  testWidgets('loads on open and shows the gap to the next rank',
      (tester) async {
    await pump(
        tester, LeaderboardLoaded(entries: _entries, userRank: _userRank));
    verify(() => bloc.add(const LoadLeaderboard())).called(1);
    expect(find.text('271 XP to pass Rahul'), findsOneWidget);
    expect(find.text('AG'), findsOneWidget);
    expect(find.byType(LeaderboardRow), findsWidgets);
  });

  testWidgets('no rows or podium gap when the list is short', (tester) async {
    await pump(
      tester,
      LeaderboardLoaded(
        entries: _entries.take(2).toList(),
        userRank: const UserXpRank(totalXp: 40),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(LeaderboardRow), findsNothing);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('error state retries', (tester) async {
    await pump(tester, const LeaderboardError(message: 'x'));
    await tester.tap(
        find.text(translations.getTranslation(TranslationKeys.commonRetry)));
    verify(() => bloc.add(const RefreshLeaderboard())).called(1);
  });

  test('initials', () {
    expect(leaderboardInitials('Rahul Varghese'), 'RV');
    expect(leaderboardInitials('John D.'), 'JD');
    expect(leaderboardInitials('Fenn'), 'F');
    expect(leaderboardInitials('  '), '?');
  });
}
