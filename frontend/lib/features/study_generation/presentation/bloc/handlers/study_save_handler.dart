import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../domain/usecases/manage_personal_notes.dart';
import '../../../data/services/save_guide_api_service.dart';
import '../../../../auth/data/services/auth_service.dart';
import '../study_event.dart';
import '../study_state.dart';

/// Handler for study guide save operations.
///
/// This class encapsulates all the business logic related to saving
/// and unsaving study guides, including personal notes operations,
/// following the Single Responsibility Principle.
class StudySaveHandler {
  final SaveGuideApiService _saveGuideService;
  final ManagePersonalNotesUseCase _managePersonalNotes;
  final AuthService _authService;

  const StudySaveHandler({
    required SaveGuideApiService saveGuideService,
    required ManagePersonalNotesUseCase managePersonalNotes,
    required AuthService authService,
  })  : _saveGuideService = saveGuideService,
        _managePersonalNotes = managePersonalNotes,
        _authService = authService;

  /// Handles the save study guide request.
  ///
  /// This method calls the save API service and emits appropriate states.
  Future<void> handleSaveStudyGuide(
    SaveStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) async {
    emit(StudySaveInProgress(guideId: event.guideId));

    try {
      final success = await _saveGuideService.toggleSaveGuide(
        guideId: event.guideId,
        save: event.save,
      );

      if (success) {
        emit(StudySaveSuccess(
          guideId: event.guideId,
          saved: event.save,
          message: event.save
              ? 'Study guide saved successfully!'
              : 'Study guide removed from saved!',
        ));
      } else {
        emit(StudySaveFailure(
          guideId: event.guideId,
          failure: const ServerFailure(
            message: 'Save operation returned false',
            code: 'SAVE_OPERATION_FAILED',
          ),
        ));
      }
    } on AuthenticationException catch (e) {
      emit(StudySaveFailure(
        guideId: event.guideId,
        failure: AuthenticationFailure(
          message: e.message,
          code: e.code,
        ),
        isRetryable: false,
      ));
    } on ServerException catch (e) {
      _handleServerException(e, event, emit);
    } on NetworkException catch (e) {
      emit(StudySaveFailure(
        guideId: event.guideId,
        failure: NetworkFailure(
          message: e.message,
          code: e.code,
        ),
      ));
    } catch (e) {
      emit(StudySaveFailure(
        guideId: event.guideId,
        failure: ClientFailure(
          message: 'An unexpected error occurred while saving',
          code: 'SAVE_UNEXPECTED_ERROR',
          context: {'error': e.toString()},
        ),
      ));
    }
  }

  /// Handles the authentication check request.
  ///
  /// This method checks if the user is authenticated and either proceeds
  /// with the save operation or requests authentication.
  Future<void> handleCheckAuthentication(
    CheckAuthenticationRequested event,
    Emitter<StudyState> emit,
    void Function(StudyEvent) addEvent,
  ) async {
    try {
      final isAuthenticated = await _authService.isAuthenticatedAsync();

      if (isAuthenticated) {
        // User is authenticated, proceed with save operation
        addEvent(SaveStudyGuideRequested(
          guideId: event.guideId,
          save: event.save,
        ));
      } else {
        // User needs to authenticate
        emit(StudyAuthenticationRequired(
          guideId: event.guideId,
          save: event.save,
          message:
              'You need to be signed in to save study guides. Would you like to sign in now?',
        ));
      }
    } catch (e) {
      // Handle authentication check failure
      emit(StudyAuthenticationRequired(
        guideId: event.guideId,
        save: event.save,
        message:
            'Unable to verify authentication status. Please try signing in.',
      ));
    }
  }

  /// Handles server exceptions with specific logic for different error codes.
  void _handleServerException(
    ServerException e,
    SaveStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) {
    if (e.code == 'ALREADY_SAVED') {
      emit(StudySaveSuccess(
        guideId: event.guideId,
        saved: true,
        message: 'This study guide is already saved!',
      ));
    } else {
      emit(StudySaveFailure(
        guideId: event.guideId,
        failure: ServerFailure(
          message: e.message,
          code: e.code,
        ),
        isRetryable: e.code != 'NOT_FOUND',
      ));
    }
  }

