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
///
/// SECURITY FIX: Enhanced with XSS and prompt injection protection
class InputValidationService {
  /// Regular expression pattern for scripture references.
  ///
  /// Matches formats like:
  /// - John 3:16
  /// - 1 Corinthians 13:4-7
  /// - Psalm 23
  /// - Genesis 1:1-2:3
  /// - सभोपदेशक 3:1 (Hindi)
  /// - സങ്കീർത്തനം 23:1 (Malayalam)
  /// - भजन संहिता 23:1 (Hindi - multi-word book names)
  /// - Song of Solomon 1:1 (English - multi-word book names)
  ///
  /// Uses Unicode letter + mark matching ([\p{L}\p{M}]) to support all languages
  /// including scripts with combining characters (Malayalam, Hindi, etc.).
  /// Allows spaces within book names for multi-word book names.
  static final RegExp _scripturePattern = RegExp(
    r'^[1-3]?\s*[\p{L}\p{M}]+(?:\s+[\p{L}\p{M}]+)*\s+\d+(?::\d+(?:-\d+)?)?$',
    unicode: true,
  );

  /// SECURITY FIX: XSS prevention patterns
  static final List<RegExp> _xssPatterns = [
    RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    // Match on* attributes only within HTML tags (e.g., <div onclick=)
    RegExp(r'<[^>]*\s+on\w+\s*=', caseSensitive: false),
    RegExp(r'<iframe', caseSensitive: false),
    RegExp(r'<embed', caseSensitive: false),
    RegExp(r'<object', caseSensitive: false),
  ];

  /// SECURITY FIX: Prompt injection patterns
  static final List<RegExp> _promptInjectionPatterns = [
    RegExp(r'ignore\s+(previous|all|above)\s+instructions?',
        caseSensitive: false),
    // Match standalone "system:" with word boundaries (not "ecosystem:")
    RegExp(r'\bsystem\b\s*:', caseSensitive: false),
    RegExp(r'<\|.*?\|>', caseSensitive: false), // Special tokens
    RegExp(r'###\s*instruction', caseSensitive: false),
    RegExp(r'ENDOFTEXT', caseSensitive: false),
    RegExp(r'\[INST\]', caseSensitive: false),
    RegExp(r'<\?php', caseSensitive: false),
  ];

  /// SECURITY FIX: Control character pattern (null bytes, etc.)
  static final RegExp _controlCharPattern =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Validates input text based on type and returns validation result.
  ///
  /// [input] The input text to validate
  /// [inputType] The type of input ('scripture' or 'topic')
  ///
  /// Returns [ValidationResult] containing validity status and error message.
  /// SECURITY FIX: Now includes XSS and prompt injection detection
  ValidationResult validateInput(String input, String inputType) {
    // Use ValidationUtils for consistent empty check
    if (ValidationUtils.isNullOrEmptyString(input)) {
      return const ValidationResult(
        isValid: false,
      );
    }

    final trimmedInput = input.trim();

    // SECURITY FIX: Check for control characters
    if (_controlCharPattern.hasMatch(trimmedInput)) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Invalid characters detected',
      );
    }

    // SECURITY FIX: Check for XSS patterns
    for (final pattern in _xssPatterns) {
      if (pattern.hasMatch(trimmedInput)) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Invalid characters detected',
        );
      }
    }

    // SECURITY FIX: Check for prompt injection patterns
    for (final pattern in _promptInjectionPatterns) {
      if (pattern.hasMatch(trimmedInput)) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Invalid input format',
        );
      }
    }

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
            'Please enter a valid scripture reference (e.g., John 3:16 or Psalm 23)',
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

  /// SECURITY FIX: Sanitize input by removing potentially dangerous characters
  /// This is a defense-in-depth measure - validation should catch most issues
  String sanitizeInput(String input) {
    return input
        // Remove HTML/XML tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Remove control characters (except newline, tab, carriage return)
        .replaceAll(_controlCharPattern, '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Creates parameters object with validation.
  ///
  /// This method combines validation with parameter creation,
  /// ensuring that only valid parameters can be created.
  ///
  /// Returns Either a [ValidationFailure] or valid parameters.
  /// SECURITY FIX: Now sanitizes input before creating params
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

    // SECURITY FIX: Sanitize input as defense-in-depth
    final sanitizedInput = sanitizeInput(input);

    return Right(StudyGenerationParams(
      input: sanitizedInput,
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
