import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_event.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_state.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/widgets/follow_up_chat_widget.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/verse_cache_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/fetch_verse_text.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/services/study_guide_tts_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/engaging_loading_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/tts_control_sheet.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/shared/widgets/scripture_verse_sheet.dart';

import '../../helpers/text_fit.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  _FakeLanguageService(this.language);
  final AppLanguage language;

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => language;

  @override
  Future<AppLanguage> getStudyContentLanguage() async => language;
}

class _SeenWalkthroughs extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

class _FakeSpeechService extends Fake implements SpeechService {}

class _FakeConfig extends Fake implements SystemConfigService {
  _FakeConfig({required this.bibleContent});
  final bool bibleContent;

  @override
  bool get isBibleContentEnabled => bibleContent;
}

class _CachedVerses extends Fake implements VerseCacheService {
  @override
  Future<CachedVerseData?> getCachedVerse({
    required String reference,
    required String language,
  }) async =>
      const CachedVerseData(
        text: 'For God so loved the world.',
        localizedReference: 'John 3:16',
      );
}

class _UnusedFetch extends Fake implements FetchVerseText {}

class _FakeTts extends Fake implements StudyGuideTTSService {
  int stopCalls = 0;
  final List<double> rates = [];

  @override
  final ValueNotifier<StudyGuideTtsState> state = ValueNotifier(
    const StudyGuideTtsState(
      status: TtsStatus.playing,
      currentSectionIndex: 1,
      sectionProgress: 0.4,
      estimatedDurationSeconds: 90,
      elapsedSeconds: 36,
    ),
  );

  @override
  bool get hasGuide => true;

  @override
  int get totalSections => 3;

  @override
  List<String> get sectionNames =>
      const ['Summary', 'Interpretation', 'Context'];

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> setSpeechRate(double rate) async => rates.add(rate);
}

class _MockChatBloc extends MockBloc<FollowUpChatEvent, FollowUpChatState>
    implements FollowUpChatBloc {}