  /// Handles the enhanced save study guide request with personal notes.
  ///
  /// This method performs both study guide saving and personal notes operations
  /// in sequence, providing detailed feedback about each operation's success.
  Future<void> handleEnhancedSaveStudyGuide(
    EnhancedSaveStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) async {
    emit(StudyEnhancedSaveInProgress(
      guideId: event.guideId,
      currentStep: 'Saving study guide...',
      progress: 0.0,
    ));

    bool guideSaveSuccess = false;
    bool notesSaveSuccess = false;
    Failure? guideFailure;
    Failure? notesFailure;

    try {
      // Step 1: Save/unsave the study guide
      emit(StudyEnhancedSaveInProgress(
        guideId: event.guideId,
        currentStep:
            event.save ? 'Saving study guide...' : 'Removing from saved...',
        progress: 0.2,
      ));

      final guideSuccess = await _saveGuideService.toggleSaveGuide(
        guideId: event.guideId,
        save: event.save,
      );

      guideSaveSuccess = guideSuccess;

      // Step 2: Handle personal notes if provided
      if (event.personalNotes != null) {
        emit(StudyEnhancedSaveInProgress(
          guideId: event.guideId,
          currentStep: 'Saving personal notes...',
          progress: 0.6,
        ));

        try {
          final notesResponse = await _managePersonalNotes.updatePersonalNotes(
            studyGuideId: event.guideId,
            notes: event.personalNotes!.trim().isEmpty
                ? null
                : event.personalNotes!.trim(),
          );

          notesSaveSuccess = notesResponse.success;
        } catch (e) {
          notesSaveSuccess = false;
          notesFailure = _mapExceptionToFailure(e, 'personal notes');
        }
      } else {
        // No notes to save, consider it successful
        notesSaveSuccess = true;
      }

      // Step 3: Emit final result
      emit(StudyEnhancedSaveInProgress(
        guideId: event.guideId,
        currentStep: 'Completing operation...',
        progress: 0.9,
      ));

      if (guideSaveSuccess && notesSaveSuccess) {
        // Both operations succeeded
        emit(StudyEnhancedSaveSuccess(
          guideId: event.guideId,
          guideSaved: event.save,
          notesSaved: event.personalNotes != null,
          message:
              _buildSuccessMessage(event.save, event.personalNotes != null),
          savedNotes: event.personalNotes?.trim(),
        ));
      } else {
        // At least one operation failed
        emit(StudyEnhancedSaveFailure(
          guideId: event.guideId,
          guideSaveSuccess: guideSaveSuccess,
          notesSaveSuccess: notesSaveSuccess,
          primaryFailure: guideFailure ??
              notesFailure ??
              const ServerFailure(
                message: 'Unknown error occurred during save operation',
                code: 'UNKNOWN_ERROR',
              ),
        ));
      }
    } on AuthenticationException catch (e) {
      emit(StudyEnhancedSaveFailure(
        guideId: event.guideId,
        guideSaveSuccess: false,
        notesSaveSuccess: false,
        primaryFailure: AuthenticationFailure(
          message: e.message,
          code: e.code,
        ),
        isRetryable: false,
      ));
    } on ServerException catch (e) {
      _handleEnhancedServerException(e, event, emit);
    } on NetworkException catch (e) {
      emit(StudyEnhancedSaveFailure(
        guideId: event.guideId,
        guideSaveSuccess: false,
        notesSaveSuccess: false,
        primaryFailure: NetworkFailure(
          message: e.message,
          code: e.code,
        ),
      ));
    } catch (e) {
      emit(StudyEnhancedSaveFailure(
        guideId: event.guideId,
        guideSaveSuccess: false,
        notesSaveSuccess: false,
        primaryFailure: ClientFailure(
          message: 'An unexpected error occurred during save operation',
          code: 'ENHANCED_SAVE_UNEXPECTED_ERROR',
          context: {'error': e.toString()},
        ),
      ));
    }
  }

  /// Handles the authentication check request for enhanced operations.
  Future<void> handleCheckEnhancedAuthentication(
    CheckEnhancedAuthenticationRequested event,
    Emitter<StudyState> emit,
    void Function(StudyEvent) addEvent,
  ) async {
    try {
      final isAuthenticated = await _authService.isAuthenticatedAsync();

      if (isAuthenticated) {
        // User is authenticated, proceed with enhanced save operation
        addEvent(EnhancedSaveStudyGuideRequested(
          guideId: event.guideId,
          save: event.save,
          personalNotes: event.personalNotes,
        ));
      } else {
        // User needs to authenticate
        emit(StudyEnhancedAuthenticationRequired(
          guideId: event.guideId,
          save: event.save,
          personalNotes: event.personalNotes,
          message:
              'You need to be signed in to save study guides and personal notes.',
        ));
      }
    } catch (e) {
      // Handle authentication check failure
      emit(StudyEnhancedAuthenticationRequired(
        guideId: event.guideId,
        save: event.save,
        personalNotes: event.personalNotes,
        message:
            'Unable to verify authentication status. Please try signing in.',
      ));
    }
  }

