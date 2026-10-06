import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/daily_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_comments_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';

import '../../../helpers/welcome_test_harness.dart';

class _MockFeedBloc extends MockBloc<FellowshipFeedEvent, FellowshipFeedState>
    implements FellowshipFeedBloc {}

const _paragraph = 'Romans 12:2 has been on my mind. @Jane.Doe, what does '
    'being transformed by the renewing of the mind look like at work?';

/// Long enough that the feed card clamps it behind "Read more".
final _longContent = List.filled(12, _paragraph).join('\n\n');

FellowshipPostEntity _post({
  String author = 'u-anna',
  String content = _paragraph,
  String type = 'general',
}) =>
    FellowshipPostEntity(
      id: 'p1',
      fellowshipId: 'f1',
      authorUserId: author,
      content: content,
      postType: type,
      reactionCounts: const {},
      isDeleted: false,
      createdAt: '2026-03-21T10:00:00Z',
      authorDisplayName: 'Anna George',
      commentCount: 0,
    );

const _comments = [
  FellowshipCommentEntity(
    id: 'c1',
    postId: 'p1',
    authorUserId: 'u-joel',
    content: 'Praying with you, @Anna.George. The Lord is near.',
    isDeleted: false,
    createdAt: '2026-03-21T11:00:00Z',
    authorDisplayName: 'Joel Mathew',
  ),
  FellowshipCommentEntity(
    id: 'c2',
    postId: 'p1',
    authorUserId: kDisciplerUserId,
    content: 'Do **not** be anxious about *anything*. — Philippians 4:6',
    isDeleted: false,
    createdAt: '2026-03-21T11:10:00Z',
    authorDisplayName: 'Discipler',
  ),
];

void main() {
  late FakeTranslationService translations;
  late List<String> clipboard;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    clipboard = [];
  });

  tearDown(() async => sl.reset());

  void captureClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.english,
    FellowshipFeedBloc? bloc,
  }) async {
    translations.language = language;
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    captureClipboard(tester);
    final feed = bloc ?? _MockFeedBloc();
    if (bloc == null) {
      when(() => feed.state).thenReturn(const FellowshipFeedState());
    }
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<FellowshipFeedBloc>.value(
        value: feed,
        child: Scaffold(body: child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget feedCard(FellowshipPostEntity post, {String? currentUserId}) =>
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FellowshipPostCard(
            post: post,
            fellowshipId: 'f1',
            currentUserId: currentUserId,
            maxContentLines: FellowshipPostCard.feedMaxContentLines,
            onCommentTap: () {},
            onShareTap: () {},
            onPostTap: () {},
          ),
        ],
      );

  group('postCopyText', () {
    test('is the whole post, mentions as typed', () {
      expect(postCopyText(_post(content: _longContent)), _longContent);
      expect(postCopyText(_post()), contains('@Jane.Doe'));
    });

    test('drops markdown emphasis from Discipler posts only', () {
      expect(
          postCopyText(
              _post(author: kDisciplerUserId, content: 'Be **still**.')),
          'Be still.');
      expect(postCopyText(_post(content: 'Be **still**.')), 'Be **still**.');
    });

    test('daily posts copy title, hook and verse without marker emoji', () {
      const daily = '📖 Who is Jesus?\n✨ A question that changes everything.'
          '\n✝️ Matthew 16:15-16\n💬 Who do you say He is?';
      expect(
          postCopyText(
              _post(author: kDisciplerUserId, type: 'daily', content: daily)),
          'Who is Jesus?\nA question that changes everything.\n'
          'Matthew 16:15-16');
      expect(dailyPostPlainText(daily), contains('Who is Jesus?'));
    });

    test('every viewer gets copy, own post or not', () {
      for (final viewer in ['u-anna', 'u-other']) {
        expect(
            postMenuItems(_post(),
                isMentor: false, isAdmin: false, currentUserId: viewer),
            contains('copy'));
      }
      expect(
          postMenuItems(_post(author: kDisciplerUserId),
              isMentor: false, isAdmin: false, currentUserId: 'u'),
          ['share', 'copy']);
    });
  });

  group('post menu', () {
    for (final viewer in ['u-anna', 'u-other']) {
      testWidgets('Copy text copies the full (unclamped) post — viewer $viewer',
          (tester) async {
        await pump(tester,
            feedCard(_post(content: _longContent), currentUserId: viewer));
        expect(find.text('Read more'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy text'));
        await tester.pumpAndSettle();

        expect(clipboard, [_longContent]);
        expect(find.text('Copied to clipboard'), findsOneWidget);
      });
    }

    testWidgets('long-press on the post opens the same menu', (tester) async {
      await pump(tester, feedCard(_post()));
      await tester.longPress(find.byKey(const Key('post_content')));
      await tester.pumpAndSettle();
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Share Post'), findsOneWidget);
    });

    testWidgets('post page text is selectable; feed text is not',
        (tester) async {
      await pump(
        tester,
        ListView(children: [
          FellowshipPostCard(post: _post(), fellowshipId: 'f1'),
        ]),
      );
      expect(find.byType(SelectionArea), findsOneWidget);

      await pump(tester, feedCard(_post()));
      expect(find.byType(SelectionArea), findsNothing);
    });

    for (final (lang, label) in [
      (AppLanguage.hindi, 'टेक्स्ट कॉपी करें'),
      (AppLanguage.malayalam, 'ടെക്സ്റ്റ് കോപ്പി ചെയ്യുക'),
    ]) {
      testWidgets('label in ${lang.code}', (tester) async {
        await pump(tester, feedCard(_post()), language: lang);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('daily post: any member can copy its text', (tester) async {
      const daily = '📖 Who is Jesus?\n✨ A question that changes everything.';
      await pump(
        tester,
        ListView(children: [
          DailyPostCard(
            post:
                _post(author: kDisciplerUserId, type: 'daily', content: daily),
            fellowshipId: 'f1',
            onCommentTap: () {},
            onShareTap: () {},
          ),
        ]),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // Not a mentor: copy only, no manage actions.
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();
      expect(clipboard, ['Who is Jesus?\nA question that changes everything.']);
    });
  });

  group('reply menu', () {
    late _MockFeedBloc bloc;

    setUp(() {
      bloc = _MockFeedBloc();
      when(() => bloc.state).thenReturn(const FellowshipFeedState(
        comments: _comments,
        commentsStatus: FellowshipCommentsStatus.success,
        currentUserId: 'u-joel',
      ));
    });

    Widget body() => const FellowshipCommentsBody(
          postId: 'p1',
          fellowshipId: 'f1',
          isMentor: false,
          currentUserId: 'u-joel',
        );

    testWidgets('own and others\' replies both offer Copy text',
        (tester) async {
      await pump(tester, body(), bloc: bloc);
      // Joel's own reply and the Discipler's reply each have a menu.
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.more_vert).at(i));
        await tester.pumpAndSettle();
        expect(find.text('Copy text'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('copies a member reply with its mention', (tester) async {
      await pump(tester, body(), bloc: bloc);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();
      expect(clipboard, ['Praying with you, @Anna.George. The Lord is near.']);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('long-press copies a Discipler reply without markdown',
        (tester) async {
      await pump(tester, body(), bloc: bloc);
      await tester.longPress(find.textContaining('Philippians 4:6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();
      expect(
          clipboard, ['Do not be anxious about anything. — Philippians 4:6']);
    });
  });
}
