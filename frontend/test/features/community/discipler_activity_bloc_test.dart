import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/discipler_activity_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_state.dart';
import 'discipler_activity_bloc_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repo;

  const draft = DisciplerActivityEntity(
    id: 'a1',
    kind: 'draft',
    commentId: 'c1',
    summary: 'Drafted a reply',
    createdAt: '2026-09-01T00:00:00Z',
    commentContent: 'Here is an answer',
    commentPending: true,
  );

  const reply = DisciplerActivityEntity(
    id: 'a2',
    kind: 'reply',
    postId: 'p1',
    summary: 'Replied to a question',
    createdAt: '2026-09-02T00:00:00Z',
  );

  setUp(() => repo = MockCommunityRepository());

  blocTest<DisciplerActivityBloc, DisciplerActivityState>(
    'load returns two items',
    build: () {
      when(repo.getDisciplerActivity(
        fellowshipId: 'f1',
      )).thenAnswer((_) async => const Right(DisciplerActivityPage(
            items: [draft, reply],
            hasMore: false,
          )));
      return DisciplerActivityBloc(repository: repo);
    },
    act: (b) => b.add(const DisciplerActivityLoadRequested(fellowshipId: 'f1')),
    expect: () => [
      predicate<DisciplerActivityState>(
          (s) => s.status == DisciplerActivityStatus.loading),
      predicate<DisciplerActivityState>((s) =>
          s.status == DisciplerActivityStatus.success && s.items.length == 2),
    ],
  );

  blocTest<DisciplerActivityBloc, DisciplerActivityState>(
    'review with approve flips commentPending false',
    build: () {
      when(repo.getDisciplerActivity(fellowshipId: 'f1'))
          .thenAnswer((_) async => const Right(DisciplerActivityPage(
                items: [draft],
                hasMore: false,
              )));
      when(repo.approveDisciplerComment('c1'))
          .thenAnswer((_) async => const Right(null));
      return DisciplerActivityBloc(repository: repo);
    },
    act: (b) => b
      ..add(const DisciplerActivityLoadRequested(fellowshipId: 'f1'))
      ..add(const DisciplerActivityReviewed(commentId: 'c1', approve: true)),
    skip: 2,
    verify: (b) {
      expect(b.state.items.single.commentPending, false);
    },
  );

  blocTest<DisciplerActivityBloc, DisciplerActivityState>(
    'delete removes the item',
    build: () {
      when(repo.getDisciplerActivity(fellowshipId: 'f1'))
          .thenAnswer((_) async => const Right(DisciplerActivityPage(
                items: [reply],
                hasMore: false,
              )));
      when(repo.deletePost('p1')).thenAnswer((_) async => const Right(null));
      return DisciplerActivityBloc(repository: repo);
    },
    act: (b) => b
      ..add(const DisciplerActivityLoadRequested(fellowshipId: 'f1'))
      ..add(const DisciplerActivityDeleteRequested(
          activityId: 'a2', postId: 'p1')),
    skip: 2,
    verify: (b) {
      expect(b.state.items, isEmpty);
    },
  );
}
