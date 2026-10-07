import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_event.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_state.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/widgets/chat_bubble.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/widgets/chat_input.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/widgets/follow_up_chat_widget.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

class _SeenWalkthroughs extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

class _FakeSpeechService extends Fake implements SpeechService {}

class _MockChatBloc extends MockBloc<FollowUpChatEvent, FollowUpChatState>
    implements FollowUpChatBloc {}

const _question = 'How do I forgive someone who isn\'t sorry?';
const _answer = 'Forgiveness doesn\'t wait for an apology.';
const _suggestion = 'Explain this passage in simple words';

FollowUpChatLoaded _loaded({List<ChatMessage> messages = const []}) =>
    FollowUpChatLoaded(
      studyGuideId: 'g1',
      studyGuideTitle: 'Forgiveness',
      conversationId: 'c1',
      messages: messages,
    );

final _conversation = [
  ChatMessage(
      id: 'u1', content: _question, isUser: true, timestamp: DateTime.now()),
  ChatMessage(
      id: 'a1', content: _answer, isUser: false, timestamp: DateTime.now()),
];

void main() {
  late _MockChatBloc bloc;

  setUpAll(() => registerFallbackValue(const CancelRequestEvent()));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance
      ..registerSingleton<TranslationService>(
          TranslationService(_FakeLanguageService(), prefs))
      ..registerSingleton<WalkthroughRepository>(_SeenWalkthroughs())
      ..registerSingleton<SpeechService>(_FakeSpeechService());
    bloc = _MockChatBloc();
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pumpChat(
    WidgetTester tester, {
    required bool dark,
    required FollowUpChatState state,
    bool expanded = true,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    whenListen(bloc, const Stream<FollowUpChatState>.empty(),
        initialState: state);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BlocProvider<FollowUpChatBloc>.value(
            value: bloc,
            child: FollowUpChatWidget(
              studyGuideId: 'g1',
              studyGuideTitle: 'Forgiveness',
              isExpanded: expanded,
              sectionNumber: 8,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: numbered header, credit caption and conversation',
        (tester) async {
      await pumpChat(tester,
          dark: dark, state: _loaded(messages: _conversation));

      expect(tester.takeException(), isNull);
      expect(find.text('08'), findsOneWidget);
      expect(find.text('Follow-up Questions'), findsOneWidget);
      expect(
          find.text('Each follow-up question uses 5 credits'), findsOneWidget);
      expect(find.byType(ChatBubble), findsNWidgets(2));
      expect(find.byType(ChatInput), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('$theme: user pill is white on dark, indigo on light',
        (tester) async {
      await pumpChat(tester,
          dark: dark, state: _loaded(messages: _conversation));

      final userBubble = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(ChatBubble).first,
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(userBubble.color, dark ? Colors.white : ReaderPalette.ink);
    });
  }

  testWidgets('ask-Discipler suggestions fill the input on tap',
      (tester) async {
    await pumpChat(tester, dark: true, state: _loaded(messages: _conversation));

    // Suggestions are questions the reader asks Discipler.
    expect(find.text(_suggestion), findsOneWidget);
    expect(find.text('How can I apply this to my life?'), findsOneWidget);
    await tester.tap(find.text(_suggestion));
    await tester.pump();

    final field = tester.widget<TextField>(find.descendant(
        of: find.byType(ChatInput), matching: find.byType(TextField)));
    expect(field.controller!.text, _suggestion);
    // Filling the input sends nothing.
    final added = verify(() => bloc.add(captureAny())).captured;
    expect(added.whereType<SendQuestionEvent>(), isEmpty);
  });

  testWidgets('empty conversation shows the prompt and the input',
      (tester) async {
    await pumpChat(tester, dark: false, state: _loaded());
    expect(tester.takeException(), isNull);
    expect(
        find.text(
            "Ask me anything about this study. I'll answer from Scripture."),
        findsOneWidget);
    expect(find.byType(ChatInput), findsOneWidget);
  });

  testWidgets('insufficient-credit state still renders its actions',
      (tester) async {
    await pumpChat(tester,
        dark: true,
        state: const FollowUpChatInsufficientTokens(
          required: 5,
          available: 0,
          userPlan: 'free',
        ));
    expect(tester.takeException(), isNull);
    expect(find.text('No Credits Left'), findsOneWidget);
    expect(find.text('Get More Credits'), findsOneWidget);
  });

  testWidgets('collapsed shows only the header', (tester) async {
    await pumpChat(tester,
        dark: true, state: _loaded(messages: _conversation), expanded: false);
    expect(find.text('Follow-up Questions'), findsOneWidget);
    // SizeTransition at 0 keeps the content in the tree but zero-height.
    final input = tester.getSize(find.byType(ChatInput));
    expect(input.height, greaterThan(0)); // laid out, clipped by the parent
    expect(tester.getSize(find.byType(SizeTransition)).height, 0);
  });
}
