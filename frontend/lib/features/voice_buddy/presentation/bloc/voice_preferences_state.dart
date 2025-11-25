import 'package:equatable/equatable.dart';

import '../../domain/entities/voice_preferences_entity.dart';

/// States for voice preferences BLoC.
abstract class VoicePreferencesState extends Equatable {
  const VoicePreferencesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before preferences are loaded.
class VoicePreferencesInitial extends VoicePreferencesState {
  const VoicePreferencesInitial();
}

/// Loading preferences.
class VoicePreferencesLoading extends VoicePreferencesState {
  const VoicePreferencesLoading();
}

/// Preferences loaded successfully.
class VoicePreferencesLoaded extends VoicePreferencesState {
  final VoicePreferencesEntity preferences;
  final bool hasUnsavedChanges;

  const VoicePreferencesLoaded({
    required this.preferences,
    this.hasUnsavedChanges = false,
  });

  @override
  List<Object?> get props => [preferences, hasUnsavedChanges];

  VoicePreferencesLoaded copyWith({
    VoicePreferencesEntity? preferences,
    bool? hasUnsavedChanges,
  }) {
    return VoicePreferencesLoaded(
      preferences: preferences ?? this.preferences,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

/// Saving preferences.
class VoicePreferencesSaving extends VoicePreferencesState {
  final VoicePreferencesEntity preferences;

  const VoicePreferencesSaving(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Preferences saved successfully.
class VoicePreferencesSaved extends VoicePreferencesState {
  final VoicePreferencesEntity preferences;

  const VoicePreferencesSaved(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Error loading or saving preferences.
class VoicePreferencesError extends VoicePreferencesState {
  final String message;
  final VoicePreferencesEntity? previousPreferences;

  const VoicePreferencesError({
    required this.message,
    this.previousPreferences,
  });

  @override
  List<Object?> get props => [message, previousPreferences];
}
