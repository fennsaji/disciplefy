import 'exceptions.dart';
import 'failures.dart';

/// Translates a thrown datasource exception into the matching [Failure].
///
/// Repositories catch broadly and delegate here so the exception→failure
/// mapping stays in one place. Anything unrecognised — including a raw
/// `Exception` from a parsing bug — becomes a [ServerFailure] carrying
/// [fallbackMessage], so callers always get a presentable message.
Failure mapExceptionToFailure(
  Object error, {
  required String fallbackMessage,
  String fallbackCode = 'UNEXPECTED_ERROR',
}) {
  if (error is AuthenticationException) {
    return AuthenticationFailure(message: error.message, code: error.code);
  }
  if (error is AuthorizationException) {
    return AuthorizationFailure(message: error.message, code: error.code);
  }
  if (error is RateLimitException) {
    return RateLimitFailure(message: error.message, code: error.code);
  }
  if (error is NetworkException) {
    return NetworkFailure(message: error.message, code: error.code);
  }
  if (error is ValidationException) {
    return ValidationFailure(message: error.message, code: error.code);
  }
  if (error is CacheException) {
    return CacheFailure(message: error.message, code: error.code);
  }
  if (error is ServerException) {
    return ServerFailure(message: error.message, code: error.code);
  }
  if (error is ClientException) {
    return ClientFailure(message: error.message, code: error.code);
  }
  return ServerFailure(message: fallbackMessage, code: fallbackCode);
}
