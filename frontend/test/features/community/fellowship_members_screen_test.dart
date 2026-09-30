// Widget tests for the restyled fellowship Members screen: page heading with
// the member count, gold "SECTION · N" labels, role pills only for mentors,
// "(you)" on the viewer's row, every menu action still dispatching, and the
// loading / empty / error states. Rendered dark and light at 320x640 in
// English, Hindi and Malayalam with no overflow or cut-off text.

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
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_members_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/text_fit.dart' show loadAppFonts;
import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockMembersBloc
    extends MockBloc<FellowshipMembersEvent, FellowshipMembersState>
    implements FellowshipMembersBloc {}

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

const _members = [
  FellowshipMemberEntity(
    userId: 'u-fenn',
    displayName: 'Fenn Saji',
    role: 'mentor',
    joinedAt: '2025-03-01T00:00:00Z',
    isMuted: false,
    isOwner: true,
  ),
  FellowshipMemberEntity(
    userId: 'u-anna',
    displayName: 'Anna Varghese',
    role: 'mentor',
    joinedAt: '2025-03-10T00:00:00Z',
    isMuted: false,
  ),
  FellowshipMemberEntity(
    userId: 'u-priya',
    displayName: 'Priya Thomas',
    role: 'member',
    joinedAt: '2025-04-01T00:00:00Z',
    isMuted: true,
  ),
  FellowshipMemberEntity(
    userId: 'u-joel',
    displayName: 'Joel Mathew',
    role: 'member',
    joinedAt: '2025-05-01T00:00:00Z',
    isMuted: false,
  ),
];

const _mentorView = FellowshipMembersState(
  status: FellowshipMembersStatus.success,
  members: _members,
  isMentor: true,
  currentUserId: 'u-fenn',
);

const _memberView = FellowshipMembersState(
  status: FellowshipMembersStatus.success,
  members: _members,
  currentUserId: 'u-joel',
);

late FakeTranslationService _translations;
late _MockMembersBloc _bloc;
late _MockPathsBloc _paths;

