import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/tts_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';

class _FakeRepository implements VoiceBuddyRepository {
  Either<Failure, VoiceQuotaEntity> quotaResult = Right(_quota(3));
  int checkQuotaCalls = 0;

  @override
  Future<Either<Failure, VoiceQuotaEntity>> checkQuota() async {
    checkQuotaCalls++;
    return quotaResult;
  }

  @override
  Future<Either<Failure, VoiceConversationEntity>> startConversation({
    required String languageCode,
    required ConversationType conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
  }) async =>
      Right(VoiceConversationEntity(
        id: 'conv-1',
        userId: 'user-1',
        sessionId: 'session-1',
        languageCode: languageCode,
        conversationType: conversationType,
        totalMessages: 0,
        totalDurationSeconds: 0,
        status: ConversationStatus.active,
        startedAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSpeech implements SpeechService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeTts implements TTSService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuth implements GoTrueClient {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSupabase implements SupabaseClient {
  @override
  GoTrueClient get auth => _FakeAuth();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLanguage implements LanguagePreferenceService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

VoiceQuotaEntity _quota(int remaining, {int limit = 3}) => VoiceQuotaEntity(
      canStart: remaining != 0,
      quotaLimit: limit,
      quotaUsed: remaining < 0 ? 0 : limit - remaining,
      quotaRemaining: remaining,
      tier: 'free',
    );

void main() {
  late _FakeRepository repository;
  late VoiceConversationBloc bloc;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() async {
    repository = _FakeRepository();
    bloc = VoiceConversationBloc(
      repository: repository,
      speechService: _FakeSpeech(),
      ttsService: _FakeTts(),
      supabaseClient: _FakeSupabase(),
      languagePreferenceService: _FakeLanguage(),
    );
    bloc.add(const StartConversation(languageCode: 'en-US'));
    await settle();
    repository.checkQuotaCalls = 0;
  });

  tearDown(() => bloc.close());

  test('stream completion reloads the monthly quota into state', () async {
    repository.quotaResult = Right(_quota(2));

    bloc.add(const StreamCompleted(scriptureReferences: []));
    await settle();

    expect(repository.checkQuotaCalls, 1);
    expect(bloc.state.quota!.quotaRemaining, 2);
    expect(bloc.state.quotaDisplay, '2/3');
    expect(bloc.state.conversation, isNotNull);
  });

  test('unlimited quota (remaining < 0) shows Unlimited after a reply',
      () async {
    repository.quotaResult = Right(_quota(-1, limit: -1));

    bloc.add(const StreamCompleted(scriptureReferences: []));
    await settle();

    expect(bloc.state.quotaDisplay, 'Unlimited');
    expect(bloc.state.quota!.canStart, true);
  });

  test('a failed quota reload keeps the previous quota', () async {
    repository.quotaResult = Right(_quota(2));
    bloc.add(const StreamCompleted(scriptureReferences: []));
    await settle();

    repository.quotaResult = const Left(NetworkFailure(message: 'offline'));
    bloc.add(const StreamCompleted(scriptureReferences: []));
    await settle();

    expect(bloc.state.quota!.quotaRemaining, 2);
  });

  test('message_limit_status does not touch the monthly chip', () async {
    final before = bloc.state.quota;

    bloc.handleStreamingEventForTest(
        {'messageCount': 18, 'limit': 20, 'remaining': 2});
    await settle();

    expect(bloc.state.quota, before);
    expect(repository.checkQuotaCalls, 0);
  });

  test('null quota stays null when the reload fails', () async {
    repository.quotaResult = const Left(NetworkFailure(message: 'offline'));
    final fresh = VoiceConversationBloc(
      repository: repository,
      speechService: _FakeSpeech(),
      ttsService: _FakeTts(),
      supabaseClient: _FakeSupabase(),
      languagePreferenceService: _FakeLanguage(),
    );
    addTearDown(fresh.close);

    fresh.add(const CheckQuota());
    await settle();

    expect(fresh.state.quota, isNull);
  });
}
