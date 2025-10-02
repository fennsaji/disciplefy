import '../error/failures.dart';
import '../error/token_failures.dart';

/// SECURITY FIX: Error message sanitizer to prevent information disclosure
///
/// This utility sanitizes error messages to ensure that internal system details,
/// stack traces, database errors, and API endpoints are never exposed to users.
class ErrorMessageSanitizer {
  /// Sanitizes an error message based on failure type
  ///
  /// Returns a user-friendly message that doesn't expose internal details
  static String sanitize(Failure failure) {
    // Use switch expression for type-safe handling
    return switch (failure.runtimeType) {
      // Network errors
      NetworkFailure _ => _sanitizeNetworkError(failure as NetworkFailure),

      // Server errors
      ServerFailure _ => _sanitizeServerError(failure as ServerFailure),

      // Authentication errors
      AuthenticationFailure _ =>
        _sanitizeAuthError(failure as AuthenticationFailure),

      // Authorization errors
      AuthorizationFailure _ =>
        _sanitizeAuthzError(failure as AuthorizationFailure),

      // Validation errors (safe to show)
      ValidationFailure _ =>
        _sanitizeValidationError(failure as ValidationFailure),

      // Rate limiting
      RateLimitFailure _ =>
        _sanitizeRateLimitError(failure as RateLimitFailure),

      // Insufficient tokens
      InsufficientTokensFailure _ =>
        _sanitizeInsufficientTokensError(failure as InsufficientTokensFailure),

      // Storage errors
      StorageFailure _ => _sanitizeStorageError(failure as StorageFailure),

      // Client errors
      ClientFailure _ => _sanitizeClientError(failure as ClientFailure),

      // Cache errors
      CacheFailure _ => _sanitizeCacheError(failure as CacheFailure),

      // Unknown/unexpected errors
      _ => _sanitizeUnknownError(failure),
    };
  }

  static String _sanitizeNetworkError(NetworkFailure failure) {
    // Never expose network details, timeouts, or endpoints
    return 'Network connection failed. Please check your internet connection.';
  }

  static String _sanitizeServerError(ServerFailure failure) {
    // Never expose server error details, status codes, or stack traces
    return 'Server error occurred. Please try again later.';
  }

  static String _sanitizeAuthError(AuthenticationFailure failure) {
    // Generic auth error - don't reveal if user exists or token details
    return 'Authentication required. Please sign in again.';
  }

  static String _sanitizeAuthzError(AuthorizationFailure failure) {
    // Generic permission error - don't reveal what permissions are needed
    return 'You do not have permission to perform this action.';
  }

  static String _sanitizeValidationError(ValidationFailure failure) {
    // Validation errors are safe to show as they're user-input related
    // But still sanitize to ensure no code injection
    return _removeSpecialCharacters(failure.message);
  }

  static String _sanitizeRateLimitError(RateLimitFailure failure) {
    // Show rate limit message but sanitize retry timing details
    if (failure.retryAfter != null) {
      final seconds = failure.retryAfter!.inSeconds;
      if (seconds > 60) {
        final minutes = (seconds / 60).ceil();
        return 'Please wait $minutes ${minutes == 1 ? 'minute' : 'minutes'} before trying again.';
      }
      return 'Please wait $seconds ${seconds == 1 ? 'second' : 'seconds'} before trying again.';
    }
    return 'You have reached your request limit. Please try again later.';
  }

  static String _sanitizeInsufficientTokensError(
      InsufficientTokensFailure failure) {
    // Show token information but sanitize internal details
    final required = failure.requiredTokens;
    final available = failure.availableTokens;

    String message =
        'You need $required tokens but only have $available available.';

    if (failure.nextResetTime != null) {
      final now = DateTime.now();
      final resetTime = failure.nextResetTime!;
      final duration = resetTime.difference(now);

      if (duration.inHours > 0) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        message += ' Tokens reset in ${hours}h ${minutes}m.';
      } else if (duration.inMinutes > 0) {
        message += ' Tokens reset in ${duration.inMinutes}m.';
      } else {
        message += ' Tokens reset soon.';
      }
    }

    return message;
  }

  static String _sanitizeStorageError(StorageFailure failure) {
    // Never expose storage paths, database details, or file system info
    return 'Unable to save data locally. Please check storage permissions.';
  }

  static String _sanitizeClientError(ClientFailure failure) {
    // Generic client error - don't expose internal state
    return 'An error occurred. Please try again.';
  }

  static String _sanitizeCacheError(CacheFailure failure) {
    // Cache errors shouldn't be visible to users - return generic message
    return 'Unable to load cached data. Please refresh.';
  }

  static String _sanitizeUnknownError(Failure failure) {
    // For any unexpected error type, return generic message
    // NEVER expose the actual error or its type
    return 'An unexpected error occurred. Please try again later.';
  }

  /// Removes special characters that could be used for injection
  static String _removeSpecialCharacters(String message) {
    return message
        // Remove HTML/script tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Remove special characters commonly used in attacks
        .replaceAll(RegExp(r'''[<>&"']'''), '')
        // Remove control characters
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
