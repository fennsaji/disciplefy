import 'package:dartz/dartz.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MockReset extends Mock implements ResetLearningProgress {}

LearningPath _path(String id, {bool guestAccessible = false}) => LearningPath(
      id: id,
      slug: id,
      title: 'Path $id',
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      guestAccessible: guestAccessible,
      topicsCount: 5,
    );

void main() {
  late _MockGuest guest;
  late _MockFlags flags;

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    guest = _MockGuest();
    flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() async => sl.reset());

  group('isGuestLockedPath', () {
    test('locked only for a guest on a path that is not guest-accessible', () {
      expect(isGuestLockedPath(_path('x'), guest: true), isTrue);
      expect(isGuestLockedPath(_path('x', guestAccessible: true), guest: true),
          isFalse);
      expect(isGuestLockedPath(_path('x'), guest: false), isFalse);
    });

    test('follows the session by default, not the guest_mode flag', () {
      expect(isGuestLockedPath(_path('x')), isTrue);
      // Switching guest mode off stops new guests only; an existing guest
      // is still limited to their path.
      when(() => flags.guestMode).thenReturn(false);
      expect(isGuestLockedPath(_path('x')), isTrue);
      when(() => guest.isGuest).thenReturn(false);
      expect(isGuestLockedPath(_path('x')), isFalse);
    });
  });

  Widget rows(List<LearningPath> paths, void Function(LearningPath) onOpen) =>
      welcomeApp(
        screen: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                for (final p in paths)
                  PathListRow(
                    path: p,
                    onTap: () =>
                        guestPathGate(context, p, () async => onOpen(p)),
                  ),
              ],
            ),
          ),
        ),
      );

  testWidgets('a locked path shows the lock; its tap opens the sheet',
      (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(rows(
      [_path('locked'), _path('mine', guestAccessible: true)],
      (p) => opened.add(p.id),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guest_path_lock_locked')), findsOneWidget);
    expect(find.byKey(const Key('guest_path_lock_mine')), findsNothing);
    // Every existing element is still there.
    expect(find.text('Path locked'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

    await tester.tap(find.text('Path locked'));
    await tester.pumpAndSettle();
    expect(find.text('Your next path needs an account'), findsOneWidget);
    expect(opened, isEmpty);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Path mine'));
    await tester.pumpAndSettle();
    expect(opened, ['mine']);
  });

  testWidgets('signing up from the sheet opens the path', (tester) async {
    when(() => guest.linkGoogle()).thenAnswer((_) async => LinkOutcome.linked);
    final opened = <String>[];
    await tester.pumpWidget(rows([_path('locked')], (p) => opened.add(p.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Path locked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(opened, ['locked']);
  });

  testWidgets('a full account sees no lock', (tester) async {
    when(() => guest.isGuest).thenReturn(false);
    final opened = <String>[];
    await tester.pumpWidget(rows([_path('any')], (p) => opened.add(p.id)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guest_path_lock_any')), findsNothing);
    await tester.tap(find.text('Path any'));
    await tester.pumpAndSettle();
    expect(opened, ['any']);
  });

  group('enrol refused for a guest', () {
    late _MockPaths repo;
    setUp(() => repo = _MockPaths());

    blocTest<LearningPathsBloc, LearningPathsState>(
      'carries the server reason',
      build: () {
        when(() => repo.enrollInPath(pathId: 'p2')).thenAnswer((_) async =>
            const Left(AccountRequiredFailure(reason: 'second_path')));
        return LearningPathsBloc(
            repository: repo, resetLearningProgress: _MockReset());
      },
      act: (bloc) => bloc.add(const EnrollInLearningPath(pathId: 'p2')),
      skip: 1,
      expect: () => [
        isA<LearningPathsError>()
            .having((s) => s.accountReason, 'accountReason', 'second_path'),
      ],
    );

    blocTest<LearningPathsBloc, LearningPathsState>(
      'other failures have no reason',
      build: () {
        when(() => repo.enrollInPath(pathId: 'p2')).thenAnswer(
            (_) async => const Left(NetworkFailure(message: 'off')));
        return LearningPathsBloc(
            repository: repo, resetLearningProgress: _MockReset());
      },
      act: (bloc) => bloc.add(const EnrollInLearningPath(pathId: 'p2')),
      skip: 1,
      expect: () => [
        isA<LearningPathsError>()
            .having((s) => s.accountReason, 'accountReason', isNull),
      ],
    );
  });
}
