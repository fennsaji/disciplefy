import 'package:equatable/equatable.dart';

import '../../../domain/entities/fellowship_entity.dart';

/// Base class for all [FellowshipSettingsBloc] events.
abstract class FellowshipSettingsEvent extends Equatable {
  const FellowshipSettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Seeds the bloc with the [fellowship] loaded via the router's `extra`.
class FellowshipSettingsLoaded extends FellowshipSettingsEvent {
  final FellowshipEntity fellowship;

  const FellowshipSettingsLoaded(this.fellowship);

  @override
  List<Object?> get props => [fellowship];
}

/// Applies a partial edit to the in-progress draft. Only non-null fields are
/// changed; all others keep their current draft value.
class FellowshipSettingsChanged extends FellowshipSettingsEvent {
  final String? name;
  final String? description;
  final String? postingPermission;
  final String? disciplerReplyMode;
  final String? disciplerReplyScope;
  final int? disciplerReplyDelayMin;
  final bool? disciplerReactEnabled;
  final bool? dailyPostOn;
  final int? dailyPostFrequencyDays;
  final bool? dailyPostAutoAdvance;
  final bool? disciplerActivityPush;

  const FellowshipSettingsChanged({
    this.name,
    this.description,
    this.postingPermission,
    this.disciplerReplyMode,
    this.disciplerReplyScope,
    this.disciplerReplyDelayMin,
    this.disciplerReactEnabled,
    this.dailyPostOn,
    this.dailyPostFrequencyDays,
    this.dailyPostAutoAdvance,
    this.disciplerActivityPush,
  });

  @override
  List<Object?> get props => [
        name,
        description,
        postingPermission,
        disciplerReplyMode,
        disciplerReplyScope,
        disciplerReplyDelayMin,
        disciplerReactEnabled,
        dailyPostOn,
        dailyPostFrequencyDays,
        dailyPostAutoAdvance,
        disciplerActivityPush,
      ];
}

/// Saves the draft's changed fields via [CommunityRepository.updateFellowship].
class FellowshipSettingsSaveRequested extends FellowshipSettingsEvent {
  const FellowshipSettingsSaveRequested();
}
