import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_event.dart';
import 'package:disciplefy_bible_study/features/follow_up_chat/presentation/bloc/follow_up_chat_state.dart';

import 'follow_up_chat_bloc_test.mocks.dart';

/// The Discipler follow-up chat needs an account: the server answers a
/// guest's conversation-history / study-followup calls with 403
/// ACCOUNT_REQUIRED. A guest's bloc never makes them.
void main() {
  late MockHttpService httpService;
  late MockConversationService conversationService;

  setUp(() {
    httpService = MockHttpService();
    conversationService = MockConversationService();
  });

  FollowUpChatBloc build({required bool guest}) => FollowUpChatBloc(
        httpService: httpService,
        conversationService: conversationService,
        isGuest: () => guest,
      );

  blocTest<FollowUpChatBloc, FollowUpChatState>(
    'a guest: starting a conversation makes no call and shows no error',
    build: () => build(guest: true),
    act: (bloc) => bloc.add(const StartConversationEvent(
      studyGuideId: 'guide-1',
      studyGuideTitle: 'Who is Jesus?',
    )),
    expect: () => <FollowUpChatState>[],
    verify: (_) {
      verifyZeroInteractions(conversationService);
      verifyZeroInteractions(httpService);
    },
  );

  blocTest<FollowUpChatBloc, FollowUpChatState>(
    'a guest: sending a question makes no call',
    build: () => build(guest: true),
    act: (bloc) => bloc.add(const SendQuestionEvent(question: 'Why?')),
    expect: () => <FollowUpChatState>[],
    verify: (_) => verifyZeroInteractions(httpService),
  );

  blocTest<FollowUpChatBloc, FollowUpChatState>(
    'a full account still loads its conversation history',
    build: () {
      when(conversationService.loadConversationHistory('guide-1'))
          .thenThrow(Exception('offline'));
      return build(guest: false);
    },
    act: (bloc) => bloc.add(const StartConversationEvent(
      studyGuideId: 'guide-1',
      studyGuideTitle: 'Who is Jesus?',
    )),
    expect: () => [isA<FollowUpChatLoading>(), isA<FollowUpChatError>()],
    verify: (_) =>
        verify(conversationService.loadConversationHistory('guide-1'))
            .called(1),
  );
}
