import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'fellowship_not_a_member_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  setUp(() => repository = MockCommunityRepository());

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'opening a link to a fellowship you have not joined offers a way in',
    build: () {
      when(repository.getFellowshipPosts(
        fellowshipId: anyNamed('fellowshipId'),
        cursor: anyNamed('cursor'),
        limit: anyNamed('limit'),
        topicId: anyNamed('topicId'),
      )).thenAnswer(
        (_) async => const Left(AuthorizationFailure(message: 'Not a member')),
      );
      return FellowshipFeedBloc(repository: repository);
    },
    act: (bloc) =>
        bloc.add(const FellowshipFeedLoadRequested(fellowshipId: 'f1')),
    verify: (bloc) {
      // Drives the join screen instead of the generic error.
      expect(bloc.state.notAMember, true);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'an ordinary failure is still an error, not a join prompt',
    build: () {
      when(repository.getFellowshipPosts(
        fellowshipId: anyNamed('fellowshipId'),
        cursor: anyNamed('cursor'),
        limit: anyNamed('limit'),
        topicId: anyNamed('topicId'),
      )).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'boom')),
      );
      return FellowshipFeedBloc(repository: repository);
    },
    act: (bloc) =>
        bloc.add(const FellowshipFeedLoadRequested(fellowshipId: 'f1')),
    verify: (bloc) {
      expect(bloc.state.notAMember, false);
      expect(bloc.state.status, FellowshipFeedStatus.failure);
    },
  );
}
