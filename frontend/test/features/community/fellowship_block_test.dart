// Verifies that blocking a user strips their posts and comments from feed
// state immediately, which is what Apple's Guideline 1.2 review checks.

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';

import 'fellowship_block_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  const abuser = 'user-abuser';
  const friend = 'user-friend';

  FellowshipPostEntity post(String id, String authorId) => FellowshipPostEntity(
        id: id,
        fellowshipId: 'fellowship-1',
        authorUserId: authorId,
        content: 'content of $id',
        postType: 'general',
        reactionCounts: const {},
        isDeleted: false,
        createdAt: '2026-08-10T00:00:00.000Z',
        authorDisplayName: authorId,
        commentCount: 0,
      );

  FellowshipCommentEntity comment(String id, String authorId) =>
      FellowshipCommentEntity(
        id: id,
        postId: 'post-friend',
        authorUserId: authorId,
        content: 'comment $id',
        isDeleted: false,
        createdAt: '2026-08-10T00:00:00.000Z',
        authorDisplayName: authorId,
      );

  final seeded = FellowshipFeedState.initial().copyWith(
    status: FellowshipFeedStatus.success,
    posts: [post('post-abuser', abuser), post('post-friend', friend)],
    comments: [comment('c-abuser', abuser), comment('c-friend', friend)],
  );

  setUp(() {
    repository = MockCommunityRepository();
  });

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'removes the blocked author\'s posts and comments and reports success',
    build: () {
      when(repository.blockUser(
        blockedUserId: anyNamed('blockedUserId'),
        fellowshipId: anyNamed('fellowshipId'),
        contentType: anyNamed('contentType'),
        contentId: anyNamed('contentId'),
      )).thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const FellowshipBlockUserRequested(
      blockedUserId: abuser,
      fellowshipId: 'fellowship-1',
      contentType: 'post',
      contentId: 'post-abuser',
    )),
    verify: (bloc) {
      expect(bloc.state.posts.map((p) => p.id), ['post-friend']);
      expect(bloc.state.comments.map((c) => c.id), ['c-friend']);
      expect(bloc.state.blockStatus, FellowshipBlockStatus.success);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'restores the removed content when the block request fails',
    build: () {
      when(repository.blockUser(
        blockedUserId: anyNamed('blockedUserId'),
        fellowshipId: anyNamed('fellowshipId'),
        contentType: anyNamed('contentType'),
        contentId: anyNamed('contentId'),
      )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'network down')));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const FellowshipBlockUserRequested(
      blockedUserId: abuser,
      fellowshipId: 'fellowship-1',
    )),
    verify: (bloc) {
      expect(bloc.state.posts.length, 2);
      expect(bloc.state.blockStatus, FellowshipBlockStatus.failure);
      expect(bloc.state.errorMessage, 'network down');
    },
  );
}
