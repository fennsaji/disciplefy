import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_stats.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';

class _MockRepository extends Mock implements GamificationRepository {}

class _MockLanguageService extends Mock implements LanguagePreferenceService {}

/// Auth provider whose state the test drives, standing in for the session
/// being restored on a cold start.
class _FakeAuthStateProvider extends AuthStateProvider {
  auth_states.AuthState _state = const auth_states.AuthInitialState();

  @override
  auth_states.AuthState get currentState => _state;

  @override
  String? get userId => _state is auth_states.AuthenticatedState
      ? (_state as auth_states.AuthenticatedState).user.id
      : null;

  void emitState(auth_states.AuthState state) {
    _state = state;
    notifyListeners();
  }
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-01T00:00:00Z',
    );

void main() {
  late _MockRepository repository;
  late _MockLanguageService language;
  late _FakeAuthStateProvider auth;

  setUp(() {
    repository = _MockRepository();
    language = _MockLanguageService();
    auth = _FakeAuthStateProvider();
    when(() => language.getSelectedLanguage())
        .thenAnswer((_) async => AppLanguage.english);
    when(() => repository.getUserStats(any()))
        .thenAnswer((_) async => const Right(UserStats(totalXp: 120)));
    when(() => repository.getUserAchievements(any(), any()))
        .thenAnswer((_) async => const Right([]));
  });

  GamificationBloc build() => GamificationBloc(
        repository: repository,
        authStateProvider: auth,
        languagePreferenceService: language,
      );

  test('waits for the restored session and then loads without a retry',
      () async {
    final bloc = build();
    bloc.add(const LoadGamificationStats());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, isNot(GamificationStatus.error));
    verifyNever(() => repository.getUserStats(any()));

    auth.emitState(const auth_states.AuthLoadingState());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, isNot(GamificationStatus.error));

    auth.emitState(auth_states.AuthenticatedState(user: _user('user-1')));
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<GamificationState>(
          (s) => s.status == GamificationStatus.loaded)),
    );
    expect(bloc.state.stats?.totalXp, 120);
    verify(() => repository.getUserStats('user-1')).called(1);
    await bloc.close();
  });

  test('reports the error when the session resolves to signed out', () async {
    final bloc = build();
    bloc.add(const LoadGamificationStats());
    await Future<void>.delayed(Duration.zero);

    auth.emitState(const auth_states.UnauthenticatedState());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<GamificationState>(
          (s) => s.status == GamificationStatus.error)),
    );
    verifyNever(() => repository.getUserStats(any()));
    await bloc.close();
  });

  test('loads straight away when the user is already signed in', () async {
    auth.emitState(auth_states.AuthenticatedState(user: _user('user-2')));
    final bloc = build();
    bloc.add(const LoadGamificationStats());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<GamificationState>(
          (s) => s.status == GamificationStatus.loaded)),
    );
    verify(() => repository.getUserStats('user-2')).called(1);
    await bloc.close();
  });
}
