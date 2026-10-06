import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';

import '../../voice_last_word_test.mocks.dart';

void main() {
  late VoiceConversationBloc bloc;

  setUp(() {
    bloc = VoiceConversationBloc(
      repository: MockVoiceBuddyRepository(),
      speechService: MockSpeechService(),
      ttsService: MockTTSService(),
      supabaseClient: MockSupabaseClient(),
      languagePreferenceService: MockLanguagePreferenceService(),
    );
    bloc.emit(const VoiceConversationState(
      quota: VoiceQuotaEntity(
        canStart: true,
        quotaLimit: 3,
        quotaUsed: 0,
        quotaRemaining: 3,
        tier: 'free',
      ),
    ));
  });

  tearDown(() => bloc.close());

  test('streamed quota_status replaces the cached quota', () async {
    bloc.add(const QuotaUpdatedFromStream(remaining: 2, limit: 3));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.quota!.quotaRemaining, 2);
    expect(bloc.state.quota!.quotaUsed, 1);
    expect(bloc.state.quota!.quotaLimit, 3);
    expect(bloc.state.quota!.tier, 'free');
    expect(bloc.state.quotaDisplay, '2/3');
  });

  test('streamed quota of zero remaining blocks starting', () async {
    bloc.add(const QuotaUpdatedFromStream(remaining: 0, limit: 3));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.quota!.canStart, false);
  });
}
