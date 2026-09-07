import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'fellowship_discipler_opt_out_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  const created = FellowshipPostEntity(
    id: 'p1',
    fellowshipId: 'f1',
    authorUserId: 'u1',
    content: 'What time should we meet?',
    postType: 'question',
    reactionCounts: {},
    isDeleted: false,
    createdAt: 't',
    authorDisplayName: 'Mentor',
    commentCount: 0,
  );

  setUp(() {
    repository = MockCommunityRepository();
    when(repository.createPost(
      fellowshipId: anyNamed('fellowshipId'),
      content: anyNamed('content'),
      postType: anyNamed('postType'),
      topicId: anyNamed('topicId'),
      topicTitle: anyNamed('topicTitle'),
      guideTitle: anyNamed('guideTitle'),
      lessonIndex: anyNamed('lessonIndex'),
      studyGuideId: anyNamed('studyGuideId'),
      guideInputType: anyNamed('guideInputType'),
      guideLanguage: anyNamed('guideLanguage'),
      disciplerReplyOptOut: anyNamed('disciplerReplyOptOut'),
    )).thenAnswer((_) async => const Right(created));
  });

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'a mentor who switches Discipler off sends the opt-out',
    build: () => FellowshipFeedBloc(repository: repository),
    act: (b) => b.add(const FellowshipPostCreateRequested(
      fellowshipId: 'f1',
      content: 'What time should we meet?',
      postType: 'question',
      disciplerReplyOptOut: true,
    )),
    verify: (_) {
      verify(repository.createPost(
        fellowshipId: 'f1',
        content: anyNamed('content'),
        postType: 'question',
        topicId: anyNamed('topicId'),
        topicTitle: anyNamed('topicTitle'),
        guideTitle: anyNamed('guideTitle'),
        lessonIndex: anyNamed('lessonIndex'),
        studyGuideId: anyNamed('studyGuideId'),
        guideInputType: anyNamed('guideInputType'),
        guideLanguage: anyNamed('guideLanguage'),
        disciplerReplyOptOut: true,
      )).called(1);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'leaving the switch alone keeps Discipler answering',
    build: () => FellowshipFeedBloc(repository: repository),
    act: (b) => b.add(const FellowshipPostCreateRequested(
      fellowshipId: 'f1',
      content: 'What time should we meet?',
      postType: 'question',
    )),
    verify: (_) {
      final captured = verify(repository.createPost(
        fellowshipId: 'f1',
        content: anyNamed('content'),
        postType: 'question',
        topicId: anyNamed('topicId'),
        topicTitle: anyNamed('topicTitle'),
        guideTitle: anyNamed('guideTitle'),
        lessonIndex: anyNamed('lessonIndex'),
        studyGuideId: anyNamed('studyGuideId'),
        guideInputType: anyNamed('guideInputType'),
        guideLanguage: anyNamed('guideLanguage'),
        disciplerReplyOptOut: captureAnyNamed('disciplerReplyOptOut'),
      )).captured.single;
      expect(captured, false);
    },
  );
}
