import 'package:equatable/equatable.dart';

import '../../domain/entities/voice_preferences_entity.dart';

/// Events for voice preferences BLoC.
abstract class VoicePreferencesEvent extends Equatable {
  const VoicePreferencesEvent();

  @override
  List<Object?> get props => [];
}

/// Load user voice preferences.
class LoadVoicePreferences extends VoicePreferencesEvent {
  const LoadVoicePreferences();
}

/// Update voice preferences.
class UpdateVoicePreferences extends VoicePreferencesEvent {
  final VoicePreferencesEntity preferences;

  const UpdateVoicePreferences(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Reset preferences to defaults.
class ResetVoicePreferences extends VoicePreferencesEvent {
  const ResetVoicePreferences();
}

/// Update a single preference field.
class UpdatePreferenceField extends VoicePreferencesEvent {
  final String field;
  final dynamic value;

  const UpdatePreferenceField({
    required this.field,
    required this.value,
  });

  @override
  List<Object?> get props => [field, value];
}
