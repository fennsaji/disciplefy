import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/pages/voice_conversation_page.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/mic_permission_dialog.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/voice_button.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockVoiceBloc
    extends MockBloc<VoiceConversationEvent, VoiceConversationState>
    implements VoiceConversationBloc {}

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

class _FakeLanguagePrefs extends Fake implements LanguagePreferenceService {
  @override
  Future<AppLanguage> getStudyContentLanguage() async => AppLanguage.english;
}

const _quota = VoiceQuotaEntity(
  canStart: true,
  quotaLimit: 3,
  quotaUsed: 0,
  quotaRemaining: 3,
  tier: 'plus',
);

final _now = DateTime(2026, 9, 30, 9, 41);

final _conversation = VoiceConversationEntity(
  id: 'c1',
  userId: 'u1',
  sessionId: 's1',
  languageCode: 'en-US',
  conversationType: ConversationType.general,
  totalMessages: 0,
  totalDurationSeconds: 0,
  status: ConversationStatus.active,
  startedAt: _now,
  createdAt: _now,
  updatedAt: _now,
);

ConversationMessageEntity _message(
  int order,
  MessageRole role,
  String text, {
  List<String>? refs,
}) =>
    ConversationMessageEntity(
      id: 'm$order',
      conversationId: 'c1',
      userId: 'u1',
      messageOrder: order,
      role: role,
      contentText: text,
      contentLanguage: 'en',
      scriptureReferences: refs,
      createdAt: _now,
    );

final _messages = [
  _message(1, MessageRole.user, 'Why did Jesus speak in parables?'),
  _message(
    2,
    MessageRole.assistant,
    'Jesus used parables to reveal truth to open hearts. He explains this '
    'after the parable of the sower in Matthew 13:10-13.',
    refs: ['Matthew 13:10-13'],
  ),
  _message(3, MessageRole.user, 'So were parables meant to confuse people?'),
];

const _startState = VoiceConversationState(quota: _quota);

VoiceConversationState _ready({
  List<ConversationMessageEntity> messages = const [],
}) =>
    VoiceConversationState(
      status: VoiceConversationStatus.ready,
      conversation: _conversation,
      messages: messages,
      quota: _quota,
    );

