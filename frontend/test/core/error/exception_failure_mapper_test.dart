import 'package:disciplefy_bible_study/core/error/exception_failure_mapper.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapExceptionToFailure', () {
    test('maps each known exception to its matching failure', () {
      expect(
        mapExceptionToFailure(
          const NetworkException(message: 'offline', code: 'NETWORK_ERROR'),
          fallbackMessage: 'fallback',
        ),
        isA<NetworkFailure>()
            .having((f) => f.message, 'message', 'offline')
            .having((f) => f.code, 'code', 'NETWORK_ERROR'),
      );

      expect(
        mapExceptionToFailure(
          const RateLimitException(message: 'slow', code: 'RATE_LIMIT'),
          fallbackMessage: 'fallback',
        ),
        isA<RateLimitFailure>(),
      );

      expect(
        mapExceptionToFailure(
          const AuthenticationException(message: 'nope', code: 'AUTH'),
          fallbackMessage: 'fallback',
        ),
        isA<AuthenticationFailure>(),
      );

      expect(
        mapExceptionToFailure(
          const ServerException(message: 'boom', code: 'SERVER_ERROR'),
          fallbackMessage: 'fallback',
        ),
        isA<ServerFailure>().having((f) => f.message, 'message', 'boom'),
      );
    });

    test('falls back to ServerFailure for an unrecognised error', () {
      final failure = mapExceptionToFailure(
        FormatException('bad json'),
        fallbackMessage: 'Failed to reset',
        fallbackCode: 'RESET_PROGRESS_ERROR',
      );

      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Failed to reset');
      expect(failure.code, 'RESET_PROGRESS_ERROR');
    });
  });
}
