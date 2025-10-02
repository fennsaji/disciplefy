/// Custom exceptions for the Disciplefy Bible Study app.
///
/// This file defines all application-specific exceptions following
/// Clean Architecture principles and standardized error handling.
abstract class AppException implements Exception {
  /// The error message to display to users.
  final String message;

  /// Error code for logging and debugging purposes.
  final String code;

  /// Additional context for the error.
  final Map<String, dynamic>? context;

  const AppException({
    required this.message,
    required this.code,
    this.context,
  });

  @override
  String toString() => 'AppException: $code - $message';
}

/// Exception thrown when server communication fails.
class ServerException extends AppException {
  const ServerException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when network connectivity is unavailable.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when input validation fails.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when user authentication fails.
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when user lacks required permissions.
class AuthorizationException extends AppException {
  const AuthorizationException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when local storage operations fail.
class StorageException extends AppException {
  const StorageException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when rate limits are exceeded.
class RateLimitException extends AppException {
  /// SECURITY FIX: Duration until rate limit expires
  final Duration? retryAfter;

  const RateLimitException({
    required super.message,
    required super.code,
    this.retryAfter,
    super.context,
  });
}

/// Exception thrown when user has insufficient tokens for an operation.
class InsufficientTokensException extends AppException {
  /// Number of tokens required for the operation
  final int requiredTokens;

  /// Number of tokens currently available
  final int availableTokens;

  /// Time when tokens will reset (if applicable)
  final DateTime? nextResetTime;

  const InsufficientTokensException({
    required super.message,
    required super.code,
    required this.requiredTokens,
    required this.availableTokens,
    this.nextResetTime,
    super.context,
  });

  /// Get formatted message with token details
  String get detailMessage {
    final baseMessage =
        'Need $requiredTokens tokens, but only $availableTokens available.';
    if (nextResetTime != null) {
      final now = DateTime.now();
      final timeUntilReset = nextResetTime!.difference(now);
      final hours = timeUntilReset.inHours;
      final minutes = timeUntilReset.inMinutes.remainder(60);

      String resetText;
      if (hours > 0) {
        resetText = 'Resets in ${hours}h ${minutes}m';
      } else if (minutes > 0) {
        resetText = 'Resets in ${minutes}m';
      } else {
        resetText = 'Resets soon';
      }

      return '$baseMessage $resetText.';
    }
    return baseMessage;
  }
}

/// Exception thrown for general client-side errors.
class ClientException extends AppException {
  const ClientException({
    required super.message,
    required super.code,
    super.context,
  });
}

/// Exception thrown when cache operations fail.
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.context,
  });
}

/// Exception thrown when token validation fails.
class TokenValidationException extends AppException {
  const TokenValidationException({
    required super.message,
    super.code = 'TOKEN_VALIDATION_ERROR',
    super.context,
  });
}
