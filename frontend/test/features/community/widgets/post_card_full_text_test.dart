import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';

import '../../../helpers/welcome_test_harness.dart';

const _first = 'Romans 12:2 has been on my mind for the last few days.';
const _second = 'I keep asking what it means to be transformed by the '
    'renewing of my mind, not just in church but at work.';
const _third = 'Would love to hear how you all practise this. @Discipler, '
    'where should I start?';
const _multiParagraph = '$_first\n\n$_second\n\n$_third';

/// Two short paragraphs: fits unclamped even in the wide test font at 360.
const _short = 'Praying for you all.\n\n@Discipler thank you!';

FellowshipPostEntity _post(String content, {String id = 'p'}) =>
    FellowshipPostEntity(
      id: id,
      fellowshipId: 'f1',
      authorUserId: 'u-anna',
      content: content,
      postType: 'general',
      reactionCounts: const {},
      isDeleted: false,
      createdAt: DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      authorDisplayName: 'Anna George',
      commentCount: 0,
    );

/// The content paragraph of the card (Text.rich keyed `post_content`).
String _shownText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('post_content')))
    .textSpan!
    .toPlainText();

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    FellowshipPostEntity post, {
    bool dark = false,
    AppLanguage language = AppLanguage.english,
    double width = 390,
    int? maxLines = FellowshipPostCard.feedMaxContentLines,
    VoidCallback? onPostTap,
  }) async {
    translations.language = language;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FellowshipPostCard(
              post: post,
              fellowshipId: 'f1',
              maxContentLines: maxLines,
              onCommentTap: () {},
              onShareTap: () {},
              onPostTap: onPostTap ?? () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('Feed post text', () {
    testWidgets('a multi-paragraph post shows every paragraph in the feed',
        (tester) async {
      // The test font draws every glyph a full em wide, so give the card the
      // room real Inter text would have on a phone.
      await pump(tester, _post(_multiParagraph), width: 700);
      expect(_shownText(tester), _multiParagraph);
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
          of: find.byKey(const Key('post_content')),
          matching: find.byType(RichText)));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(find.byKey(const Key('post_read_more')), findsNothing);
    });

    testWidgets('mentions are styled in the accent colour', (tester) async {
      await pump(tester, _post(_multiParagraph));
      final spans = tester
          .widget<Text>(find.byKey(const Key('post_content')))
          .textSpan! as TextSpan;
      final mention = spans.children!
          .cast<TextSpan>()
          .singleWhere((s) => s.text!.startsWith('@'));
      // The sentence's comma stays out of the mention.
      expect(mention.text, '@Discipler');
      final context = tester.element(find.byKey(const Key('post_content')));
      expect(mention.style!.color, ReaderPalette.of(context).accentIcon);
      expect(mention.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('a very long post clamps with a visible "Read more"',
        (tester) async {
      var opened = 0;
      final long = List.filled(10, _multiParagraph).join('\n\n');
      await pump(tester, _post(long), onPostTap: () => opened++);
      final text = tester.widget<Text>(find.byKey(const Key('post_content')));
      expect(text.maxLines, FellowshipPostCard.feedMaxContentLines);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.text('Read more'), findsOneWidget);
      final button = tester.getSize(find.byKey(const Key('post_read_more')));
      expect(button.height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Read more'));
      expect(opened, 1);
    });

    testWidgets('the post page (no clamp) shows a long post in full',
        (tester) async {
      final long = List.filled(10, _multiParagraph).join('\n\n');
      await pump(tester, _post(long), maxLines: null);
      expect(_shownText(tester), long);
      expect(find.byKey(const Key('post_read_more')), findsNothing);
    });

    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('${language.code} $theme: fits 360 wide without overflow',
            (tester) async {
          final long = List.filled(6, _multiParagraph).join('\n\n');
          await pump(tester, _post(_short),
              dark: dark, language: language, width: 360);
          expect(tester.takeException(), isNull);
          expect(_shownText(tester), _short);
          expect(find.byKey(const Key('post_read_more')), findsNothing);

          await pump(tester, _post(long, id: 'long'),
              dark: dark, language: language, width: 360);
          expect(tester.takeException(), isNull);
          final readMore = AppLocalizations(Locale(language.code)).feedReadMore;
          expect(find.text(readMore), findsOneWidget);
          final label = tester.renderObject<RenderParagraph>(find.descendant(
              of: find.byKey(const Key('post_read_more')),
              matching: find.byType(RichText)));
          expect(label.didExceedMaxLines, isFalse);
        });
      }
    }
  });
}
