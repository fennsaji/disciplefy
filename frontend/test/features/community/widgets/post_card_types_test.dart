import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/share_guide_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/reaction_button.dart';

import '../../../helpers/welcome_test_harness.dart';
import '../../settings/text_fit.dart';

const _languages = [
  AppLanguage.english,
  AppLanguage.hindi,
  AppLanguage.malayalam,
];

FellowshipPostEntity _post(
  String type, {
  String id = 'p',
  String content = 'Please pray for my mother’s surgery on Thursday.',
  Map<String, int> reactions = const {'i_prayed': 4},
  int comments = 3,
  String? guideTitle,
  String? topicTitle,
  String? topicId,
  int? lessonIndex,
  String? studyGuideId,
  String? guideInputType,
  String? guideLanguage,
}) =>
    FellowshipPostEntity(
      id: id,
      fellowshipId: 'f1',
      authorUserId: 'u-anna',
      content: content,
      postType: type,
      reactionCounts: reactions,
      isDeleted: false,
      createdAt: DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      authorDisplayName: 'Anna George',
      commentCount: comments,
      guideTitle: guideTitle,
      topicTitle: topicTitle,
      topicId: topicId,
      lessonIndex: lessonIndex,
      studyGuideId: studyGuideId,
      guideInputType: guideInputType,
      guideLanguage: guideLanguage,
    );

final _sharedGuide = _post(
  'shared_guide',
  id: 'sg',
  content: 'This helped me so much this morning — sharing with you all.',
  reactions: const {'fire': 5},
  comments: 1,
  guideTitle: 'Romans 8:28',
  guideInputType: 'scripture',
  guideLanguage: 'en',
);

final _studyNote = _post(
  'study_note',
  id: 'sn',
  content: 'What struck me: Peter answered before he fully understood.',
  reactions: const {'fire': 3},
  comments: 0,
  topicTitle: 'Who is Jesus Christ?',
  guideTitle: 'New Believer Essentials',
  lessonIndex: 1,
);

