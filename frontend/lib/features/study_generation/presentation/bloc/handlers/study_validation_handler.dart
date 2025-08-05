import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/input_validation_service.dart';
import '../study_event.dart';
import '../study_state.dart';

/// Handler for input validation logic.
///
/// This class encapsulates all the business logic related to validating
/// user input for study guide generation, following the Single Responsibility Principle.
class StudyValidationHandler {
  final InputValidationService _validationService;

  const StudyValidationHandler({
    required InputValidationService validationService,
  }) : _validationService = validationService;

  /// Handles input validation request.
  ///
  /// This method validates the input using the domain validation service
  /// and emits the appropriate validation state.
  void handleValidateInput(
    ValidateInputRequested event,
    Emitter<StudyState> emit,
  ) {
    final result = _validationService.validateInput(
      event.input,
      event.inputType,
    );

    emit(StudyInputValidation(
      isValid: result.isValid,
      input: event.input,
      inputType: event.inputType,
      errorMessage: result.errorMessage,
    ));
  }
}
