import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../data/services/save_guide_api_service.dart';
import '../../../../auth/data/services/auth_service.dart';
import '../study_event.dart';
import '../study_state.dart';

/// Handler for study guide save operations.
/// 
/// This class encapsulates all the business logic related to saving
/// and unsaving study guides, following the Single Responsibility Principle.
class StudySaveHandler {
  final SaveGuideApiService _saveGuideService;
  final AuthService _authService;

  const StudySaveHandler({
    required SaveGuideApiService saveGuideService,
    required AuthService authService,
  })  : _saveGuideService = saveGuideService,
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
          message: 'You need to be signed in to save study guides. Would you like to sign in now?',
        ));
      }
    } catch (e) {
      // Handle authentication check failure
      emit(StudyAuthenticationRequired(
        guideId: event.guideId,
        save: event.save,
        message: 'Unable to verify authentication status. Please try signing in.',
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
}