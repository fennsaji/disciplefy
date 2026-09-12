import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';

import 'shared_link_not_a_member_test.mocks.dart';

/// A shared post link reaches people who are not in the fellowship. The app
/// already had a screen for that — an offer to join — but nobody ever saw it:
/// the 403 was thrown as an AuthorizationException and then swallowed by a bare
/// `catch` that re-wrapped it as a ServerException. So a non-member opening a
/// link got "Something went wrong" and a red "Server error occurred" toast over
/// a half-drawn fellowship, instead of being asked whether they wanted to join.
///
/// These pin the distinction that failure depended on: not-a-member is an
/// AuthorizationFailure, and it is never reported as a server fault.
@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  setUp(() => repository = MockCommunityRepository());

  FellowshipMembersBloc buildBloc() =>
      FellowshipMembersBloc(repository: repository);

  test('a non-member roster load raises no error message to show the user',
      () async {
    when(repository.getFellowshipMembers(any)).thenAnswer(
      (_) async => const Left(AuthorizationFailure(message: 'Not a member')),
    );

    final bloc = buildBloc();
    bloc.add(const FellowshipMembersLoadRequested(fellowshipId: 'f-1'));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.status, FellowshipMembersStatus.failure);
    // The feed says "join to see this" — a red server-error toast on top of
    // that offer is what this test exists to prevent.
    expect(bloc.state.errorMessage, isNull);
    await bloc.close();
  });

  test('a genuine server failure still tells the user something went wrong',
      () async {
    when(repository.getFellowshipMembers(any)).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'boom')),
    );

    final bloc = buildBloc();
    bloc.add(const FellowshipMembersLoadRequested(fellowshipId: 'f-1'));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.status, FellowshipMembersStatus.failure);
    expect(bloc.state.errorMessage, isNotNull);
    await bloc.close();
  });
}
