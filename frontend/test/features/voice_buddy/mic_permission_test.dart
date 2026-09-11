import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/tts_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';

import 'mic_permission_test.mocks.dart';

/// A refused microphone used to reach the user as a red "Something went wrong.
/// Please try again." — the recognizer's `initialize()` returned a bare `false`
/// and the bloc could not tell a declined permission from a broken engine.
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
  });

  Future<VoiceConversationBloc> tapMicWith(MicPermission permission) async {
    when(speechService.requestMicrophonePermission())
        .thenAnswer((_) async => permission);
    final bloc = buildBloc();
    bloc.add(const StartListening());
    await Future.delayed(const Duration(milliseconds: 50));
    return bloc;
  }

  test('a declined microphone is not reported as an error', () async {
    final bloc = await tapMicWith(MicPermission.denied);

    expect(bloc.state.status, VoiceConversationStatus.micPermissionDenied);
    expect(bloc.state.micPermissionPermanentlyDenied, isFalse);
    expect(bloc.state.isListening, isFalse);
    // The user's own mode preference survives a refusal.
    expect(bloc.state.isContinuousMode, isTrue);
    await bloc.close();
  });

  test('a permanently declined microphone is flagged for the settings route',
      () async {
    final bloc = await tapMicWith(MicPermission.permanentlyDenied);

    expect(bloc.state.status, VoiceConversationStatus.micPermissionDenied);
    expect(bloc.state.micPermissionPermanentlyDenied, isTrue);
    await bloc.close();
  });

  test('the recognizer is never touched when the microphone is refused',
      () async {
    final bloc = await tapMicWith(MicPermission.denied);

    verifyNever(speechService.initialize());
    verifyNever(speechService.startListening(
      languageCode: anyNamed('languageCode'),
      onResult: anyNamed('onResult'),
    ));
    await bloc.close();
  });

  test('a granted microphone proceeds to the recognizer', () async {
    final bloc = await tapMicWith(MicPermission.granted);

    expect(
        bloc.state.status, isNot(VoiceConversationStatus.micPermissionDenied));
    verify(speechService.initialize()).called(1);
    await bloc.close();
  });
}
