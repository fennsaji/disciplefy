import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/tts_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';

import 'voice_last_word_test.mocks.dart';

/// Reproduces the Android ordering that dropped the final word: the recognizer
/// reports status `notListening` BEFORE it delivers the final result, so the
/// bloc used to send the last partial and clear its buffers, discarding the
/// complete text that arrived moments later.
@GenerateNiceMocks([
  MockSpec<VoiceBuddyRepository>(),
  MockSpec<SpeechService>(),
  MockSpec<TTSService>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<LanguagePreferenceService>(),
])
void main() {
  late MockVoiceBuddyRepository repository;
  late MockSpeechService speechService;
  late MockTTSService ttsService;
  late MockSupabaseClient supabaseClient;
  late MockLanguagePreferenceService languagePreferenceService;
  late MockGoTrueClient auth;

  // Callbacks the bloc hands to the speech engine, captured so the test can
  // drive the engine's ordering by hand.
  late void Function(SpeechRecognitionResult) onResult;
  late void Function(String) onStatusChange;

  VoiceConversationBloc buildBloc() {
    final bloc = VoiceConversationBloc(
      repository: repository,
      speechService: speechService,
      ttsService: ttsService,
      supabaseClient: supabaseClient,
      languagePreferenceService: languagePreferenceService,
    );
    bloc.emit(VoiceConversationState(
      status: VoiceConversationStatus.ready,
      conversation: VoiceConversationEntity(
        id: 'conv-1',
        userId: 'user-1',
        sessionId: 'session-1',
        languageCode: 'en-US',
        conversationType: ConversationType.general,
        totalMessages: 0,
        totalDurationSeconds: 0,
        status: ConversationStatus.active,
        startedAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ));
    return bloc;
  }

  setUp(() {
    repository = MockVoiceBuddyRepository();
    speechService = MockSpeechService();
    ttsService = MockTTSService();
    supabaseClient = MockSupabaseClient();
    languagePreferenceService = MockLanguagePreferenceService();
    auth = MockGoTrueClient();
    when(supabaseClient.auth).thenReturn(auth);
    when(auth.currentUser).thenReturn(null);

    when(speechService.initialize()).thenAnswer((_) async => true);
    when(speechService.stopListening()).thenAnswer((_) async {});
    when(ttsService.stop()).thenAnswer((_) async {});

    when(speechService.startListening(
      languageCode: anyNamed('languageCode'),
      onResult: anyNamed('onResult'),
      onSoundLevelChange: anyNamed('onSoundLevelChange'),
      onStatusChange: anyNamed('onStatusChange'),
      onError: anyNamed('onError'),
      pauseFor: anyNamed('pauseFor'),
      listenFor: anyNamed('listenFor'),
      partialResults: anyNamed('partialResults'),
    )).thenAnswer((invocation) async {
      onResult = invocation.namedArguments[#onResult] as void Function(
          SpeechRecognitionResult);
      onStatusChange =
          invocation.namedArguments[#onStatusChange] as void Function(String);
    });
  });

  SpeechRecognitionResult result(String words, {required bool isFinal}) =>
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, null, 0.9)],
        isFinal,
      );

  test('final result wins when it arrives after the notListening status',
      () async {
    final bloc = buildBloc();
    bloc.add(const StartListening());
    await Future.delayed(const Duration(milliseconds: 50));

    // Partial text — the trailing word has not been recognized yet.
    onResult(result('what does the wages of sin', isFinal: false));
    // Android flips the status before delivering the final result.
    onStatusChange('notListening');
    // The complete sentence lands inside the grace window.
    await Future.delayed(const Duration(milliseconds: 200));
    onResult(result('what does the wages of sin mean', isFinal: true));

    await Future.delayed(const Duration(milliseconds: 900));

    expect(bloc.state.messages.map((m) => m.contentText),
        contains('what does the wages of sin mean'));
    expect(bloc.state.messages.map((m) => m.contentText),
        isNot(contains('what does the wages of sin')));
    await bloc.close();
  });

  test('falls back to the last partial when no final result ever arrives',
      () async {
    final bloc = buildBloc();
    bloc.add(const StartListening());
    await Future.delayed(const Duration(milliseconds: 50));

    onResult(result('tell me about grace', isFinal: false));
    onStatusChange('notListening');

    await Future.delayed(const Duration(milliseconds: 900));

    expect(bloc.state.messages.map((m) => m.contentText),
        contains('tell me about grace'));
    await bloc.close();
  });

  test('a late speech callback after close does not throw', () async {
    final bloc = buildBloc();
    bloc.add(const StartListening());
    await Future.delayed(const Duration(milliseconds: 50));

    await bloc.close();

    // The engine can deliver one more result after the screen is gone.
    expect(
        () => onResult(result('late words', isFinal: true)), returnsNormally);
    expect(() => onStatusChange('done'), returnsNormally);
  });
}
