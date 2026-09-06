import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'fellowship_discipler_review_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;
  FellowshipCommentEntity draft(String id) => FellowshipCommentEntity(
      id: id,
      postId: 'p',
      authorUserId: kDisciplerUserId,
      content: 'draft',
      isDeleted: false,
      createdAt: 't',
      authorDisplayName: 'Discipler',
      isPendingReview: true);
  final seeded = FellowshipFeedState.initial().copyWith(
      status: FellowshipFeedStatus.success,
      activePostId: 'p',
      comments: [draft('c1'), draft('c2')]);
  setUp(() => repository = MockCommunityRepository());

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'approve clears pending on the comment',
    build: () {
      when(repository.approveDisciplerComment('c1'))
          .thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (b) => b.add(const FellowshipDisciplerCommentReviewed(
        commentId: 'c1', approve: true)),
    verify: (b) {
      expect(b.state.comments.firstWhere((c) => c.id == 'c1').isPendingReview,
          false);
      expect(b.state.comments.firstWhere((c) => c.id == 'c2').isPendingReview,
          true);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'discard removes the comment',
    build: () {
      when(repository.discardDisciplerComment('c2'))
          .thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (b) => b.add(const FellowshipDisciplerCommentReviewed(
        commentId: 'c2', approve: false)),
    verify: (b) => expect(b.state.comments.map((c) => c.id), ['c1']),
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'create post forwards toMentors',
    build: () {
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
        toMentors: true,
      )).thenAnswer((_) async => Left(const ServerFailure(message: 'x')));
      return FellowshipFeedBloc(repository: repository);
    },
    act: (b) => b.add(const FellowshipPostCreateRequested(
        fellowshipId: 'f',
        content: 'help?',
        postType: 'question',
        toMentors: true)),
    verify: (_) => verify(repository.createPost(
            fellowshipId: 'f',
            content: 'help?',
            postType: 'question',
            toMentors: true))
        .called(1),
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'creating a comment keeps toMentors and mentionsDiscipler on the post',
    build: () {
      when(repository.createComment(
        postId: anyNamed('postId'),
        content: anyNamed('content'),
      )).thenAnswer((_) async => Right(FellowshipCommentEntity(
            id: 'c1',
            postId: 'p',
            authorUserId: 'u',
            content: 'reply',
            isDeleted: false,
            createdAt: 't',
            authorDisplayName: 'User',
          )));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => FellowshipFeedState.initial().copyWith(
      status: FellowshipFeedStatus.success,
      activePostId: 'p',
      posts: [
        const FellowshipPostEntity(
          id: 'p',
          fellowshipId: 'f',
          authorUserId: 'a',
          content: 'question for mentors',
          postType: 'question',
          reactionCounts: {},
          isDeleted: false,
          createdAt: 't',
          authorDisplayName: 'a',
          commentCount: 0,
          toMentors: true,
          mentionsDiscipler: true,
        ),
      ],
    ),
    act: (b) => b.add(const FellowshipCommentCreateRequested(content: 'reply')),
    verify: (b) {
      final post = b.state.posts.firstWhere((p) => p.id == 'p');
      expect(post.commentCount, 1);
      expect(post.toMentors, true);
      expect(post.mentionsDiscipler, true);
    },
  );
}