  /// Handles personal notes operations independently.
  Future<void> handleUpdatePersonalNotes(
    UpdatePersonalNotesRequested event,
    Emitter<StudyState> emit,
  ) async {
    emit(StudyPersonalNotesInProgress(
      guideId: event.guideId,
      isAutoSave: event.isAutoSave,
    ));

    try {
      final response = await _managePersonalNotes.updatePersonalNotes(
        studyGuideId: event.guideId,
        notes: event.personalNotes?.trim().isEmpty == true
            ? null
            : event.personalNotes?.trim(),
      );

      if (response.success) {
        emit(StudyPersonalNotesSuccess(
          guideId: event.guideId,
          savedNotes: response.notes,
          isAutoSave: event.isAutoSave,
          message:
              event.isAutoSave ? null : 'Personal notes saved successfully!',
        ));
      } else {
        emit(StudyPersonalNotesFailure(
          guideId: event.guideId,
          failure: ServerFailure(
            message: response.message,
            code: 'PERSONAL_NOTES_OPERATION_FAILED',
          ),
          isAutoSave: event.isAutoSave,
        ));
      }
    } on AuthenticationException catch (e) {
      emit(StudyPersonalNotesFailure(
        guideId: event.guideId,
        failure: AuthenticationFailure(
          message: e.message,
          code: e.code,
        ),
        isAutoSave: event.isAutoSave,
        isRetryable: false,
      ));
    } catch (e) {
      final failure = _mapExceptionToFailure(e, 'personal notes');
      emit(StudyPersonalNotesFailure(
        guideId: event.guideId,
        failure: failure,
        isAutoSave: event.isAutoSave,
        isRetryable: failure is! AuthenticationFailure,
      ));
    }
  }

  /// Handles loading personal notes for a study guide.
  Future<void> handleLoadPersonalNotes(
    LoadPersonalNotesRequested event,
    Emitter<StudyState> emit,
  ) async {
    try {
      final response = await _managePersonalNotes.getPersonalNotes(
        studyGuideId: event.guideId,
      );

      emit(StudyPersonalNotesLoaded(
        guideId: event.guideId,
        notes: response.notes,
        loadedAt: DateTime.now(),
      ));
    } catch (e) {
      // Silently handle load failures - personal notes are optional
      emit(StudyPersonalNotesLoaded(
        guideId: event.guideId,
        loadedAt: DateTime.now(),
      ));
    }
  }

  /// Maps exceptions to appropriate failure types.
  Failure _mapExceptionToFailure(dynamic exception, String operation) {
    if (exception is AuthenticationException) {
      return AuthenticationFailure(
        message: exception.message,
        code: exception.code,
      );
    } else if (exception is ServerException) {
      return ServerFailure(
        message: exception.message,
        code: exception.code,
      );
    } else if (exception is NetworkException) {
      return NetworkFailure(
        message: exception.message,
        code: exception.code,
      );
    } else {
      return ClientFailure(
        message: 'An unexpected error occurred while updating $operation',
        code:
            '${operation.toUpperCase().replaceAll(' ', '_')}_UNEXPECTED_ERROR',
        context: {'error': exception.toString()},
      );
    }
  }

  /// Handles server exceptions for enhanced save operations.
  void _handleEnhancedServerException(
    ServerException e,
    EnhancedSaveStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) {
    if (e.code == 'ALREADY_SAVED') {
      emit(StudyEnhancedSaveSuccess(
        guideId: event.guideId,
        guideSaved: true,
        notesSaved: event.personalNotes != null,
        message: 'This study guide is already saved!',
        savedNotes: event.personalNotes?.trim(),
      ));
    } else {
      emit(StudyEnhancedSaveFailure(
        guideId: event.guideId,
        guideSaveSuccess: false,
        notesSaveSuccess: false,
        primaryFailure: ServerFailure(
          message: e.message,
          code: e.code,
        ),
        isRetryable: e.code != 'NOT_FOUND',
      ));
    }
  }

  /// Builds success message based on operations performed.
  String _buildSuccessMessage(bool guideSaved, bool notesIncluded) {
    if (guideSaved && notesIncluded) {
      return 'Study guide and personal notes saved successfully!';
    } else if (guideSaved) {
      return 'Study guide saved successfully!';
    } else if (notesIncluded) {
      return 'Study guide removed from saved, personal notes updated!';
    } else {
      return 'Study guide removed from saved!';
    }
  }
}