void main() {
  late _MockVoiceBloc bloc;
  late FakeTranslationService translations;

  setUpAll(() async {
    registerFallbackValue(const LoadPreferences());
    await loadAppFonts();
  });

  setUp(() async {
    await sl.reset();
    bloc = _MockVoiceBloc();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerFactory<VoiceConversationBloc>(() => bloc);
    sl.registerSingleton<GamificationBloc>(_MockGamificationBloc());
    sl.registerSingleton<LanguagePreferenceService>(_FakeLanguagePrefs());
  });

  tearDown(() async => sl.reset());

  /// Mounts the Discipler tab with [initial]; [states] are emitted after.
  Future<void> pump(
    WidgetTester tester, {
    required VoiceConversationState initial,
    Stream<VoiceConversationState>? states,
    bool dark = true,
    Size size = const Size(390, 844),
  }) async {
    useSurface(tester, size);
    whenListen(
      bloc,
      states ?? const Stream<VoiceConversationState>.empty(),
      initialState: initial,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const VoiceConversationPage(asTab: true),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  String tr(String key) => translations.getTranslation(key);

  group('layout', () {
    final screens = <String, VoiceConversationState>{
      'start': _startState,
      'chat': VoiceConversationState(
        status: VoiceConversationStatus.processing,
        conversation: _conversation,
        messages: _messages,
        quota: _quota,
      ),
      'listening': VoiceConversationState(
        status: VoiceConversationStatus.listening,
        conversation: _conversation,
        isListening: true,
        currentTranscription: 'How can I trust God when things feel uncertain',
        quota: _quota,
      ),
      'speaking': VoiceConversationState(
        status: VoiceConversationStatus.playing,
        conversation: _conversation,
        messages: _messages.take(2).toList(),
        isPlaying: true,
        quota: _quota,
      ),
    };

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        for (final entry in screens.entries) {
          testWidgets(
              '${entry.key} fits 320x640 (${language.code}, '
              '${dark ? 'dark' : 'light'})', (tester) async {
            translations.language = language;
            await pump(
              tester,
              initial: entry.value,
              dark: dark,
              size: const Size(320, 640),
            );
            // The chat screen is reached from the voice view.
            if (entry.key == 'chat') {
              await tester.tap(find.byTooltip(translations
                  .getTranslation(TranslationKeys.voiceSessionTypingMode)));
              await tester.pump(const Duration(milliseconds: 50));
              expect(find.byType(TextField), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            expectNoTruncatedText(tester);
          });
        }
      }
    }
  });

  group('end sheet layout', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets(
            'fits 320x640 (${language.code}, ${dark ? 'dark' : 'light'})',
            (tester) async {
          translations.language = language;
          await pump(
            tester,
            initial: _ready(messages: _messages),
            dark: dark,
            size: const Size(320, 640),
          );
          await tester.tap(
              find.byTooltip(tr('voice_buddy.voice_controls.end_tooltip')));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  });

  group('start screen', () {
    testWidgets('shows content and allowance', (tester) async {
      await pump(tester, initial: _startState);
      expect(
          find.text(tr(TranslationKeys.voiceSessionHeadline)), findsOneWidget);
      expect(find.text(tr('voice_buddy.description')), findsOneWidget);
      expect(find.text('3 of 3 left this month'), findsOneWidget);
      expect(find.text('Speaking English'), findsOneWidget);
      for (final key in [
        TranslationKeys.voiceSessionSuggestion1,
        TranslationKeys.voiceSessionSuggestion2,
        TranslationKeys.voiceSessionSuggestion3,
      ]) {
        expect(find.text(tr(key)), findsOneWidget);
      }
    });

    testWidgets('Start talking starts a conversation', (tester) async {
      await pump(tester, initial: _startState);
      await tester.tap(find.text(tr(TranslationKeys.voiceSessionStartTalking)));
      verify(() => bloc.add(const StartConversation(languageCode: 'en-US')))
          .called(1);
    });

    testWidgets('Start talking listens once the conversation is active',
        (tester) async {
      final states = StreamController<VoiceConversationState>();
      addTearDown(states.close);
      await pump(tester, initial: _startState, states: states.stream);

      await tester.tap(find.text(tr(TranslationKeys.voiceSessionStartTalking)));
      verifyNever(() => bloc.add(const StartListening()));

      states.add(const VoiceConversationState(
        status: VoiceConversationStatus.loading,
        quota: _quota,
      ));
      await tester.pump();
      verifyNever(() => bloc.add(const StartListening()));

      states.add(_ready());
      await tester.pump();
      verify(() => bloc.add(const StartListening())).called(1);

      // A later ready state (the allowance refresh) does not listen again.
      states.add(_ready().copyWith(
          quota: const VoiceQuotaEntity(
        canStart: true,
        quotaLimit: 3,
        quotaUsed: 1,
        quotaRemaining: 2,
        tier: 'plus',
      )));
      await tester.pump();
      verifyNever(() => bloc.add(const StartListening()));
    });

    testWidgets('Start talking with the mic declined shows the dialog',
        (tester) async {
      final states = StreamController<VoiceConversationState>();
      addTearDown(states.close);
      await pump(tester, initial: _startState, states: states.stream);

      await tester.tap(find.text(tr(TranslationKeys.voiceSessionStartTalking)));
      states.add(_ready());
      await tester.pump();
      verify(() => bloc.add(const StartListening())).called(1);

      states.add(VoiceConversationState(
        status: VoiceConversationStatus.micPermissionDenied,
        conversation: _conversation,
        quota: _quota,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(MicPermissionDialog), findsOneWidget);
    });

    testWidgets('a suggestion starts and then sends it', (tester) async {
      final states = StreamController<VoiceConversationState>();
      addTearDown(states.close);
      await pump(tester, initial: _startState, states: states.stream);

      final question = tr(TranslationKeys.voiceSessionSuggestion2);
      await tester.tap(find.text(question));
      verify(() => bloc.add(const StartConversation(languageCode: 'en-US')))
          .called(1);
      verifyNever(() => bloc.add(SendTextMessage(question)));

      states.add(_ready());
      await tester.pump();
      verify(() => bloc.add(SendTextMessage(question))).called(1);
      verifyNever(() => bloc.add(const StartListening()));
      // It lands in the chat view.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Type opens the chat view', (tester) async {
      final states = StreamController<VoiceConversationState>();
      addTearDown(states.close);
      await pump(tester, initial: _startState, states: states.stream);

      await tester.tap(find.text(tr(TranslationKeys.voiceSessionType)));
      verify(() => bloc.add(const StartConversation(languageCode: 'en-US')))
          .called(1);
      states.add(_ready());
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<SendTextMessage>())));
      verifyNever(() => bloc.add(const StartListening()));
    });

    testWidgets('no allowance: no conversation is started', (tester) async {
      await pump(
        tester,
        initial: const VoiceConversationState(
          quota: VoiceQuotaEntity(
            canStart: false,
            quotaLimit: 3,
            quotaUsed: 3,
            quotaRemaining: 0,
            tier: 'plus',
          ),
        ),
      );
      expect(find.text('0 of 3 left this month'), findsOneWidget);
      // The upgrade sheet needs app services; only the gate matters here.
      try {
        await tester
            .tap(find.text(tr(TranslationKeys.voiceSessionStartTalking)));
        await tester.pump();
      } catch (_) {}
      tester.takeException();
      verifyNever(() => bloc.add(any(that: isA<StartConversation>())));
    });

    testWidgets('language chip changes the language', (tester) async {
      await pump(tester, initial: _startState);
      await tester.tap(find.text('Speaking English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const ChangeLanguage('hi-IN'))).called(1);
    });
  });

  group('conversation', () {
    Future<void> openChat(WidgetTester tester) async {
      await tester
          .tap(find.byTooltip(tr(TranslationKeys.voiceSessionTypingMode)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('chat shows messages, references and sends text',
        (tester) async {
      await pump(tester, initial: _ready(messages: _messages));
      await openChat(tester);

      expect(find.text('Why did Jesus speak in parables?'), findsOneWidget);
      expect(find.text('Matthew 13:10-13'), findsOneWidget);
      expect(find.text('Ready · English'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Tell me more  ');
      await tester.tap(find.byTooltip(tr(TranslationKeys.voiceSessionSend)));
      verify(() => bloc.add(const SendTextMessage('Tell me more'))).called(1);
      // Let the scroll-to-bottom delay run out.
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('End opens the sheet and sends the feedback', (tester) async {
      await pump(tester, initial: _ready(messages: _messages));
      await openChat(tester);

      await tester.tap(find.text(tr('voice_buddy.conversation.end_button')));
      await tester.pumpAndSettle();
      expect(
          find.text(tr('voice_buddy.conversation.end_title')), findsOneWidget);

      await tester.tap(find.byTooltip('Rate 4 of 5'));
      await tester.tap(find.text(tr('voice_buddy.conversation.yes')));
      await tester.enterText(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField)),
          'Helpful');
      await tester.pump();
      await tester.tap(find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.text(tr('voice_buddy.conversation.end_button')),
          )
          .last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const EndConversation(
            rating: 4,
            feedbackText: 'Helpful',
            wasHelpful: true,
          ))).called(1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Keep talking closes the sheet without ending', (tester) async {
      await pump(tester, initial: _ready(messages: _messages));
      await tester
          .tap(find.byTooltip(tr('voice_buddy.voice_controls.end_tooltip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr(TranslationKeys.voiceSessionKeepTalking)));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      verifyNever(() => bloc.add(any(that: isA<EndConversation>())));
    });

    testWidgets('voice view: mic tap listens in continuous mode',
        (tester) async {
      await pump(tester, initial: _ready());
      expect(find.text(tr('voice_buddy.voice_controls.tap_to_speak')),
          findsWidgets);
      await tester.tap(find.byType(VoiceButton));
      verify(() => bloc.add(const StartListening())).called(1);
    });

    group('orb', () {
      final orb = find.byKey(const ValueKey('voice-session-orb'));

      /// Events the bloc received since the last call.
      List<Object?> received() {
        try {
          return verify(() => bloc.add(captureAny())).captured;
        } on TestFailure {
          return const [];
        }
      }

      final states = <String, VoiceConversationState>{
        'idle': _ready(),
        'listening': VoiceConversationState(
          status: VoiceConversationStatus.listening,
          conversation: _conversation,
          isListening: true,
        ),
        'thinking': VoiceConversationState(
          status: VoiceConversationStatus.processing,
          conversation: _conversation,
        ),
      };

      for (final continuous in [true, false]) {
        for (final entry in states.entries) {
          testWidgets(
              'tap does what the mic does (${entry.key}, '
              '${continuous ? 'continuous' : 'hold'})', (tester) async {
            await pump(
              tester,
              initial: entry.value.copyWith(isContinuousMode: continuous),
            );
            expect(orb, findsOneWidget);
            received();

            await tester.tap(find.byType(VoiceButton));
            final fromMic = received();
            await tester.tap(orb);
            final fromOrb = received();

            expect(fromOrb, fromMic);
          });
        }
      }

      testWidgets('idle tap starts listening', (tester) async {
        await pump(tester, initial: _ready());
        await tester.tap(orb);
        verify(() => bloc.add(const StartListening())).called(1);
      });

      testWidgets('listening tap stops listening', (tester) async {
        await pump(
          tester,
          initial: VoiceConversationState(
            status: VoiceConversationStatus.listening,
            conversation: _conversation,
            isListening: true,
          ),
        );
        await tester.tap(orb);
        verify(() => bloc.add(const StopListening())).called(1);
      });

      testWidgets('is a button labelled with the hint', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, initial: _ready());
        expect(
          tester.getSemantics(orb),
          matchesSemantics(
            label: tr('voice_buddy.voice_controls.tap_to_speak'),
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });
    });

    group('chat header status', () {
      Future<void> statusIn(
        WidgetTester tester,
        VoiceConversationState state,
      ) async {
        await pump(tester, initial: state);
        await openChat(tester);
        expect(find.byType(TextField), findsOneWidget);
      }

      String line(String key) => '${tr(key)} · English';

      testWidgets('text mode with nothing listening reads Ready',
          (tester) async {
        // A leftover listening flag from the voice view is not listening.
        await statusIn(
          tester,
          _ready(messages: _messages).copyWith(isListening: true),
        );
        expect(find.text(line(TranslationKeys.voiceSessionStatusReady)),
            findsOneWidget);
        expect(find.text(line(TranslationKeys.voiceSessionStatusListening)),
            findsNothing);
      });

      testWidgets('reads Thinking while a reply is prepared', (tester) async {
        await statusIn(
          tester,
          VoiceConversationState(
            status: VoiceConversationStatus.processing,
            conversation: _conversation,
            messages: _messages,
            isListening: true,
          ),
        );
        expect(find.text(line(TranslationKeys.voiceSessionStatusThinking)),
            findsOneWidget);
      });

      testWidgets('reads Speaking while the reply plays', (tester) async {
        await statusIn(
          tester,
          VoiceConversationState(
            status: VoiceConversationStatus.playing,
            conversation: _conversation,
            messages: _messages.take(2).toList(),
            isPlaying: true,
          ),
        );
        expect(find.text(line(TranslationKeys.voiceSessionStatusSpeaking)),
            findsOneWidget);
      });

      testWidgets('reads Listening only while the mic records', (tester) async {
        await statusIn(
          tester,
          VoiceConversationState(
            status: VoiceConversationStatus.listening,
            conversation: _conversation,
            messages: _messages,
            isListening: true,
          ),
        );
        expect(find.text(line(TranslationKeys.voiceSessionStatusListening)),
            findsOneWidget);
      });
    });

    testWidgets('listening shows the live transcription', (tester) async {
      await pump(
        tester,
        initial: VoiceConversationState(
          status: VoiceConversationStatus.listening,
          conversation: _conversation,
          isListening: true,
          currentTranscription: 'How can I trust God',
        ),
      );
      expect(find.text('How can I trust God'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('speaking: interrupt stops the reply and listens',
        (tester) async {
      await pump(
        tester,
        initial: VoiceConversationState(
          status: VoiceConversationStatus.playing,
          conversation: _conversation,
          messages: _messages.take(2).toList(),
          isPlaying: true,
        ),
      );
      expect(find.text('YOU ASKED'), findsOneWidget);
      expect(find.text('Why did Jesus speak in parables?'), findsOneWidget);

      await tester
          .tap(find.text(tr('voice_buddy.voice_controls.tap_to_interrupt')));
      verifyInOrder([
        () => bloc.add(const StopPlayback()),
        () => bloc.add(const StartListening()),
      ]);
    });
  });

  group('mic permission', () {
    for (final blocked in [false, true]) {
      testWidgets('dialog (${blocked ? 'blocked' : 'ask'})', (tester) async {
        final states = StreamController<VoiceConversationState>();
        addTearDown(states.close);
        await pump(tester, initial: _ready(), states: states.stream);

        states.add(VoiceConversationState(
          status: VoiceConversationStatus.micPermissionDenied,
          conversation: _conversation,
          micPermissionPermanentlyDenied: blocked,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MicPermissionDialog), findsOneWidget);
        expect(
          find.text(tr(blocked
              ? TranslationKeys.micPermissionOpenSettings
              : TranslationKeys.micPermissionAllow)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);

        if (!blocked) {
          await tester.tap(find.text(tr(TranslationKeys.micPermissionAllow)));
          await tester.pumpAndSettle();
          verify(() => bloc.add(const StartListening())).called(1);
        } else {
          await tester
              .tap(find.text(tr(TranslationKeys.micPermissionTypeInstead)));
          await tester.pumpAndSettle();
          expect(find.byType(MicPermissionDialog), findsNothing);
          // Type instead switches to the chat view.
          expect(find.byType(TextField), findsOneWidget);
        }
      });
    }
  });
}
