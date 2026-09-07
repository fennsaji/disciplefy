import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/community_repository.dart';
import 'fellowship_settings_event.dart';
import 'fellowship_settings_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// BLoC backing the fellowship settings screen: name/description/posting
/// permission edits plus the mentor-only Discipler preference controls.
///
/// Tracks an [original] (last-saved) and [draft] (in-progress) fellowship so
/// only the fields the mentor actually changed are sent to the server.
class FellowshipSettingsBloc
    extends Bloc<FellowshipSettingsEvent, FellowshipSettingsState> {
  final CommunityRepository _repository;

  FellowshipSettingsBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipSettingsState()) {
    on<FellowshipSettingsLoaded>((e, emit) => emit(state.copyWith(
          original: e.fellowship,
          draft: e.fellowship,
          status: FellowshipSettingsStatus.idle,
        )));
    on<FellowshipSettingsChanged>((e, emit) {
      final d = state.draft;
      if (d == null) return;
      emit(state.copyWith(
        draft: d.copyWith(
          name: e.name,
          description: e.description,
          postingPermission: e.postingPermission,
          disciplerReplyMode: e.disciplerReplyMode,
          disciplerReplyScope: e.disciplerReplyScope,
          disciplerReplyDelayMin: e.disciplerReplyDelayMin,
          disciplerReactEnabled: e.disciplerReactEnabled,
          dailyPostOn: e.dailyPostOn,
          dailyPostFrequencyDays: e.dailyPostFrequencyDays,
          dailyPostAutoAdvance: e.dailyPostAutoAdvance,
          myDisciplerActivityPush: e.disciplerActivityPush,
        ),
      ));
    });
    on<FellowshipSettingsSaveRequested>(_onSave);
  }

  Future<void> _onSave(
    FellowshipSettingsSaveRequested event,
    Emitter<FellowshipSettingsState> emit,
  ) async {
    final o = state.original, d = state.draft;
    if (o == null || d == null) return;
    emit(state.copyWith(status: FellowshipSettingsStatus.saving));

    T? diff<T>(T? a, T? b) => a == b ? null : b;

    final result = await _repository.updateFellowship(
      fellowshipId: d.id,
      name: diff(o.name, d.name),
      description: diff(o.description, d.description),
      postingPermission: diff(o.postingPermission, d.postingPermission),
      disciplerReplyMode: diff(o.disciplerReplyMode, d.disciplerReplyMode),
      disciplerReplyScope: diff(o.disciplerReplyScope, d.disciplerReplyScope),
      disciplerReplyDelayMin:
          diff(o.disciplerReplyDelayMin, d.disciplerReplyDelayMin),
      disciplerReactEnabled:
          diff(o.disciplerReactEnabled, d.disciplerReactEnabled),
      dailyPostOn: diff(o.dailyPostOn, d.dailyPostOn),
      dailyPostFrequencyDays:
          diff(o.dailyPostFrequencyDays, d.dailyPostFrequencyDays),
      dailyPostAutoAdvance:
          diff(o.dailyPostAutoAdvance, d.dailyPostAutoAdvance),
      disciplerActivityPush:
          diff(o.myDisciplerActivityPush, d.myDisciplerActivityPush),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipSettingsStatus.failure,
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (_) => emit(state.copyWith(
        status: FellowshipSettingsStatus.saved,
        original: d,
        clearErrorMessage: true,
      )),
    );
  }
}
