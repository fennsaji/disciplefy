import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_state.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/widgets/chat_bubble.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/guide_share_prompts.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/learning_path_detail_page.dart';
import 'package:disciplefy_bible_study/shared/widgets/clickable_scripture_text.dart';
import 'package:disciplefy_bible_study/shared/widgets/markdown_with_scripture.dart';

import '../../helpers/text_fit.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  _FakeLanguageService(this.language);
  final AppLanguage language;

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => language;
}

Future<void> _register(AppLanguage language) async {
  SharedPreferences.setMockInitialValues(
      {'user_language_preference': language.code});
  final prefs = await SharedPreferences.getInstance();
  await GetIt.instance.reset();
  final languageService = _FakeLanguageService(language);
  GetIt.instance
    ..registerSingleton<TranslationService>(
        TranslationService(languageService, prefs))
    ..registerSingleton<LanguagePreferenceService>(languageService);
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app({required bool dark, required Widget home}) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );

/// Opens [sheet] the way the app does: a transparent root modal sheet.
Future<void> _openSheet(
  WidgetTester tester, {
  required bool dark,
  required WidgetBuilder sheet,
}) async {
  await tester.pumpWidget(_app(
    dark: dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: sheet,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

LearningPathTopic _topic(int i) => LearningPathTopic(
      position: i,
      isMilestone: false,
      topicId: 't$i',
      title: 'Topic $i',
      description: 'About topic $i',
      category: 'Faith',
      xpValue: 10,
    );

ReaderPalette _paletteOf(WidgetTester tester, Finder finder) =>
    ReaderPalette.of(tester.element(finder));

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => GetIt.instance.reset());

  final combos = [
    for (final language in AppLanguage.values)
      for (final dark in [true, false]) (language, dark),
  ];

  group('screenshot share sheet', () {
    for (final (language, dark) in combos) {
      testWidgets(
          'fits 320x640 ${language.code} ${dark ? 'dark' : 'light'} '
          'and sits on the card fill', (tester) async {
        await _register(language);
        _usePhone(tester);
        await _openSheet(
          tester,
          dark: dark,
          sheet: (_) => ScreenshotShareSheet(
            onShareText: () {},
            onShareFellowship: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        final palette = _paletteOf(tester, find.byType(ScreenshotShareSheet));
        final card = tester.widget<Container>(find
            .descendant(
              of: find.byType(ScreenshotShareSheet),
              matching: find.byType(Container),
            )
            .first);
        expect((card.decoration! as BoxDecoration).color, palette.card);
      });
    }

    testWidgets('share, share to fellowship and not now keep their actions',
        (tester) async {
      await _register(AppLanguage.english);
      _usePhone(tester);
      var shared = 0;
      var fellowship = 0;
      await _openSheet(
        tester,
        dark: true,
        sheet: (ctx) => ScreenshotShareSheet(
          onShareText: () => shared++,
          onShareFellowship: () => fellowship++,
        ),
      );

      await tester.tap(find.text('Share'));
      await tester.tap(find.text('Share to Fellowship'));
      expect(shared, 1);
      expect(fellowship, 1);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(ScreenshotShareSheet), findsNothing);
    });

    testWidgets('hides share to fellowship without fellowships',
        (tester) async {
      await _register(AppLanguage.english);
      _usePhone(tester);
      await _openSheet(
        tester,
        dark: false,
        sheet: (_) => ScreenshotShareSheet(onShareText: () {}),
      );
      expect(find.text('Share to Fellowship'), findsNothing);
    });
  });

  group('generation interrupted banner', () {
    for (final (language, dark) in combos) {
      testWidgets('fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
          (tester) async {
        await _register(language);
        _usePhone(tester);
        await tester.pumpWidget(_app(
          dark: dark,
          home: Scaffold(
            body: GenerationInterruptedBanner(onRetry: () {}),
          ),
        ));
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('retry calls back; no retry pill when it cannot retry',
        (tester) async {
      await _register(AppLanguage.english);
      var retried = 0;
      await tester.pumpWidget(_app(
        dark: true,
        home: Scaffold(
          body: GenerationInterruptedBanner(onRetry: () => retried++),
        ),
      ));
      await tester.tap(find.byType(TextButton));
      expect(retried, 1);

      await tester.pumpWidget(_app(
        dark: true,
        home: const Scaffold(body: GenerationInterruptedBanner()),
      ));
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('rendered markdown uses the reader palette', () {
    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets('study guide markdown links, headings, code ($theme)',
          (tester) async {
        await tester.pumpWidget(_app(
          dark: dark,
          home: const Scaffold(
            body: MarkdownWithScripture(
              data: '# Heading\n\nRead John 3:16 and `code`\n\n> quote',
            ),
          ),
        ));
        final palette = _paletteOf(tester, find.byType(MarkdownBody));
        final sheet =
            tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
        expect(sheet.a!.color, palette.accentIcon);
        expect(sheet.listBullet!.color, palette.accentIcon);
        expect(sheet.h1!.color, palette.text);
        expect(sheet.code!.backgroundColor, palette.raised);
        final bar =
            (sheet.blockquoteDecoration! as BoxDecoration).border! as Border;
        expect(bar.left.color, palette.accentIcon);
      });

      testWidgets('clickable scripture references ($theme)', (tester) async {
        await tester.pumpWidget(_app(
          dark: dark,
          home: const Scaffold(
            body: ClickableScriptureText(
              text: 'Read John 3:16 today',
              selectable: false,
            ),
          ),
        ));
        final palette = _paletteOf(tester, find.byType(ClickableScriptureText));
        final spans = <TextSpan>[];
        tester
            .widget<RichText>(find.descendant(
              of: find.byType(ClickableScriptureText),
              matching: find.byType(RichText),
            ))
            .text
            .visitChildren((span) {
          if (span is TextSpan) spans.add(span);
          return true;
        });
        final reference = spans.firstWhere((s) => s.text == 'John 3:16');
        expect(reference.style!.color, palette.accentIcon);
      });

      testWidgets('follow-up chat reply markdown ($theme)', (tester) async {
        await _register(AppLanguage.english);
        await tester.pumpWidget(_app(
          dark: dark,
          home: Scaffold(
            body: ChatBubble(
              message: ChatMessage(
                id: 'm1',
                content: '## Grace\n\nSee [this](https://x.y) and `code`.',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            ),
          ),
        ));
        final palette = _paletteOf(tester, find.byType(ChatBubble));
        final sheet =
            tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
        expect(sheet.a!.color, palette.accentIcon);
        expect(sheet.code!.backgroundColor, palette.raised);
        expect(sheet.h2!.fontFamily, contains('Poppins'));
        expect(sheet.code!.fontFamily, 'monospace');
      });
    }
  });

  group('download topic picker', () {
    for (final (language, dark) in combos) {
      testWidgets('fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
          (tester) async {
        await _register(language);
        _usePhone(tester);
        await _openSheet(
          tester,
          dark: dark,
          sheet: (_) => TopicSelectionSheet(
            topics: [for (var i = 1; i <= 3; i++) _topic(i)],
            initialSelected: const {'t1', 't2', 't3'},
            costPerGuide: 5,
            onConfirm: (_) async {},
          ),
        );
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester, allow: {'Topic '});
      });
    }

    testWidgets('unticking a topic narrows the download to the rest',
        (tester) async {
      await _register(AppLanguage.english);
      _usePhone(tester);
      List<LearningPathTopic>? chosen;
      await _openSheet(
        tester,
        dark: true,
        sheet: (_) => TopicSelectionSheet(
          topics: [for (var i = 1; i <= 3; i++) _topic(i)],
          initialSelected: const {'t1', 't2', 't3'},
          costPerGuide: 5,
          onConfirm: (topics) async => chosen = topics,
        ),
      );

      expect(find.text('5 credits'), findsNWidgets(3));
      await tester.tap(find.text('Topic 2'));
      await tester.pump();
      await tester.tap(find.textContaining('Download 2'));
      await tester.pumpAndSettle();

      expect(chosen!.map((t) => t.topicId), ['t1', 't3']);
      expect(find.byType(TopicSelectionSheet), findsNothing);
    });
  });
}
