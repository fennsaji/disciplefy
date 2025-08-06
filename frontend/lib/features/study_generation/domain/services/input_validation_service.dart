import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validation_utils.dart';
import '../usecases/generate_study_guide.dart';

/// Domain service for input validation logic.
///
/// This service encapsulates all business rules for validating
/// study generation inputs, providing a single source of truth
/// for validation logic across the application.
class InputValidationService {
  /// Regular expression pattern for scripture references.
  ///
  /// Matches formats like:
  /// - John 3:16
  /// - 1 Corinthians 13:4-7
  /// - Psalm 23
  /// - Genesis 1:1-2:3
  static final RegExp _scripturePattern = RegExp(
    r'^[1-3]?\s*[a-zA-Z]+\s+\d+(?::\d+(?:-\d+)?)?$',
  );

  /// Validates input text based on type and returns validation result.
  ///
  /// [input] The input text to validate
  /// [inputType] The type of input ('scripture' or 'topic')
  ///
  /// Returns [ValidationResult] containing validity status and error message.
  ValidationResult validateInput(String input, String inputType) {
    // Use ValidationUtils for consistent empty check
    if (ValidationUtils.isNullOrEmptyString(input)) {
      return const ValidationResult(
        isValid: false,
      );
    }

    final trimmedInput = input.trim();

    // Validate based on input type
    if (inputType == 'scripture') {
      return _validateScriptureReference(trimmedInput);
    } else if (inputType == 'topic') {
      return _validateTopic(trimmedInput);
    } else {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Invalid input type',
      );
    }
  }

  /// Validates scripture reference format.
  ValidationResult _validateScriptureReference(String input) {
    // Use ValidationUtils for length validation
    if (!ValidationUtils.isValidLength(
      input,
      minLength: AppConstants.MIN_INPUT_LENGTH,
      maxLength: AppConstants.MAX_VERSE_LENGTH,
    )) {
      if (input.length < AppConstants.MIN_INPUT_LENGTH) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Please enter at least 2 characters',
        );
      } else {
        return const ValidationResult(
          isValid: false,
          errorMessage:
              'Verse reference cannot exceed ${AppConstants.MAX_VERSE_LENGTH} characters',
        );
      }
    }

    // Check format with regex
    if (!_scripturePattern.hasMatch(input)) {
      return const ValidationResult(
        isValid: false,
        errorMessage:
            'Please enter a valid scripture reference (e.g., John 3:16)',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Validates topic input.
  ValidationResult _validateTopic(String input) {
    // Use ValidationUtils for length validation
    if (!ValidationUtils.isValidLength(
      input,
      minLength: AppConstants.MIN_INPUT_LENGTH,
      maxLength: AppConstants.MAX_TOPIC_LENGTH,
    )) {
      if (input.length < AppConstants.MIN_INPUT_LENGTH) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Please enter at least 2 characters',
        );
      } else {
        return const ValidationResult(
          isValid: false,
          errorMessage:
              'Topic cannot exceed ${AppConstants.MAX_TOPIC_LENGTH} characters',
        );
      }
    }

    return const ValidationResult(isValid: true);
  }

  /// Creates parameters object with validation.
  ///
  /// This method combines validation with parameter creation,
  /// ensuring that only valid parameters can be created.
  ///
  /// Returns Either a [ValidationFailure] or valid parameters.
  Either<ValidationFailure, StudyGenerationParams> createValidatedParams({
    required String input,
    required String inputType,
    String? language,
  }) {
    final result = validateInput(input, inputType);

    if (!result.isValid && result.errorMessage != null) {
      return Left(ValidationFailure(
        message: result.errorMessage!,
      ));
    }

    if (input.trim().isEmpty) {
      return const Left(ValidationFailure(
        message: 'Input cannot be empty',
        code: 'EMPTY_INPUT',
      ));
    }

    return Right(StudyGenerationParams(
      input: input.trim(),
      inputType: inputType,
      language: language,
    ));
  }
}

/// Result of input validation.
class ValidationResult {
  /// Whether the input is valid.
  final bool isValid;

  /// Error message if invalid (null for valid inputs or empty input).
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
