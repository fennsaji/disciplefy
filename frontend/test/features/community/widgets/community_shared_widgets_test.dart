import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/current_study_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/daily_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';

import '../../../helpers/welcome_test_harness.dart';
import '../../settings/text_fit.dart';

const _prayer = FellowshipPostEntity(
  id: 'p1',
  fellowshipId: 'f',
  authorUserId: 'u-priya',
  content:
      "Please pray for my mother's surgery on Thursday. Trusting God for peace for our family.",
  postType: 'prayer',
  reactionCounts: {'i_prayed': 4},
  isDeleted: false,
  createdAt: '2026-03-21T10:00:00Z',
  authorDisplayName: 'Priya Thomas',
  commentCount: 3,
);

const _daily = FellowshipPostEntity(
  id: 'd1',
  fellowshipId: 'f',
  authorUserId: kDisciplerUserId,
  content: '📖 Who is Jesus Christ?\n\n'
      '✨ Jesus asked His disciples, "Who do you say that I am?"\n\n'
      "Today we look at Peter's answer.\n\n"
      '✝️ Matthew 16:15-16',
  postType: 'daily',
  reactionCounts: {'fire': 6},
  isDeleted: false,
  createdAt: '2026-03-21T06:00:00Z',
  authorDisplayName: 'Discipler',
  commentCount: 2,
  guideTitle: 'New Believer Essentials',
  lessonIndex: 1,
  topicTitle: 'Who is Jesus Christ?',
);

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });
  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool dark = true,
    AppLanguage language = AppLanguage.english,
    Size size = const Size(320, 640),
  }) async {
    translations.language = language;
    useSurface(tester, size);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('post cards fit 320 wide', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          await pump(
            tester,
            Column(children: [
              FellowshipPostCard(
                post: _daily,
                fellowshipId: 'f',
                isMentor: true,
                onCommentTap: () {},
                onShareTap: () {},
              ),
              const SizedBox(height: 12),
              FellowshipPostCard(
                post: _prayer,
                fellowshipId: 'f',
                onCommentTap: () {},
                onShareTap: () {},
              ),
            ]),
            dark: dark,
            language: language,
            size: const Size(320, 1400),
          );
          expectNoTruncatedText(tester, allowed: {'Priya Thomas'});
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('member post: avatar initials, type chip, replies and reaction',
      (tester) async {
    await pump(
      tester,
      FellowshipPostCard(
        post: _prayer,
        fellowshipId: 'f',
        onCommentTap: () {},
        onShareTap: () {},
      ),
      size: const Size(390, 800),
    );

    expect(find.text('PT'), findsOneWidget);
    expect(find.text('Prayer'), findsOneWidget);
    expect(find.text('3 replies'), findsOneWidget);
    expect(find.text('I prayed 4'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('comment and share taps reach their callbacks', (tester) async {
    var comments = 0;
    var shares = 0;
    await pump(
      tester,
      FellowshipPostCard(
        post: _prayer,
        fellowshipId: 'f',
        onCommentTap: () => comments++,
        onShareTap: () => shares++,
      ),
      size: const Size(390, 800),
    );

    await tester.tap(find.text('3 replies'));
    await tester.tap(find.byIcon(Icons.share_outlined));
    expect(comments, 1);
    expect(shares, 1);
  });

  testWidgets('daily post: eyebrow, title, hook, verse chip and Start study',
      (tester) async {
    await pump(
      tester,
      FellowshipPostCard(
        post: _daily,
        fellowshipId: 'f',
        onCommentTap: () {},
        onShareTap: () {},
      ),
      size: const Size(390, 1000),
    );

    expect(find.text('NEW BELIEVER ESSENTIALS · LESSON 1'), findsOneWidget);
    expect(find.text('Who is Jesus Christ?'), findsOneWidget);
    expect(find.text('Daily study'), findsOneWidget);
    expect(find.text('Start study'), findsOneWidget);
    expect(find.text('Matthew 16:15-16'), findsOneWidget);
    // Narrow card: replies collapse to icon + count, full label in tooltip.
    expect(find.byTooltip('2 replies'), findsOneWidget);
    // Everyone gets the menu for Copy text; Edit/Delete stay with
    // mentors and admins.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('a daily post without path data shows no eyebrow',
      (tester) async {
    const bare = FellowshipPostEntity(
      id: 'd2',
      fellowshipId: 'f',
      authorUserId: kDisciplerUserId,
      content: '📖 Grace',
      postType: 'daily',
      reactionCounts: {},
      isDeleted: false,
      createdAt: '2026-03-21T06:00:00Z',
      authorDisplayName: 'Discipler',
      commentCount: 0,
    );
    await pump(tester, const DailyPostCard(post: bare, fellowshipId: 'f'),
        size: const Size(390, 800));

    expect(find.byType(CommunitySectionLabel), findsNothing);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Reply'), findsNothing,
        reason: 'no reply callback, no replies button');
  });

  testWidgets('scripture chip is tappable only for a recognised reference',
      (tester) async {
    await pump(
      tester,
      const Column(children: [
        ScriptureReferenceChip(reference: 'John 3:16'),
        ScriptureReferenceChip(reference: 'Not a verse'),
      ]),
    );

    final wells = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
    expect(wells[0].onTap, isNotNull);
    expect(wells[1].onTap, isNull);
  });

  group('fellowship card parts', () {
    const study = CurrentStudyEntity(
      learningPathId: 'p',
      learningPathTitle: 'The Gospel of Matthew',
      currentGuideIndex: 2,
      startedAt: '2026-01-01',
      totalGuides: 29,
    );

    testWidgets('mentor line: you, singular member, Discipler, unknown',
        (tester) async {
      const mine = FellowshipEntity(
        id: 'f',
        name: 'Group',
        memberCount: 1,
        userRole: 'mentor',
        joinedAt: '',
        createdAt: '',
        mentors: [FellowshipMentorEntity(userId: 'me', displayName: 'Fenn')],
      );
      const official = FellowshipEntity(
        id: 'o',
        name: 'Disciplefy',
        memberCount: 3,
        userRole: 'member',
        joinedAt: '',
        createdAt: '',
        isOfficial: true,
      );
      const unknown = FellowshipEntity(
        id: 'u',
        name: 'Group',
        memberCount: 5,
        userRole: 'member',
        joinedAt: '',
        createdAt: '',
      );
      await pump(
        tester,
        Column(children: [
          FellowshipMentorRow(
            mentor:
                FellowshipMentorInfo.forFellowship(mine, currentUserId: 'me'),
            memberCount: 1,
          ),
          FellowshipMentorRow(
            mentor: FellowshipMentorInfo.forFellowship(mine,
                currentUserId: 'someone-else'),
            memberCount: 1,
          ),
          FellowshipMentorRow(
            mentor: FellowshipMentorInfo.forFellowship(official),
            memberCount: 3,
          ),
          FellowshipMentorRow(
            mentor: FellowshipMentorInfo.forFellowship(unknown),
            memberCount: 5,
          ),
        ]),
      );

      expect(find.text('Mentor: Fenn (you) · 1 member'), findsOneWidget);
      expect(find.text('Mentor: Fenn · 1 member'), findsOneWidget);
      expect(find.text('Guided by Discipler · 3 members'), findsOneWidget);
      expect(find.text('5 members'), findsOneWidget);
    });

    testWidgets('current study: lesson, n of m and progress', (tester) async {
      await pump(tester, const FellowshipCurrentStudyRow(study: study));

      expect(find.text('The Gospel of Matthew · Lesson 3'), findsOneWidget);
      // Lessons done: the ones before the group's current lesson.
      expect(find.text('2 of 29 done'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(2 / 29, 1e-9));
    });

    testWidgets('a finished study names the path and fills the bar',
        (tester) async {
      await pump(
        tester,
        const FellowshipCurrentStudyRow(
          study: CurrentStudyEntity(
            learningPathId: 'p',
            learningPathTitle: 'The Gospel of Matthew',
            currentGuideIndex: 28,
            startedAt: '2026-01-01',
            completedAt: '2026-02-01',
            totalGuides: 29,
          ),
        ),
      );
      expect(find.text('The Gospel of Matthew'), findsOneWidget);
      expect(find.text('29 of 29 done'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 1.0);
    });

    testWidgets('current study without a total hides count and bar',
        (tester) async {
      await pump(
        tester,
        const FellowshipCurrentStudyRow(
          study: CurrentStudyEntity(
            learningPathId: 'p',
            currentGuideIndex: 0,
            startedAt: '',
          ),
        ),
      );

      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('card fits 320 in ${language.code}', (tester) async {
        await pump(
          tester,
          const FellowshipCardShell(
            child: Column(children: [
              FellowshipCardTitle(
                  name: 'Daily Post Test Group', isOfficial: true),
              FellowshipCurrentStudyRow(study: study),
            ]),
          ),
          language: language,
          dark: language != AppLanguage.hindi,
        );
        expectNoTruncatedText(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('photo wash decodes the photo tiny, with no blur filter',
      (tester) async {
    await pump(
      tester,
      const SizedBox(
        height: 500,
        child: PhotoWash(
          image: PhotoWash.communityTabImage,
          child: Text('content'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 8);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('underline tabs and CTA pill report taps', (tester) async {
    int? tab;
    var pressed = 0;
    await pump(
      tester,
      Column(children: [
        CommunityUnderlineTabs(
          labels: const ['My fellowships', 'Discover'],
          selected: 0,
          onChanged: (i) => tab = i,
        ),
        CommunityCtaPill(label: 'Join', onPressed: () => pressed++),
      ]),
    );

    await tester.tap(find.text('Discover'));
    await tester.tap(find.text('Join'));
    expect(tab, 1);
    expect(pressed, 1);
  });

  testWidgets('a loading CTA pill ignores taps', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityCtaPill(
            label: 'Busy', loading: true, onPressed: () => pressed++),
      ),
    ));
    await tester.tap(find.text('Busy'));
    expect(pressed, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('card pills are 32px with a 40px tap area; large pills are 40px',
      (tester) async {
    var pressed = 0;
    await pump(
      tester,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CommunityCtaPill(
            key: const Key('small'), label: 'Join', onPressed: () => pressed++),
        CommunityCtaPill(
            key: const Key('large'),
            large: true,
            label: 'Join a fellowship',
            onPressed: () {}),
        CommunityRaisedPill(
            key: const Key('chip'), label: 'Hindi', onPressed: () {}),
      ]),
    );
    final small = find.byKey(const Key('small'));
    expect(tester.getSize(small).height, 40);
    expect(
        tester
            .getSize(
                find.descendant(of: small, matching: find.byType(Material)))
            .height,
        32);
    expect(tester.getSize(find.byKey(const Key('large'))).height, 40);
    expect(tester.getSize(find.byKey(const Key('chip'))).height, 40);
    // The 4px above the visible pill still presses it.
    final top = tester.getTopLeft(small);
    await tester.tapAt(top + const Offset(20, 1));
    expect(pressed, 1);
  });
}
