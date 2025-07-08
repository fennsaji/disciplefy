import 'package:equatable/equatable.dart';

/// Abstract base class for all failures in the application.
/// 
/// Failures represent error states that have been handled and can be
/// presented to the user in a meaningful way.
abstract class Failure extends Equatable {
  /// User-friendly error message.
  final String message;
  
  /// Technical error code for debugging.
  final String code;
  
  /// Additional context about the failure.
  final Map<String, dynamic>? context;

  const Failure({
    required this.message,
    required this.code,
    this.context,
  });

  @override
  List<Object?> get props => [message, code, context];

  @override
  String toString() => 'Failure: $code - $message';
}

/// Failure related to server communication issues.
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred. Please try again later.',
    super.code = 'SERVER_ERROR',
    super.context,
  });
}

/// Failure related to network connectivity issues.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'NETWORK_ERROR',
    super.context,
  });
}

/// Failure related to input validation.
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Invalid input provided.',
    super.code = 'VALIDATION_ERROR',
    super.context,
  });
}

/// Failure related to user authentication.
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.message = 'Authentication failed. Please sign in again.',
    super.code = 'AUTH_ERROR',
    super.context,
  });
}

/// Failure related to user authorization.
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    super.message = 'You do not have permission to perform this action.',
    super.code = 'AUTHORIZATION_ERROR',
    super.context,
  });
}

/// Failure related to local storage operations.
class StorageFailure extends Failure {
  const StorageFailure({
    super.message = 'Local storage error occurred.',
    super.code = 'STORAGE_ERROR',
    super.context,
  });
}

/// Failure related to rate limiting.
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    super.message = 'Too many requests. Please wait before trying again.',
    super.code = 'RATE_LIMIT_ERROR',
    super.context,
  });
}

/// General client-side failure.
class ClientFailure extends Failure {
  const ClientFailure({
    super.message = 'An unexpected error occurred.',
    super.code = 'CLIENT_ERROR',
    super.context,
  });
}