Future<void> _register(AppLanguage language) async {
  SharedPreferences.setMockInitialValues(
      {'user_language_preference': language.code});
  final prefs = await SharedPreferences.getInstance();
  await GetIt.instance.reset();
  final languageService = _FakeLanguageService(language);
  GetIt.instance
    ..registerSingleton<TranslationService>(
        TranslationService(languageService, prefs))
    ..registerSingleton<LanguagePreferenceService>(languageService)
    ..registerSingleton<WalkthroughRepository>(_SeenWalkthroughs())
    ..registerSingleton<SpeechService>(_FakeSpeechService());
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

/// Pumps [builder]'s sheet from a button, as the app opens it.
Future<void> _openSheet(
  WidgetTester tester, {
  required bool dark,
  required void Function(BuildContext context) open,
}) async {
  await tester.pumpWidget(_app(
    dark: dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    registerFallbackValue(const CancelRequestEvent());
    await loadAppFonts();
  });

  tearDown(() => GetIt.instance.reset());

  final combos = [
    for (final language in AppLanguage.values)
      for (final dark in [true, false]) (language, dark),
  ];

  group('follow-up chat status cards', () {
    final states = <String, FollowUpChatState>{
      'error': const FollowUpChatError('x'),
      'no credits': const FollowUpChatInsufficientTokens(
        required: 5,
        available: 0,
        userPlan: 'free',
      ),
      'not on plan': const FollowUpChatFeatureNotAvailable(
        message: 'Follow-up chat is part of Plus.',
        userPlan: 'free',
      ),
      'limit': const FollowUpChatLimitExceeded(
        message: 'You reached the limit for this guide.',
        current: 5,
        max: 5,
        userPlan: 'free',
      ),
    };

    for (final (language, dark) in combos) {
      for (final entry in states.entries) {
        testWidgets(
            '${entry.key} fits 320x640 ${language.code} '
            '${dark ? 'dark' : 'light'}', (tester) async {
          await _register(language);
          _usePhone(tester);
          final bloc = _MockChatBloc();
          whenListen(bloc, const Stream<FollowUpChatState>.empty(),
              initialState: entry.value);
          await tester.pumpWidget(_app(
            dark: dark,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocProvider<FollowUpChatBloc>.value(
                  value: bloc,
                  child: const FollowUpChatWidget(
                    studyGuideId: 'g1',
                    studyGuideTitle: 'Forgiveness',
                    isExpanded: true,
                    sectionNumber: 8,
                  ),
                ),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }

    testWidgets('dismiss restarts the conversation; primary is a cta pill',
        (tester) async {
      await _register(AppLanguage.english);
      _usePhone(tester);
      final bloc = _MockChatBloc();
      whenListen(bloc, const Stream<FollowUpChatState>.empty(),
          initialState: const FollowUpChatInsufficientTokens(
            required: 5,
            available: 0,
            userPlan: 'free',
          ));
      await tester.pumpWidget(_app(
        dark: true,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<FollowUpChatBloc>.value(
              value: bloc,
              child: const FollowUpChatWidget(
                studyGuideId: 'g1',
                studyGuideTitle: 'Forgiveness',
                isExpanded: true,
                sectionNumber: 8,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      final primary = tester.widget<FilledButton>(find.descendant(
          of: find.byKey(const Key('follow_up_chat_get_tokens')),
          matching: find.byType(FilledButton)));
      final palette =
          ReaderPalette.of(tester.element(find.byType(FollowUpChatWidget)));
      expect(primary.style?.backgroundColor?.resolve({}), palette.ctaFill);

      clearInteractions(bloc);
      await tester
          .ensureVisible(find.byKey(const Key('follow_up_chat_dismiss')));
      await tester.tap(find.byKey(const Key('follow_up_chat_dismiss')));
      verify(() => bloc.add(any(that: isA<StartConversationEvent>())))
          .called(1);
    });
  });

  group('listen controls sheet', () {
    for (final (language, dark) in combos) {
      testWidgets(
          'fits 320x640 ${language.code} ${dark ? 'dark' : 'light'} on palette.card',
          (tester) async {
        await _register(language);
        GetIt.instance.registerSingleton<StudyGuideTTSService>(_FakeTts());
        _usePhone(tester);
        await _openSheet(tester,
            dark: dark, open: (context) => showTtsControlSheet(context));

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        final palette =
            ReaderPalette.of(tester.element(find.byType(TtsControlSheet)));
        final surface = tester.widget<Container>(find
            .descendant(
                of: find.byType(TtsControlSheet),
                matching: find.byType(Container))
            .first);
        expect((surface.decoration! as BoxDecoration).color, palette.card);
      });
    }

    testWidgets('speed chip and Stop still work', (tester) async {
      await _register(AppLanguage.english);
      final tts = _FakeTts();
      GetIt.instance.registerSingleton<StudyGuideTTSService>(tts);
      _usePhone(tester);
      await _openSheet(tester,
          dark: true, open: (context) => showTtsControlSheet(context));

      await tester.tap(find.text('1.25x'));
      expect(tts.rates, [1.25]);

      await tester.ensureVisible(find.byKey(const Key('tts_stop_button')));
      await tester.tap(find.byKey(const Key('tts_stop_button')));
      await tester.pumpAndSettle();
      expect(tts.stopCalls, 1);
      expect(find.byType(TtsControlSheet), findsNothing);
    });
  });

  group('scripture verse sheet', () {
    for (final (language, dark) in combos) {
      testWidgets(
          'loaded verse fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
          (tester) async {
        await _register(language);
        GetIt.instance
          ..registerSingleton<SystemConfigService>(
              _FakeConfig(bibleContent: true))
          ..registerSingleton<VerseCacheService>(_CachedVerses())
          ..registerSingleton<FetchVerseText>(_UnusedFetch());
        _usePhone(tester);
        await _openSheet(tester,
            dark: dark,
            open: (context) =>
                ScriptureVerseSheet.show(context, reference: 'John 3:16'));

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        expect(find.text('For God so loved the world.'), findsOneWidget);
        expect(find.byKey(const Key('verse_sheet_study')), findsOneWidget);
        expect(find.byKey(const Key('verse_sheet_memory')), findsOneWidget);
        expect(find.byKey(const Key('verse_sheet_copy')), findsOneWidget);
      });
    }

    testWidgets('kill-switch shows the unavailable message, no actions',
        (tester) async {
      await _register(AppLanguage.english);
      GetIt.instance.registerSingleton<SystemConfigService>(
          _FakeConfig(bibleContent: false));
      _usePhone(tester);
      await _openSheet(tester,
          dark: false,
          open: (context) =>
              ScriptureVerseSheet.show(context, reference: 'John 3:16'));

      expect(find.text('Bible content is temporarily unavailable.'),
          findsOneWidget);
      expect(find.byKey(const Key('verse_sheet_study')), findsNothing);
    });

    testWidgets('copy puts the verse on the clipboard and confirms',
        (tester) async {
      await _register(AppLanguage.english);
      GetIt.instance
        ..registerSingleton<SystemConfigService>(
            _FakeConfig(bibleContent: true))
        ..registerSingleton<VerseCacheService>(_CachedVerses())
        ..registerSingleton<FetchVerseText>(_UnusedFetch());
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      _usePhone(tester);
      await _openSheet(tester,
          dark: true,
          open: (context) =>
              ScriptureVerseSheet.show(context, reference: 'John 3:16'));

      await tester.ensureVisible(find.byKey(const Key('verse_sheet_copy')));
      await tester.tap(find.byKey(const Key('verse_sheet_copy')));
      await tester.pump();
      expect(copied, contains('For God so loved the world.'));
      expect(find.text('Verse copied to clipboard'), findsOneWidget);
    });
  });

  group('generation loading screen', () {
    setUp(() {
      // WakelockPlus talks to a pigeon channel; answer it with "done".
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (message) async =>
            const StandardMessageCodec().encodeMessage(<Object?>[]),
      );
    });

    for (final (language, dark) in combos) {
      testWidgets(
          'palette ground fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
          (tester) async {
        await _register(language);
        _usePhone(tester);
        await tester.pumpWidget(_app(
          dark: dark,
          home: Scaffold(
            body: EngagingLoadingScreen(
              topic: 'John 3:16',
              language: language.code,
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 700));

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester, allow: {'John 3:16'});
        final palette = ReaderPalette.of(
            tester.element(find.byType(EngagingLoadingScreen)));
        final ground = tester.widget<ColoredBox>(find
            .descendant(
                of: find.byType(EngagingLoadingScreen),
                matching: find.byType(ColoredBox))
            .first);
        expect(ground.color, palette.page);

        // Dispose so the stage/fact timers are cancelled.
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
