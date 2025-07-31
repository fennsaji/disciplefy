/// Centralized validation utilities to reduce repeated validation logic.
/// 
/// This class provides common validation patterns used across the application,
/// promoting code reuse and consistency.
class ValidationUtils {
  ValidationUtils._(); // Private constructor to prevent instantiation

  /// Validates that a string is not null, not empty, and not just whitespace.
  /// 
  /// Returns true if the string contains meaningful content.
  static bool isNotNullOrEmptyString(String? value) => 
    value != null && value.trim().isNotEmpty;

  /// Validates that a string is null, empty, or just whitespace.
  /// 
  /// Returns true if the string is empty or contains no meaningful content.
  static bool isNullOrEmptyString(String? value) => 
    value == null || value.trim().isEmpty;

  /// Validates string length is within specified bounds.
  /// 
  /// [value] String to validate
  /// [minLength] Minimum required length (inclusive)
  /// [maxLength] Maximum allowed length (inclusive)
  /// 
  /// Returns true if length is within bounds.
  static bool isValidLength(String? value, {int minLength = 0, int? maxLength}) {
    if (value == null) return minLength == 0;
    
    final length = value.trim().length;
    if (length < minLength) return false;
    if (maxLength != null && length > maxLength) return false;
    
    return true;
  }

  /// Validates that a list is not null and not empty.
  /// 
  /// Returns true if the list contains at least one element.
  static bool isNotNullOrEmpty<T>(List<T>? list) => 
    list != null && list.isNotEmpty;

  /// Validates that a list is null or empty.
  /// 
  /// Returns true if the list is null or contains no elements.
  static bool isNullOrEmpty<T>(List<T>? list) => 
    list == null || list.isEmpty;

  /// Validates that an object is not null.
  /// 
  /// Returns true if the object is not null.
  static bool isNotNull<T>(T? value) => value != null;

  /// Validates that an object is null.
  /// 
  /// Returns true if the object is null.
  static bool isNull<T>(T? value) => value == null;

  /// Validates that a number is within specified bounds.
  /// 
  /// [value] Number to validate
  /// [min] Minimum allowed value (inclusive)
  /// [max] Maximum allowed value (inclusive)
  /// 
  /// Returns true if the number is within bounds.
  static bool isWithinBounds(num? value, {num? min, num? max}) {
    if (value == null) return false;
    
    if (min != null && value < min) return false;
    if (max != null && value > max) return false;
    
    return true;
  }

  /// Validates that a string contains only allowed characters.
  /// 
  /// [value] String to validate
  /// [allowedPattern] RegExp pattern for allowed characters
  /// 
  /// Returns true if the string matches the pattern.
  static bool containsOnlyAllowed(String? value, RegExp allowedPattern) {
    if (value == null) return false;
    return allowedPattern.hasMatch(value);
  }

  /// Validates email format using a basic regex pattern.
  /// 
  /// Returns true if the email format appears valid.
  static bool isValidEmail(String? email) {
    if (isNullOrEmptyString(email)) return false;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    return emailRegex.hasMatch(email!.trim());
  }

  /// Validates URL format using a basic regex pattern.
  /// 
  /// Returns true if the URL format appears valid.
  static bool isValidUrl(String? url) {
    if (isNullOrEmptyString(url)) return false;
    
    try {
      final uri = Uri.parse(url!.trim());
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Validates that a collection has the expected size.
  /// 
  /// [collection] Collection to validate
  /// [expectedSize] Expected number of elements
  /// 
  /// Returns true if the collection has exactly the expected size.
  static bool hasExpectedSize<T>(Iterable<T>? collection, int expectedSize) {
    if (collection == null) return expectedSize == 0;
    return collection.length == expectedSize;
  }

  /// Validates that a collection has at least the minimum required size.
  /// 
  /// [collection] Collection to validate
  /// [minSize] Minimum required size
  /// 
  /// Returns true if the collection has at least the minimum size.
  static bool hasMinimumSize<T>(Iterable<T>? collection, int minSize) {
    if (collection == null) return minSize <= 0;
    return collection.length >= minSize;
  }

  /// Validates that a collection has at most the maximum allowed size.
  /// 
  /// [collection] Collection to validate
  /// [maxSize] Maximum allowed size
  /// 
  /// Returns true if the collection has at most the maximum size.
  static bool hasMaximumSize<T>(Iterable<T>? collection, int maxSize) {
    if (collection == null) return true;
    return collection.length <= maxSize;
  }

  /// Validates multiple conditions and returns the first failure message.
  /// 
  /// [validations] Map of validation functions to error messages
  /// 
  /// Returns null if all validations pass, otherwise returns the first error message.
  static String? validateAll(Map<bool Function(), String> validations) {
    for (final entry in validations.entries) {
      if (!entry.key()) {
        return entry.value;
      }
    }
    return null;
  }

  /// Creates a validation result with success/failure and optional message.
  /// 
  /// [isValid] Whether the validation passed
  /// [errorMessage] Error message if validation failed
  /// 
  /// Returns ValidationResult instance.
  static ValidationResult createResult(bool isValid, [String? errorMessage]) => ValidationResult(
      isValid: isValid,
      errorMessage: isValid ? null : errorMessage,
    );
}

/// Result of a validation operation.
class ValidationResult {
  /// Whether the validation passed.
  final bool isValid;
  
  /// Error message if validation failed (null if valid).
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  /// Creates a successful validation result.
  const ValidationResult.valid() : this(isValid: true);

  /// Creates a failed validation result with an error message.
  const ValidationResult.invalid(String errorMessage) 
    : this(isValid: false, errorMessage: errorMessage);

  @override
  String toString() => 'ValidationResult(isValid: $isValid, errorMessage: $errorMessage)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationResult &&
        other.isValid == isValid &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => isValid.hashCode ^ errorMessage.hashCode;
}