Future<void> _pump(
  WidgetTester tester, {
  bool dark = true,
  AppLanguage language = AppLanguage.english,
  Size size = const Size(320, 640),
  double bottomInset = 0,
  bool disciplerAllowed = true,
}) async {
  _translations.language = language;
  useSurface(tester, size);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipMembersBloc>.value(value: _bloc),
        BlocProvider<LearningPathsBloc>.value(value: _paths),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(language.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // Stands in for the floating tab dock, which the shell adds to the
        // bottom padding.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: child!,
        ),
        home: FellowshipMembersTabScreen(
          fellowshipId: 'f1',
          fellowshipName: 'Disciplefy',
          disciplerAllowed: disciplerAllowed,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectClean(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expectNoTruncatedText(tester);
}

Future<void> _openMenuFor(WidgetTester tester, String name) async {
  final row = find.ancestor(
    of: find.textContaining(name),
    matching: find.byType(Row),
  );
  final menu =
      find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert));
  await tester.ensureVisible(menu.first);
  await tester.tap(menu.first);
  await tester.pumpAndSettle();
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
    registerFallbackValue(
        const FellowshipMembersLoadRequested(fellowshipId: ''));
  });

  setUp(() {
    _translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(_translations);
    _bloc = _MockMembersBloc();
    _paths = _MockPathsBloc();
    when(() => _bloc.state).thenReturn(_mentorView);
    when(() => _paths.state).thenReturn(const LearningPathsInitial());
  });

  tearDown(() async => sl.reset());

  group('fits 320x640', () {
    for (final v in _variants) {
      final label = '${v.$1.code} ${v.$2 ? 'dark' : 'light'}';

      testWidgets('roster — $label', (tester) async {
        await _pump(tester, language: v.$1, dark: v.$2);
        _expectClean(tester);
        // Scroll through the whole list: every row must lay out cleanly.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        _expectClean(tester);
      });

      testWidgets('empty, loading and error — $label', (tester) async {
        for (final state in const [
          FellowshipMembersState(status: FellowshipMembersStatus.loading),
          FellowshipMembersState(status: FellowshipMembersStatus.success),
          FellowshipMembersState(
            status: FellowshipMembersStatus.failure,
            errorMessage: 'Could not load members. Check your connection.',
          ),
        ]) {
          when(() => _bloc.state).thenReturn(state);
          await _pump(tester, language: v.$1, dark: v.$2);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        }
      });
    }
  });

  group('layout', () {
    testWidgets('heading shows the fellowship, title and member count',
        (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      expect(find.text('DISCIPLEFY'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);
    });

    testWidgets('sections carry gold labels with their counts', (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      expect(find.text('MENTORS · 2'), findsOneWidget);
      expect(find.text('HELPERS · 1'), findsOneWidget);
      expect(find.text('MEMBERS · 2'), findsOneWidget);
      expect(find.byType(DisciplerAvatar), findsOneWidget);
      expect(find.byType(DisciplerAiChip), findsOneWidget);
    });

    testWidgets('only mentors get a role pill; members show their join date',
        (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Mentor'), findsOneWidget);
      // The old per-row "Member" chip is gone.
      expect(find.text('Member'), findsNothing);
      expect(find.text('Joined May 2025'), findsOneWidget);
      // Muted state is still shown.
      expect(find.text('Muted'), findsOneWidget);
    });

    testWidgets("the viewer's own row is marked (you)", (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      expect(find.text('Fenn Saji (you)'), findsOneWidget);
      expect(find.text('Joel Mathew'), findsOneWidget);
    });

    testWidgets('no Helpers section when Discipler is off', (tester) async {
      await _pump(tester, size: const Size(390, 1200), disciplerAllowed: false);
      expect(find.text('HELPERS · 1'), findsNothing);
      expect(find.byType(DisciplerAvatar), findsNothing);
    });

    testWidgets('the last row scrolls clear of the dock and invite pill',
        (tester) async {
      await _pump(tester, bottomInset: 100);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      final lastRow = tester.getRect(find.text('Joel Mathew'));
      final invite = tester.getRect(find.text('Invite'));
      expect(lastRow.bottom, lessThan(640 - 100));
      expect(lastRow.bottom, lessThan(invite.top));
    });
  });

  group('actions', () {
    testWidgets('a mentor sees the invite pill', (tester) async {
      await _pump(tester);
      expect(find.text('Invite'), findsOneWidget);
    });

    testWidgets('a member does not see the invite pill', (tester) async {
      when(() => _bloc.state).thenReturn(_memberView);
      await _pump(tester);
      expect(find.text('Invite'), findsNothing);
    });

    testWidgets('mute dispatches the same event', (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Joel Mathew');
      await tester.tap(find.text('Mute member'));
      await tester.pumpAndSettle();
      verify(() =>
              _bloc.add(const FellowshipMembersMuteRequested(userId: 'u-joel')))
          .called(1);
    });

    testWidgets('unmute dispatches the same event', (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Priya Thomas');
      await tester.tap(find.text('Unmute member'));
      await tester.pumpAndSettle();
      verify(() => _bloc.add(
          const FellowshipMembersUnmuteRequested(userId: 'u-priya'))).called(1);
    });

    testWidgets('promote dispatches the same event', (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Joel Mathew');
      await tester.tap(find.text('Promote to Mentor'));
      await tester.pumpAndSettle();
      verify(() => _bloc.add(
          const FellowshipMemberPromoteRequested(userId: 'u-joel'))).called(1);
    });

    testWidgets('demote is offered on a promoted mentor, not the owner',
        (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Anna Varghese');
      await tester.tap(find.text('Demote to Member'));
      await tester.pumpAndSettle();
      verify(() => _bloc.add(
          const FellowshipMemberDemoteRequested(userId: 'u-anna'))).called(1);

      // The owner's own row has no menu at all (no block on yourself).
      final ownerRow = find.ancestor(
          of: find.text('Fenn Saji (you)'), matching: find.byType(Row));
      expect(
          find.descendant(
              of: ownerRow.first, matching: find.byIcon(Icons.more_vert)),
          findsNothing);
    });

    testWidgets('mentor menu keeps every entry', (tester) async {
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Joel Mathew');
      for (final label in const [
        'Mute member',
        'Transfer Mentor Role',
        'Promote to Mentor',
        'Remove Member',
        'Block User',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a member is only offered Block on others', (tester) async {
      when(() => _bloc.state).thenReturn(_memberView);
      await _pump(tester, size: const Size(390, 1200));
      await _openMenuFor(tester, 'Priya Thomas');
      expect(find.text('Block User'), findsOneWidget);
      expect(find.text('Mute member'), findsNothing);
      expect(find.text('Unmute member'), findsNothing);
      expect(find.text('Remove Member'), findsNothing);
      expect(find.text('Promote to Mentor'), findsNothing);
    });

    testWidgets('error retry reloads the members', (tester) async {
      when(() => _bloc.state).thenReturn(const FellowshipMembersState(
        status: FellowshipMembersStatus.failure,
        errorMessage: 'Offline',
      ));
      await _pump(tester);
      expect(find.text('Members'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      verify(() => _bloc.add(
          const FellowshipMembersLoadRequested(fellowshipId: 'f1'))).called(1);
    });
  });
}