List<FellowshipPostEntity> _allPosts() => [
      _sharedGuide,
      _post('prayer', id: 'pr'),
      _post('praise',
          id: 'pa',
          content: 'Praise God — I got the job!',
          reactions: const {'amen': 9},
          comments: 4),
      _post('question',
          id: 'q',
          content: 'How do you keep a daily reading habit?',
          reactions: const {'heart': 2},
          comments: 6),
      _studyNote,
      _post('general',
          id: 'g',
          content: 'Reminder: we meet Sunday at 7 PM.',
          reactions: const {'amen': 6},
          comments: 2),
    ];

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

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
          path: '/study-guide-v2',
          builder: (_, s) => Text('stub:guide:${s.uri.query}'),
        ),
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

  Widget feed(List<FellowshipPostEntity> posts) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FellowshipPostCard(
                  post: p,
                  fellowshipId: 'f1',
                  onCommentTap: () {},
                  onShareTap: () {},
                ),
              ),
          ],
        ),
      );

  group('Post card types', () {
    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';

      testWidgets('$theme: each type shows its chip and footer',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        for (final post in _allPosts()) {
          await tester.pumpWidget(app(feed([post]), dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final chip = find.byType(PostTypeChip);
          if (post.postType == 'general') {
            expect(find.descendant(of: chip, matching: find.byType(Text)),
                findsNothing,
                reason: 'general posts have no type chip');
          } else {
            expect(chip, findsOneWidget);
          }
          expect(find.byType(FellowshipReactionButton), findsOneWidget);
          expect(find.byIcon(Icons.share_outlined), findsOneWidget);
          expect(
              find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
        }
      });

      testWidgets('$theme: chip labels, reaction labels and replies',
          (tester) async {
        useSurface(tester, const Size(390, 2400));
        await tester.pumpWidget(app(feed(_allPosts()), dark: dark));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final label in [
          'Study guide',
          'Prayer',
          'Praise',
          'Question',
          'Study Note',
        ]) {
          expect(
              find.descendant(
                  of: find.byType(PostTypeChip), matching: find.text(label)),
              findsOneWidget,
              reason: 'chip "$label"');
        }
        expect(find.text('Shared Guide'), findsNothing);

        expect(find.text('I prayed 4'), findsOneWidget);
        expect(find.text('Praise 9'), findsOneWidget);
        expect(find.text('Love 2'), findsOneWidget);
        expect(find.text('1 reply'), findsOneWidget);
        expect(find.text('3 replies'), findsOneWidget);
        expect(find.text('Reply'), findsOneWidget);
      });

      testWidgets('$theme: chip colours differ per type', (tester) async {
        useSurface(tester, const Size(390, 2400));
        await tester.pumpWidget(app(feed(_allPosts()), dark: dark));
        await tester.pumpAndSettle();
        final colours = <Color?>{};
        for (final element in find
            .descendant(
                of: find.byType(PostTypeChip), matching: find.byType(Icon))
            .evaluate()) {
          colours.add((element.widget as Icon).color);
        }
        expect(colours.length, 5);
      });
    }
  });

  group('Shared guide card', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: tracked label, title, link',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(feed([_sharedGuide]), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('SCRIPTURE · ENGLISH'), findsOneWidget);
        expect(find.text('Romans 8:28'), findsOneWidget);
        expect(find.text('Open study guide'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
        expect(
            find.text('This helped me so much this morning — sharing with '
                'you all.'),
            findsOneWidget);
      });
    }

    testWidgets('tapping the inner card opens the guide', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(feed([_sharedGuide]), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shared-guide-card')));
      await tester.pumpAndSettle();

      expect(
        find.text('stub:guide:input=Romans%208%3A28&type=scripture'
            '&language=en&source=fellowship_feed'),
        findsOneWidget,
      );
    });
  });

  group('Study note chip', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: shows the lesson it is on',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(feed([_studyNote]), dark: dark));
        await tester.pumpAndSettle();

        expect(
          find.text(
              'On: Who is Jesus Christ? · Lesson 1 · New Believer Essentials',
              findRichText: true),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('study-note-chip')), findsOneWidget);
      });
    }

    testWidgets('without a topic id the chip is not tappable', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(feed([_studyNote]), dark: true));
      await tester.pumpAndSettle();
      final ink =
          tester.widget<InkWell>(find.byKey(const ValueKey('study-note-chip')));
      expect(ink.onTap, isNull);
    });

    testWidgets('with a topic id the chip is tappable', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(
          feed([
            _post('study_note',
                topicId: 't1', topicTitle: 'Who is Jesus Christ?'),
          ]),
          dark: true));
      await tester.pumpAndSettle();
      final ink =
          tester.widget<InkWell>(find.byKey(const ValueKey('study-note-chip')));
      expect(ink.onTap, isNotNull);
    });
  });

  group('320pt feed', () {
    for (final language in _languages) {
      for (final dark in [true, false]) {
        testWidgets(
            '${language.code} ${dark ? 'dark' : 'light'}: no overflow or '
            'truncation', (tester) async {
          useSurface(tester, const Size(320, 640));
          await tester.pumpWidget(
              app(feed(_allPosts()), dark: dark, language: language));
          await tester.pumpAndSettle();
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            expect(tester.takeException(), isNull);
            // The author name is user content and may ellipsize by design.
            expectNoTruncatedText(tester, allowed: {'Anna George'});
            await tester.drag(scrollable, const Offset(0, -400));
            await tester.pumpAndSettle();
          }
        });
      }
    }
  });

  group('Share guide sheet rows', () {
    final fellowships = [
      const FellowshipEntity(
        id: 'f1',
        name: 'Disciplefy',
        memberCount: 4,
        userRole: 'member',
        joinedAt: '2026-01-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
        isOfficial: true,
      ),
      const FellowshipEntity(
        id: 'f2',
        name: 'Daily Post Test Group',
        memberCount: 1,
        userRole: 'mentor',
        joinedAt: '2026-01-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
        mentors: [FellowshipMentorEntity(userId: 'u-1', displayName: 'Fenn')],
      ),
      const FellowshipEntity(
        id: 'f3',
        name: 'Morning Word',
        memberCount: 7,
        userRole: 'member',
        joinedAt: '2026-01-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
        mentorName: 'Mentor',
      ),
    ];

    Widget sheet() {
      final auth = MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: AuthenticatedState(
          user: User(
            id: 'u-1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ),
        ),
      );
      return BlocProvider<AuthBloc>.value(
        value: auth,
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ShareGuideSheet(
              studyGuideId: 'g1',
              guideTitle: 'Romans 8:28',
              guideInputType: 'scripture',
              guideLanguage: 'en',
              fellowships: fellowships,
            ),
          ),
        ),
      );
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: mentor avatars, lines, checks',
          (tester) async {
        useSurface(tester, const Size(390, 1000));
        await tester.pumpWidget(app(sheet(), dark: dark));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Share guide'), findsOneWidget);
        expect(find.text('Verse study · English'), findsOneWidget);
        expect(find.text('SHARE TO FELLOWSHIP'), findsOneWidget);
        expect(find.text('Mentor: Discipler · 4 members'), findsOneWidget);
        expect(find.text('Mentor: Fenn (you) · 1 member'), findsOneWidget);
        // Placeholder mentor name → member count only.
        expect(find.text('7 members'), findsOneWidget);
        expect(find.byType(DisciplerAvatar), findsOneWidget);
        expect(find.byType(MemberAvatar), findsNWidgets(2));

        expect(find.text('Select a fellowship'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        await tester.tap(find.text('Disciplefy'));
        await tester.tap(find.text('Morning Word'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
        expect(find.text('Share to 2 fellowships'), findsOneWidget);
        expect(find.byIcon(Icons.send_outlined), findsOneWidget);

        await tester.tap(find.text('Morning Word'));
        await tester.pumpAndSettle();
        expect(find.text('Share to 1 fellowship'), findsOneWidget);
      });
    }

    for (final language in _languages) {
      testWidgets('320pt ${language.code}: no overflow or truncation',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(sheet(),
            dark: language != AppLanguage.hindi, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  });
}
