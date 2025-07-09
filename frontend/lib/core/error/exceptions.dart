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
  const RateLimitException({
    required super.message,
    required super.code,
    super.context,
  });
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