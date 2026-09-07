import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';

import 'fellowship_members_roles_test.mocks.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  FellowshipMemberEntity member(String userId, String role) =>
      FellowshipMemberEntity(
        userId: userId,
        displayName: userId,
        role: role,
        joinedAt: '2026-08-10T00:00:00.000Z',
        isMuted: false,
      );

  final seeded = FellowshipMembersState.initial().copyWith(
    status: FellowshipMembersStatus.success,
    fellowshipId: 'f1',
    members: [member('mentor-1', 'mentor'), member('rahul', 'member')],
  );

  setUp(() {
    repository = MockCommunityRepository();
  });

  blocTest<FellowshipMembersBloc, FellowshipMembersState>(
    'promoting a member flips their role to mentor',
    build: () {
      when(repository.promoteMember(
        fellowshipId: anyNamed('fellowshipId'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => const Right(null));
      return FellowshipMembersBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) =>
        bloc.add(const FellowshipMemberPromoteRequested(userId: 'rahul')),
    verify: (bloc) {
      expect(bloc.state.members.firstWhere((m) => m.userId == 'rahul').role,
          'mentor');
    },
  );

  blocTest<FellowshipMembersBloc, FellowshipMembersState>(
    'demoting a mentor flips their role back to member',
    build: () {
      when(repository.demoteMember(
        fellowshipId: anyNamed('fellowshipId'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => const Right(null));
      return FellowshipMembersBloc(repository: repository);
    },
    seed: () => seeded.copyWith(
      members: [member('mentor-1', 'mentor'), member('rahul', 'mentor')],
    ),
    act: (bloc) =>
        bloc.add(const FellowshipMemberDemoteRequested(userId: 'rahul')),
    verify: (bloc) {
      expect(bloc.state.members.firstWhere((m) => m.userId == 'rahul').role,
          'member');
    },
  );

  blocTest<FellowshipMembersBloc, FellowshipMembersState>(
    'promote failure sets a sanitized error message',
    build: () {
      when(repository.promoteMember(
        fellowshipId: anyNamed('fellowshipId'),
        userId: anyNamed('userId'),
      )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'db exploded')));
      return FellowshipMembersBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) =>
        bloc.add(const FellowshipMemberPromoteRequested(userId: 'rahul')),
    verify: (bloc) {
      expect(bloc.state.members.firstWhere((m) => m.userId == 'rahul').role,
          'member');
      expect(bloc.state.errorMessage, isNot(contains('db exploded')));
      expect(
          bloc.state.errorMessage,
          ErrorMessageSanitizer.sanitize(
              const ServerFailure(message: 'db exploded')));
    },
  );
}
