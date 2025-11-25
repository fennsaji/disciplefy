import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/voice_preferences_entity.dart';
import '../../domain/repositories/voice_buddy_repository.dart';
import 'voice_preferences_event.dart';
import 'voice_preferences_state.dart';

/// BLoC for managing voice preferences.
class VoicePreferencesBloc
    extends Bloc<VoicePreferencesEvent, VoicePreferencesState> {
  final VoiceBuddyRepository _repository;

  VoicePreferencesBloc({
    required VoiceBuddyRepository repository,
  })  : _repository = repository,
        super(const VoicePreferencesInitial()) {
    on<LoadVoicePreferences>(_onLoadPreferences);
    on<UpdateVoicePreferences>(_onUpdatePreferences);
    on<ResetVoicePreferences>(_onResetPreferences);
    on<UpdatePreferenceField>(_onUpdatePreferenceField);
  }

  Future<void> _onLoadPreferences(
    LoadVoicePreferences event,
    Emitter<VoicePreferencesState> emit,
  ) async {
    emit(const VoicePreferencesLoading());

    final result = await _repository.getPreferences();

    result.fold(
      (failure) => emit(VoicePreferencesError(message: failure.message)),
      (preferences) => emit(VoicePreferencesLoaded(preferences: preferences)),
    );
  }

  Future<void> _onUpdatePreferences(
    UpdateVoicePreferences event,
    Emitter<VoicePreferencesState> emit,
  ) async {
    final currentState = state;
    if (currentState is VoicePreferencesLoaded) {
      emit(VoicePreferencesSaving(event.preferences));

      final result = await _repository.updatePreferences(event.preferences);

      result.fold(
        (failure) => emit(VoicePreferencesError(
          message: failure.message,
          previousPreferences: currentState.preferences,
        )),
        (preferences) {
          emit(VoicePreferencesSaved(preferences));
          emit(VoicePreferencesLoaded(preferences: preferences));
        },
      );
    }
  }

  Future<void> _onResetPreferences(
    ResetVoicePreferences event,
    Emitter<VoicePreferencesState> emit,
  ) async {
    final currentState = state;
    if (currentState is VoicePreferencesLoaded) {
      emit(const VoicePreferencesLoading());

      final result = await _repository.resetPreferences();

      result.fold(
        (failure) => emit(VoicePreferencesError(
          message: failure.message,
          previousPreferences: currentState.preferences,
        )),
        (preferences) {
          emit(VoicePreferencesSaved(preferences));
          emit(VoicePreferencesLoaded(preferences: preferences));
        },
      );
    }
  }

  void _onUpdatePreferenceField(
    UpdatePreferenceField event,
    Emitter<VoicePreferencesState> emit,
  ) {
    final currentState = state;
    if (currentState is VoicePreferencesLoaded) {
      final preferences = currentState.preferences;

      // Update the specific field
      VoicePreferencesEntity updatedPreferences;

      switch (event.field) {
        case 'preferredLanguage':
          updatedPreferences =
              preferences.copyWith(preferredLanguage: event.value as String);
          break;
        case 'autoDetectLanguage':
          updatedPreferences =
              preferences.copyWith(autoDetectLanguage: event.value as bool);
          break;
        case 'ttsVoiceGender':
          updatedPreferences =
              preferences.copyWith(ttsVoiceGender: event.value as VoiceGender);
          break;
        case 'speakingRate':
          updatedPreferences =
              preferences.copyWith(speakingRate: event.value as double);
          break;
        case 'pitch':
          updatedPreferences =
              preferences.copyWith(pitch: event.value as double);
          break;
        case 'autoPlayResponse':
          updatedPreferences =
              preferences.copyWith(autoPlayResponse: event.value as bool);
          break;
        case 'showTranscription':
          updatedPreferences =
              preferences.copyWith(showTranscription: event.value as bool);
          break;
        case 'continuousMode':
          updatedPreferences =
              preferences.copyWith(continuousMode: event.value as bool);
          break;
        case 'useStudyContext':
          updatedPreferences =
              preferences.copyWith(useStudyContext: event.value as bool);
          break;
        case 'citeScriptureReferences':
          updatedPreferences = preferences.copyWith(
              citeScriptureReferences: event.value as bool);
          break;
        case 'notifyDailyQuotaReached':
          updatedPreferences = preferences.copyWith(
              notifyDailyQuotaReached: event.value as bool);
          break;
        default:
          updatedPreferences = preferences;
      }

      emit(currentState.copyWith(
        preferences: updatedPreferences,
        hasUnsavedChanges: true,
      ));
    }
  }
}
