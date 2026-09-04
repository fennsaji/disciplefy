import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/data/services/conversation_service.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_event.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'follow_up_chat_bloc_test.mocks.dart';

/// Regressions for the "asked twice, no answer, stuck on Responding..." bug
/// report (4 Sept 2026):
///
/// 1. The mobile fallback POST used [HttpService]'s 10s default timeout, but
///    the backend generates the whole answer with an LLM before replying —
///    routinely well over 10s — so the request timed out with credits
///    already spent server-side.
/// 2. `_onStreamingError`'s generic branch marked the placeholder message
///    failed in one emit, then re-emitted from the stale `currentState` on
///    the next line, whose copy of the placeholder was still `streaming`.
///    The bubble was left on "Responding..." forever.
@GenerateMocks([HttpService, ConversationService])
void main() {
  late MockHttpService httpService;
  late MockConversationService conversationService;

  setUp(() {
    httpService = MockHttpService();
    conversationService = MockConversationService();
  });

  FollowUpChatBloc buildBloc() => FollowUpChatBloc(
        httpService: httpService,
        conversationService: conversationService,
      );

  final seeded = FollowUpChatLoaded(
    studyGuideId: 'guide-1',
    studyGuideTitle: 'The Cost of Following Jesus',
    conversationId: 'conv-1',
    messages: <ChatMessage>[
      ChatMessage(
        id: 'user-1',
        content: 'How should a day look like if I have followed all this',
        isUser: true,
        timestamp: DateTime(2026, 9, 4, 3, 5),
      ),
      ChatMessage(
        id: 'assistant-1',
        content: '',
        isUser: false,
        timestamp: DateTime(2026, 9, 4, 3, 5),
        status: ChatMessageStatus.streaming,
      ),
    ],
    isProcessing: true,
    currentStreamingMessageId: 'assistant-1',
  );

  blocTest<FollowUpChatBloc, FollowUpChatState>(
    'a generic streaming error marks the placeholder failed, not stuck streaming',
    build: buildBloc,
    seed: () => seeded,
    act: (bloc) =>
        bloc.add(const StreamingErrorEvent('Streaming connection error')),
    verify: (bloc) {
      final state = bloc.state;
      expect(state, isA<FollowUpChatLoaded>());
      final loaded = state as FollowUpChatLoaded;

      // The core bug: this used to still be `streaming`.
      final assistantMessage =
          loaded.messages.firstWhere((m) => m.id == 'assistant-1');
      expect(assistantMessage.status, ChatMessageStatus.failed,
          reason: 'placeholder must not be left as "Responding..."');

      expect(loaded.isProcessing, isFalse);
      expect(loaded.error, 'Streaming connection error');
      expect(loaded.currentStreamingMessageId, isNull);
    },
  );

  test('mobile fallback POST uses the follow-up timeout, not the 10s default',
      () {
    expect(FollowUpChatBloc.followUpRequestTimeout,
        greaterThan(const Duration(seconds: 10)));
  });
}
