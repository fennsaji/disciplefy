import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_state.dart';
import 'fellowship_settings_bloc_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repo;
  const f = FellowshipEntity(
      id: 'f',
      name: 'N',
      memberCount: 1,
      userRole: 'mentor',
      joinedAt: 'j',
      createdAt: 'c',
      disciplerAllowed: true);
  setUp(() => repo = MockCommunityRepository());

  blocTest<FellowshipSettingsBloc, FellowshipSettingsState>(
    'saves only changed Discipler fields',
    build: () {
      when(repo.updateFellowship(
        fellowshipId: 'f',
        disciplerReplyMode: 'review',
        disciplerReplyDelayMin: 30,
      )).thenAnswer((_) async => const Right(null));
      return FellowshipSettingsBloc(repository: repo);
    },
    act: (b) => b
      ..add(const FellowshipSettingsLoaded(f))
      ..add(const FellowshipSettingsChanged(
          disciplerReplyMode: 'review', disciplerReplyDelayMin: 30))
      ..add(const FellowshipSettingsSaveRequested()),
    verify: (b) {
      expect(b.state.status, FellowshipSettingsStatus.saved);
      expect(b.state.isDirty, false);
      expect(b.state.original!.disciplerReplyMode, 'review');
    },
  );

  blocTest<FellowshipSettingsBloc, FellowshipSettingsState>(
    'saves changed daily post frequency and auto-advance prefs',
    build: () {
      when(repo.updateFellowship(
        fellowshipId: 'f',
        dailyPostFrequencyDays: 7,
        dailyPostAutoAdvance: false,
      )).thenAnswer((_) async => const Right(null));
      return FellowshipSettingsBloc(repository: repo);
    },
    act: (b) => b
      ..add(const FellowshipSettingsLoaded(f))
      ..add(const FellowshipSettingsChanged(
          dailyPostFrequencyDays: 7, dailyPostAutoAdvance: false))
      ..add(const FellowshipSettingsSaveRequested()),
    verify: (b) {
      expect(b.state.status, FellowshipSettingsStatus.saved);
      expect(b.state.isDirty, false);
      expect(b.state.original!.dailyPostFrequencyDays, 7);
      expect(b.state.original!.dailyPostAutoAdvance, false);
    },
  );
}
